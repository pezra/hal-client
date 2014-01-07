$LOAD_PATH << Pathname(__FILE__).dirname + "../lib"

require 'rspec'
require 'webmock/rspec'

WebMock.disable_net_connect!