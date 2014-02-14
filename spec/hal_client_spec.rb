require_relative "./spec_helper"
require "hal_client"

describe HalClient do
  describe ".new()" do
    subject { HalClient.new }
    it { should be_kind_of HalClient }
  end

  describe '.new w/ custom accept' do
    subject { HalClient.new(accept: "application/vnd.myspecialmediatype") }
    it { should be_kind_of HalClient }
  end

  describe "#get(<url>)" do
    subject(:client) { HalClient.new }
    let!(:return_val) { client.get "http://example.com/foo" }

    it "returns a HalClient::Representation" do
      expect(return_val).to be_kind_of HalClient::Representation
    end

    describe "request" do
      subject { request }
      it("should have been made") { should have_been_made }

      it "sends accept header" do
        expect(request.with(headers: {'Accept' => 'application/hal+json'})).
          to have_been_made
      end
    end

    context "explicit accept" do
      subject(:client) { HalClient.new accept: 'app/test' }
      it "sends specified accept header" do
        expect(request.with(headers: {'Accept' => 'app/test'})).
          to have_been_made
      end
    end
  end

  describe ".get(<url>)" do 
    let!(:return_val) { HalClient.get "http://example.com/foo" }

    it "returns a HalClient::Representation" do
      expect(return_val).to be_kind_of HalClient::Representation
    end

    describe "request" do
      subject { request }
      it("should have been made") { should have_been_made }

      it "sends accept header" do
        expect(request.with(headers: {'Accept' => 'application/hal+json'})).
          to have_been_made
      end
    end
  end

  let!(:request) { stub_request(:get, "http://example.com/foo").
    to_return body: "{}" }
end
