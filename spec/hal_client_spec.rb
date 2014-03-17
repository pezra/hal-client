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

  describe "#post(<url>)" do
    subject(:client) { HalClient.new }
    let!(:return_val) { client.post "http://example.com/foo", post_data }

    it "returns a HalClient::Representation" do
      expect(return_val).to be_kind_of HalClient::Representation
    end

    describe "request" do
      subject { post_request }
      it("should have been made") { should have_been_made }

      it "sends accept header" do
        expect(post_request.with(headers: {'Content-Type' => 'application/hal+json'})).
          to have_been_made
      end
    end

    context "explicit accept" do
      subject(:client) { HalClient.new content_type: 'app/test' }
      it "sends specified content-type header" do
        expect(post_request.with(headers: {'Content-Type' => 'app/test'})).
          to have_been_made
      end
    end
  end

  describe ".post(<url>)" do
    let!(:return_val) { HalClient.post "http://example.com/foo", post_data }

    it "returns a HalClient::Representation" do
      expect(return_val).to be_kind_of HalClient::Representation
    end

    describe "request" do
      subject { post_request }
      it("should have been made") { should have_been_made }

      it "sends accept header" do
        expect(post_request.with(headers: {'Content-Type' => 'application/hal+json'})).
          to have_been_made
      end
    end
  end

  let(:post_data) { "ABC" }

  let!(:post_request) { stub_request(:post, "http://example.com/foo").
    with(:body => post_data).
    to_return body: "{}" }

  let!(:request) { stub_request(:get, "http://example.com/foo").
    to_return body: "{}" }
end
