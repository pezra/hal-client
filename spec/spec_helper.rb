$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"

require 'rspec'
require 'webmock/rspec'
require 'multi_json'
require 'rspec/collection_matchers'
