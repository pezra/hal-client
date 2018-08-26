require "hal-client"

require "hal_client/anonymous_resource_locator"

RSpec.describe HalClient::AnonymousResourceLocator do

  describe "#+" do
    specify { expect(
                subject + "http://example.com/foo/bar"
              ).to behave_like_a Addressable::URI }
    specify { expect(
                (subject + "http://example.com/foo/bar").to_str
              ).to eq "http://example.com/foo/bar" }
    specify { expect(
                (subject + Addressable::URI.parse("http://example.com/foo/bar")).to_str
              ).to eq "http://example.com/foo/bar" }

    specify { expect(
                subject + Addressable::Template.new("http://example.com/foo/{bar}")
              ).to behave_like_a Addressable::Template }
    specify { expect(
                (subject + Addressable::Template.new("http://example.com/foo/{bar}")).pattern
              ).to eq "http://example.com/foo/{bar}" }

  end
end
