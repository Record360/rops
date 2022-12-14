require 'spec_helper'
require 'deployer'

describe Deployer do
  subject { Deployer.new(__dir__ + '/../fixtures') }

  it "#notify!" do
    expect(subject).to receive(:branch) { 'branch' }
    expect(subject).to receive(:commit) { '1234567890abcdef' }

    notify = subject.config.contexts[:test][:notify]
    stub_request(:post, notify[:url]).with(
      headers: { 'Content-Type' => 'application/json' },
      body: notify.slice(:channel, :icon, :username).merge(
        text: "TESTING - branch: branch, commit: 12345678"
      ),
    )
    subject.send(:notify!, :test)
  end
end
