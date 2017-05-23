require 'hal_client'
require 'hal_client/representation'
require 'hal_client/representation_set'

RSpec.describe HalClient::RepresentationSet do
  describe "#new" do
    let!(:return_val) { described_class.new([foo_repr, bar_repr]) }
    it { is_expected.to be_kind_of described_class }
    it { is_expected.to have(2).items }
  end

  subject(:repr_set) { described_class.new([foo_repr, bar_repr]) }

  describe "#each" do
    it "iterates over each item in the set" do
      seen = []
      subject.each {|it| seen << it}
      expect(seen).to match_array [foo_repr, bar_repr]
    end
  end

  specify { expect(repr_set.count).to eq 2 }
  specify { expect(repr_set.empty?).to be false }

  describe "#any?" do
    it "returns true if there are any matching" do
      expect(subject.any?{|it| it == foo_repr }).to be true
    end

    it "returns true if there are any matchin" do
      expect(subject.any?).to be true
    end

    it "returns false if there aren't any matching" do
      expect(subject.any?{|it| false }).to be false
    end
  end

  describe "#related" do
    context "single target in each member" do
      subject(:returned_val) { repr_set.related("spouse") }
      it { is_expected.to include_representation_of "http://example.com/foo-spouse" }
      it { is_expected.to include_representation_of "http://example.com/bar-spouse" }
      it { is_expected.to have(2).items }
    end

    context "multiple targets" do
      subject(:returned_val) { repr_set.related("sibling") }
      it { is_expected.to include_representation_of "http://example.com/foo-brother" }
      it { is_expected.to include_representation_of "http://example.com/foo-sister" }
      it { is_expected.to include_representation_of "http://example.com/bar-brother" }
      it { is_expected.to have(3).items }
    end

    context "templated" do
      subject(:returned_val) { repr_set.related("cousin", distance: "first") }
      specify { expect(subject.map{ |s| s.href.to_s }).to include("http://example.com/foo-first-cousin") }
      specify { expect(subject.map{ |s| s.href.to_s }).to include("http://example.com/bar-paternal-first-cousin") }
      specify { expect(subject.map{ |s| s.href.to_s }).to include("http://example.com/bar-maternal-first-cousin") }
      it { is_expected.to have(3).items }
    end
  end

  describe "#post" do
    context "with a single representation" do
      subject(:repr_single_set) { described_class.new([foo_repr]) }
      let!(:post_request) { stub_request(:post, "example.com/foo") }

      before(:each) do
        repr_single_set.post("abc")
      end

      it "makes an HTTP POST with the data within the representation" do
        expect(
          post_request.
          with(:body => "abc", :headers => {'Content-Type' => 'application/hal+json'})
          ).to have_been_made
      end
    end
  end

  describe "#put" do
    context "with a single representation" do
      subject(:repr_single_set) { described_class.new([foo_repr]) }
      let!(:put_request) { stub_request(:put, "example.com/foo") }

      before(:each) do
        repr_single_set.put("abc")
      end

      it "makes an HTTP PUT with the data within the representation" do
        expect(
          put_request.
          with(:body => "abc", :headers => {'Content-Type' => 'application/hal+json'})
          ).to have_been_made
      end
    end
  end

  describe "#patch" do
    context "with a single representation" do
      subject(:repr_single_set) { described_class.new([foo_repr]) }
      let!(:patch_request) { stub_request(:patch, "example.com/foo") }

      before(:each) do
        repr_single_set.patch("abc")
      end

      it "makes an HTTP PATCH with the data within the representation" do
        expect(
          patch_request.
          with(:body => "abc", :headers => {'Content-Type' => 'application/hal+json'})
          ).to have_been_made
      end
    end
  end

  let(:a_client) { HalClient.new }

  let(:foo_repr) { HalClient::Representation.new hal_client: a_client, parsed_json: MultiJson.load(foo_hal)}
  let(:foo_hal) { <<-HAL }
{ "_links":{
    "self": { "href":"http://example.com/foo" }
    ,"cousin": { "href": "http://example.com/foo-{distance}-cousin"
                 ,"templated": true }
  }
  ,"_embedded": {
    "spouse": { "_links": { "self": { "href": "http://example.com/foo-spouse"}}}
    ,"sibling": [{ "_links": { "self": { "href": "http://example.com/foo-brother"}}}
                 ,{ "_links": { "self": { "href": "http://example.com/foo-sister"}}}]
  }
}
  HAL

  let(:bar_repr) { HalClient::Representation.new hal_client: a_client, parsed_json: MultiJson.load(bar_hal) }
  let(:bar_hal) { <<-HAL }
{ "_links":{
    "self": { "href":"http://example.com/bar" }
    ,"cousin": [{ "href": "http://example.com/bar-maternal-{distance}-cousin"
                  ,"templated": true }
                ,{ "href": "http://example.com/bar-paternal-{distance}-cousin"
                  ,"templated": true }]
  }
  ,"_embedded": {
    "spouse": { "_links": { "self": { "href": "http://example.com/bar-spouse"}}}
    ,"sibling": { "_links": { "self": { "href": "http://example.com/bar-brother"}}}
  }
}
  HAL

  let!(:foo_cousin_request) {
    stub_identity_request "http://example.com/foo-first-cousin" }
  let!(:bar_maternal_cousin_request) {
    stub_identity_request "http://example.com/bar-maternal-first-cousin" }
  let!(:bar_paternal_cousin_request) {
    stub_identity_request "http://example.com/bar-paternal-first-cousin" }

  def stub_identity_request(url)
    stub_request(:get, url).
      to_return body: %Q|{"_links":{"self":{"href":#{url.to_json}}}}|
  end

  RSpec::Matchers.define(:include_representation_of) do |url|
    match { |repr_set|
      repr_set.any?{|it| it.href == url}
    }
    failure_message { |repr_set|
      "Expected representation of <#{url}> but found only #{repr_set.map(&:href)}"
    }
  end

end
