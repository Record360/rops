class Buildable
  attr_reader :name, :repository, :commit
  attr_writer :commit

  def initialize(name:, repository:, commit:)
    @name = name.downcase
    @repository = repository
    @commit = commit
  end

  def checkout  # :yields: source directory
    Dir.mktmpdir("#{name}-build") do |dir|
      system("git -C #{repository} archive #{commit} | tar -x -C #{dir}") or raise "Git error"
      yield dir
    end
  end
end
