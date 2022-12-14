require 'yaml'
require 'base64'
require 'liquid'
require_relative 'image'

class Config
  CONFIG_LOCATIONS = %w(.rops.yaml platform/rops.yaml config/rops.yaml).freeze
  CONFIG_DEFAULTS = {
    'repository' => nil,
    'default_branch' => 'master',
    'registry' => 'docker.io/r360',
    'default_context' => 'staging',
    'production_context' => 'production',
    'images' => [],
    'contexts' => {},
  }.freeze

  attr_reader :repository, :registry, :default_branch, :default_context, :production_context, :ssh_host
  attr_reader :images, :contexts

  def load(root)
    conf_path = find(root)
    conf = conf_path ? YAML.load_file(conf_path) : {}
    conf = conf.reverse_merge(CONFIG_DEFAULTS)

    @repository, @registry, @default_branch, @default_context, @production_context, @ssh_host, contexts, images =
      conf.values_at('repository', 'registry', 'default_branch', 'default_context', 'production_context', 'ssh', 'contexts', 'images').map(&:presence)
    @repository ||= root

    images ||= [{ 'name' => File.basename(File.absolute_path(repository)) }]
    @images = images.map do |image|
      name = image['name']
      dockerfile = image['dockerfile'].presence || 'Dockerfile'
      Image.new(name: name, repository: repository, dockerfile: dockerfile, registry: registry, commit: nil, tag: nil)
    end

    @contexts = HashWithIndifferentAccess.new(contexts)
    @contexts.each_value do |context|
      notify = context[:notify]
      next  unless notify

      # base64 decode Slack URLs
      if (url = notify[:url])
        notify_url = URI.parse(url)
        unless notify_url.is_a?(URI::HTTP)
          notify_url = URI.parse(Base64.decode64(url))
        end
        notify[:url] = notify_url
      end

      # parse liquid templates
      if (text = notify[:text])
        notify[:text] = Liquid::Template.parse(text)
      end
    end

    self
  end

private

  def find(dir)
    return dir  unless File.directory?(dir)
    CONFIG_LOCATIONS.map { |location|  File.join(dir, location) }.detect { |path|  File.exist?(path) }
  end
end
