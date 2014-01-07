require_relative "./spec_helper"
require "hal_client"

describe HalClient do
  describe ".new" do
    specify { expect(HalClient.new).to be_kind_of HalClient }
    specify { expect(HalClient.new(accept: "application/vnd.myspecialmediatype")).to be }
  end
end