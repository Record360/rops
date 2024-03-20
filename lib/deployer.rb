require 'yaml'
require 'open3'
require 'ptools'
require 'net/http'
require 'uri'

require 'git_ext'
require 'config'
require 'image'

class Deployer
  attr_reader :root, :config
  attr_reader :branch, :commit, :image_tag
  attr_accessor :spec_dir

  delegate :repository, :registry, :ssh_host, :images, to: :config
  delegate :default_branch, :default_context, :production_context, to: :config

  def self.docker
    @docker_path ||= File.which('docker') || File.which('podman')
  end

  def self.podman?
    docker.include?('podman')
  end

  def initialize(root = nil, branch: nil)
    @specs = {}
    @root = root || Dir.pwd
    load_config
    self.branch = branch.presence || default_branch
  end

  def branch=(branch)
    return  unless branch
    @branch = branch.dup
    @branch.delete_prefix!('g')  if @branch.match(/^g\h{8}$/)
    @commit = git.object(@branch).sha

    @image_tag = @commit[0, 8]
    images.each do |image|
      image.commit = commit
      image.tag = image_tag
    end
  end

  def specs_running(context = nil)
    context = (context || default_context).to_s
    specs = deploy_specs(context)

    cmd = String.new "--output=json"
    if (namespace = specs.first.dig('metadata', 'namespace'))
      cmd += " --namespace #{namespace}"
    end
    cmd += " get"
    specs.each do |spec|
      cmd += " #{spec['kind'].downcase}/#{spec.dig('metadata', 'name')}"
    end

    statuses, stderr, success = kubectl(context, cmd)
    unless (success || stderr.match(/not found/)) && statuses.present?
      puts stderr  if stderr.present?
      return nil
    end

    spec_status = specs.map { |spec|  [ spec, nil ] }.to_h
    statuses = JSON.parse(statuses)
    statuses = statuses['items']  if statuses.key?('items')
    Array.wrap(statuses).each do |item|
      containers = Array(item.dig('spec', 'template', 'spec', 'containers')) +
                   Array(item.dig('spec', 'jobTemplate', 'spec', 'template', 'spec', 'containers'))
      version = containers.first['image'].split(':').last               # FIXME: support multiple containers
      status = item.delete('status').with_indifferent_access

      spec = specs.detect do |s|
        (item['kind'] == s['kind']) &&
        (item.dig('metadata', 'name') == s.dig('metadata', 'name')) &&
        (item.dig('metadata', 'namespace') == (s.dig('metadata', 'namespace') || 'default'))
      end
      spec_status[spec] = { spec: item, version: version, status: status }
    end
    spec_status
  end

  def deploy!(context)
    context = (context || default_context).to_s
    specs = deploy_specs(context).presence  or raise "No kubernetes specs to deploy"
    stdout, stderr, _success = kubectl(context, 'apply -f -', YAML.dump_stream(*specs))
    puts stdout  if stdout.present?
    puts stderr  if stderr.present?
    notify!(context)
  end

  def deploy_specs(context = nil)
    dspecs = []
    specs(context).deep_dup.each do |spec|
      containers =
        Array(spec.dig('spec', 'template', 'spec', 'containers')) +                       # deployments/statefulsets
        Array(spec.dig('spec', 'jobTemplate', 'spec', 'template', 'spec', 'containers'))  # cronjobs

      containers.each do |container|
        image = images.detect { |image|  image.remote_repo == container['image'] }
        if image
          container['image'] = image.remote_image
          dspecs << spec  unless dspecs.include?(spec)
        elsif !container['image'].include?(':')
          raise "Unknown image #{container['image']}"
        end
      end
    end
    dspecs
  end

  def specs(context = nil)
    spec_dir = self.spec_dir.presence || (context || default_context).to_s
    @specs[spec_dir] ||= begin
      spec_dir = "platform/#{spec_dir}/"
      paths = git.ls_tree(commit, spec_dir)['blob'].keys
      raise "No specs found in #{spec_dir}"  unless paths.present?
      paths.map { |path| YAML.load_stream( git.show(commit, path) ) }.flatten.compact
    end
  end

  def kubectl(context, cmd, data = nil)
    cmd = "kubectl --context #{context} #{cmd}"

    if ssh_host.blank?
      stdout, stderr, cmd_status = Open3.capture3(cmd, stdin_data: data)
      [ stdout, stderr, cmd_status.success? ]
    else
      require 'net/ssh'
      exit_code = -1
      stdout = String.new
      stderr = String.new

      ssh = Net::SSH.start(ssh_host)
      ssh.open_channel do |channel|
        channel.exec(cmd) do |_ch, success|
          success or raise "FAILED: couldn't execute command on #{ssh_host}: #{cmd.inspect}"
          channel.on_data { |_ch, in_data|  stdout << in_data }
          channel.on_extended_data { |_ch, _type, in_data|  stderr << in_data }
          channel.on_request('exit-status') { |_ch, in_data|  exit_code = in_data.read_long }
          channel.send_data(data)  if data
          channel.eof!
        end
      end
      ssh.loop
      [ stdout, stderr, exit_code.zero? ]
    end
  end

private

  def git
    @git ||= Git.open(repository, log: nil)
  end

  def load_config
    @config ||= ::Config.new.load(root)
  end

  def notify!(context)
    if (notify = config.contexts[context]&.dig(:notify))
      text = notify[:text].render(
        'repository' => repository,
        'registry' => registry,
        'ssh_host' => ssh_host,
        'branch' => branch,
        'commit' => commit,
        'image_tag' => image_tag,
      )
      url = notify[:url]
      msg = notify.without(:url).symbolize_keys.merge(text: text).compact

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.instance_of?(URI::HTTPS)
      request = Net::HTTP::Post.new(url.request_uri, content_type: 'application/json')
      request.body = msg.to_json
      response = http.request(request)
    end
  end
end
