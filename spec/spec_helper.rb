$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"

require 'rspec'
require 'webmock/rspec'
require 'multi_json'
require 'rspec/collection_matchers'

require 'support/custom_matchers'

RSpec.configure do |config|
  config.include CustomMatchers
end