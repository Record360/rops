require 'open3'
require 'git'
require 'ptools'
require 'yaml'

# gem 'git'
module Git
  class Base
    def ls_tree(*args)
      self.lib.ls_tree(*args)
    end
  end

  class Lib
    # monkey-patched to add 'files' argument
    def ls_tree(sha, files = nil)
      data = {'blob' => {}, 'tree' => {}}
      command_lines('ls-tree', [sha, files].compact).each do |line|
        (info, filenm) = line.split("\t")
        (mode, type, sha) = info.split
        data[type][filenm] = {:mode => mode, :sha => sha}
      end
      data
    end
  end
end

class Deploy
  attr_reader :app, :git_repo, :registry, :default_context, :commit

  def self.docker
    @docker_path ||= File.which('docker') || File.which('podman')
  end

  def self.podman?
    docker.include?('podman')
  end

  def self.build_cores
    ENV.fetch('R360_BUILD_CORES', [ 1, Concurrent::Utility::ProcessorCounter.new.processor_count - 1 ].max).to_i
  end

  def initialize(app:, git_repo:, registry: 'r360', default_context: 'staging', commit: 'master')
    @app = app
    @git_repo = git_repo
    @registry = registry
    @default_context = default_context
    @commit = commit
    @specs = {}
  end

  def local_repo
    app.downcase
  end

  def remote_repo
    "#{registry}/#{app.downcase}"
  end

  def commit=(commit)
    commit = commit.delete_prefix('g')  if commit&.match(/^g\h{8}$/)
    @commit = commit
    @commit_id = @image_tag = nil
    @specs = {}
  end

  def commit_id
    @commit_id ||= git.object(commit || 'master').sha
  end

  def image_tag
    unless @image_tag
      short_id = commit_id[0, 8]
      @image_tag = "g#{short_id}"
      if commit.present? && (commit != 'master') && !commit.start_with?(short_id)
        @image_tag += "-#{commit}"
      end
    end
    @image_tag
  end

  def local_image
    "#{local_repo}:#{image_tag}"
  end

  def local_image_exists?
    system("#{Deploy.docker} image exists #{local_image}")
  end

  def remote_image
    "#{remote_repo}:#{image_tag}"
  end

  def remote_image_exists?
    # this fails to parse the manifest of some images (built with Podman?), and gives warnings on others
    stdout, stderr, status = Open3.capture3("DOCKER_CLI_EXPERIMENTAL=enabled #{Deploy.docker} manifest inspect #{remote_image}")
    return true  if status.success? || stderr.match(/error parsing manifest blob/)

    puts stderr  if stderr.present?
    false
  end

  def specs_running(context = nil)
    context ||= default_context
    context = context.to_s
    specs = deploy_specs(context)

    cmd = String.new "kubectl --context #{context} --output=json"
    if (namespace = specs.first.dig('metadata', 'namespace'))
      cmd += " --namespace #{namespace}"
    end
    cmd += " get"
    specs.each do |spec|
      cmd += " #{spec['kind'].downcase}/#{spec.dig('metadata', 'name')}"
    end

    statuses, cmd_status = Open3.capture2(cmd)
    return nil  unless cmd_status.success?

    statuses = JSON.parse(statuses)
    statuses = statuses['items']  if statuses.key?('items')
    Array.wrap(statuses).map.with_index do |item, idx|
      containers = Array(item.dig('spec', 'template', 'spec', 'containers')) +
                   Array(item.dig('spec', 'jobTemplate', 'spec', 'template', 'spec', 'containers'))
      version = containers.first['image'].split(':').last               # FIXME: support multiple containers
      status = item.delete('status').with_indifferent_access
      [ specs[idx], { spec: item, version: version, status: status }]
    end.to_h
  end

  def push!
    if Deploy.podman?
      system("#{Deploy.docker} push #{local_image} #{remote_image}")
    else
      system("#{Deploy.docker} tag  #{local_image} #{remote_image}") and
      system("#{Deploy.docker} push #{remote_image}") and
      system("#{Deploy.docker} rmi  #{remote_image}")
    end
  end

  def deploy!(context)
    context ||= default_context
    context = context.to_s
    specs = deploy_specs(context)
    kubectl_apply(context, *specs)
  end

  def deploy_specs(context = nil)
    dspecs = []
    specs(context).deep_dup.each do |spec|
      containers =
        Array(spec.dig('spec', 'template', 'spec', 'containers')) +                       # deployments/statefulsets
        Array(spec.dig('spec', 'jobTemplate', 'spec', 'template', 'spec', 'containers'))  # cronjobs

      containers.each do |container|
        if container['image'] == remote_repo
          container['image'] = remote_image
          dspecs << spec  unless dspecs.include?(spec)
        end
      end
    end
    dspecs
  end

  def specs(context = nil)
    context ||= default_context
    context = context.to_s
    @specs[context] ||= begin
      paths = git.ls_tree(commit_id, "platform/#{context}/")['blob'].keys
      raise "No specs found for context #{context}"  unless paths.present?
      paths.map { |path| YAML.load_stream( git.show(commit_id, path) ) }.flatten.compact
    end
  end

  def kubectl_apply(context, *specs)
    Open3.popen2e("kubectl --context #{context} apply -f -") do |stdin, out, wait_thread|
      Thread.new { out.each { |l| puts l } }
      stdin.write YAML.dump_stream(*specs)
      stdin.close
      wait_thread.value
    end
  end

private

  def git
    @git ||= Git.open(git_repo, log: nil)
  end
end
