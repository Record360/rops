require 'active_support'
require 'active_support/core_ext'

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true

    config.filter_run_including focus: true
    config.run_all_when_everything_filtered = true
  end
end

Dir[__dir__ + '/support/**/*.rb'].each { |f| load(f) }
