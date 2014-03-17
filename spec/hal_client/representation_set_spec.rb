require_relative '../spec_helper'

require 'hal_client'
require 'hal_client/representation'
require 'hal_client/representation_set'

describe HalClient::RepresentationSet do
  describe "#new" do
    let!(:return_val) { described_class.new([foo_repr, bar_repr]) }
    it { should be_kind_of described_class }
    it { should have(2).items }
  end

  subject(:repr_set) { described_class.new([foo_repr, bar_repr]) }

  describe "#each" do
    it "iterates over each item in the set" do
      seen = []
      subject.each {|it| seen << it}
      expect(seen).to match_array [foo_repr, bar_repr]
    end
  end

  its(:count) { should eq 2 }
  its(:empty?) { should be_false }

  describe "#any?" do
    it "returns true if there are any" do
      expect(subject.any?{|it| it == foo_repr }).to be_true
    end

    it "returns false if there aren't any" do
      expect(subject.any?{|it| false }).to be_false
    end
  end

  describe "#related" do
    context "single target in each member" do
      subject(:returned_val) { repr_set.related("spouse") }
      it { should include_representation_of "http://example.com/foo-spouse" }
      it { should include_representation_of "http://example.com/bar-spouse" }
      it { should have(2).items }
    end

    context "multiple targets" do
      subject(:returned_val) { repr_set.related("sibling") }
      it { should include_representation_of "http://example.com/foo-brother" }
      it { should include_representation_of "http://example.com/foo-sister" }
      it { should include_representation_of "http://example.com/bar-brother" }
      it { should have(3).items }
    end

    context "templated" do
      subject(:returned_val) { repr_set.related("cousin", distance: "first") }
      it { should include_representation_of "http://example.com/foo-first-cousin" }
      it { should include_representation_of "http://example.com/bar-paternal-first-cousin" }
      it { should include_representation_of "http://example.com/bar-maternal-first-cousin" }
      it { should have(3).items }
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
    failure_message_for_should { |repr_set|
      "Expected representation of <#{url}> but found only #{repr_set.map(&:href)}"
    }
  end

end
