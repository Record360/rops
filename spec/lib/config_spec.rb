require 'spec_helper'
require 'config'

describe Config do
  it "#load" do
    config = Config.new.load(__dir__ + '/../fixtures')
    expect(config.repository).to eq '.'
    expect(config.registry).to eq 'the registry'
    expect(config.default_branch).to eq 'master'
    expect(config.default_context).to eq 'default context'
    expect(config.production_context).to eq 'production context'
    expect(config.ssh_host).to eq 'ssh.host'

    expect(config.images.length).to eq 1
    expect(config.images.first.name).to eq 'image'

    expect(config.contexts.keys).to eq %w(test)
  end
end
