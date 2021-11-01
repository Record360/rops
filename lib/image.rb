require 'buildable'

class Image < Buildable
  def self.build_cores
    @build_cores ||= ENV.fetch('R360_BUILD_CORES', [ 1, Concurrent::Utility::ProcessorCounter.new.processor_count - 1 ].max).to_i
  end

  attr_reader :dockerfile, :tag, :registry

  def initialize(name:, repository:, commit:, dockerfile:, tag:, registry:)
    super(name: name, repository: repository, commit: commit)
    @dockerfile = dockerfile
    @tag = tag
    @registry = registry
  end

  def tag=(tag)
    @tag = tag
    @remote_exists = nil
  end

  def build!
    return  if local_exists?
    checkout do |dir|
      system("#{Deployer.docker} build -f #{dockerfile} -t #{local_image} --build-arg JOBS=#{Image.build_cores} --build-arg GIT_VERSION=#{commit} #{dir}")
    end
  end

  def push!
    return  if remote_exists?

    if Deployer.podman?
      system("#{Deployer.docker} push #{local_image} #{remote_image}")
    else
      system("#{Deployer.docker} tag  #{local_image} #{remote_image}") and
      system("#{Deployer.docker} push #{remote_image}") and
      system("#{Deployer.docker} rmi  #{remote_image}")
    end
  end

  def local_repo
    name
  end

  def remote_repo
    "#{registry}/#{name}"
  end

  def local_image
    "#{local_repo}:#{tag}"
  end

  def local_exists?
    if @local_exists.nil?
      @local_exists = system("#{Deployer.docker} image exists #{local_image}")
    end
  end

  def remote_image
    "#{remote_repo}:#{tag}"
  end

  def remote_exists?
    if @remote_exists.nil?
      # this fails to parse the manifest of some images (built with Podman?), and gives warnings on others
      _stdout, stderr, status = Open3.capture3("DOCKER_CLI_EXPERIMENTAL=enabled #{Deployer.docker} manifest inspect #{remote_image}")
      if status.success? || stderr.include?('error parsing manifest blob')
        @remote_exists = true
      else
        puts stderr  if stderr.present? && !stderr.include?('manifest unknown') && !stderr.include?('no such manifest')
        @remote_exists = false
      end
    end
    @remote_exists
  end
end
