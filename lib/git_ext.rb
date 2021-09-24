require 'git'

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

