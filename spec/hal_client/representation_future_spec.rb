require 'hal-client'

RSpec.describe HalClient::RepresentationFuture do
  describe ".new" do
    specify {
      expect(
        HalClient::RepresentationFuture.new("http://example.com", HalClient.new)
      ).to behave_like_a HalClient::Representation
    }
  end

  subject { HalClient::RepresentationFuture.new("http://example.com", HalClient.new) }

  describe "#to_s" do
    it "doesn't make a request" do
      req = stub_request(:get, "http://example.com")

      subject.to_s

      expect(req).not_to have_been_made
    end

    specify { expect( subject.to_s ).to include "http://example.com" }
  end

  describe "#inspect" do
    it "doesn't make a request" do
      req = stub_request(:get, "http://example.com")

      subject.inspect

      expect(req).not_to have_been_made
    end

    specify { expect( subject.inspect ).to include "http://example.com" }
  end

  describe "#pretty_print" do
    it "doesn't make a request" do
      req = stub_request(:get, "http://example.com")

      subject.pretty_print(pp_stub)

      expect(req).not_to have_been_made
    end

    specify { expect( subject.pretty_print(pp_stub) ).to include "http://example.com" }

    let(:pp_stub) { nil }
  end
end