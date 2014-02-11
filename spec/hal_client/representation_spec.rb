require_relative "../spec_helper"

require "halibut"
require "hal_client/representation"

describe HalClient::Representation do
  describe ".new" do
    let!(:return_val) { described_class.new(a_client, halibut_repr) }
    describe "return_val" do
      subject { return_val }
      it { should be_kind_of described_class }

    end
  end

  let(:raw_repr) { <<-HAL }
{ "prop1": 1
  ,"_links": {
    "self": { "href": "http://example.com/foo" }
    ,"link1": { "href": "http://example.com/bar" }
    ,"link2": { "href": "http://example.com/people{?name}"
                ,"templated": true }
  }
  ,"_embedded": {
    "embed1": {
      "_links": { "self": { "href": "http://example.com/baz" }}
    }
  }
}
HAL

  describe "#property" do
    context "existent" do
      subject { repr.property "prop1" }
      it { should eq 1 }
    end
    context "non-existent" do
      it "raises exception" do
        pending
        expect{repr.property 'wat'}.to raise_exception KeyError
      end
    end
  end

  its(:href) { should eq "http://example.com/foo" }

  describe "#fetch" do
    context "for existent property" do
      subject { repr.fetch "prop1" }
      it { should eq 1 }
    end
    context "for existent link" do
      subject { repr.fetch "link1" }
      it { should have(1).item }
      it "includes related resource representation" do
        expect(subject.first.href).to eq "http://example.com/bar"
      end
    end
    context "for existent embedded" do
      subject { repr.fetch "embed1" }
      it { should have(1).item }
      it "includes related resource representation" do
        expect(subject.first.href).to eq "http://example.com/baz"
      end
    end
    context "non-existent item w/o default" do
      it "raises exception" do
        expect{repr.fetch 'wat'}.to raise_exception KeyError
      end
    end
    context "non-existent item w/ default value" do
      subject { repr.fetch "wat", "whatevs" }
      it { pending; should eq "whatevs" }
    end
    context "non-existent item w/ default value generator" do
      subject { repr.fetch("wat"){|key| key+"gen" } }
      it { pending; should eq "watgen" }
    end
  end

  describe "#[]" do
    context "for existent property" do
      subject { repr["prop1"] }
      it { should eq 1 }
    end
    context "for existent link" do
      subject { repr["link1"] }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/bar" }
    end
    context "for existent embedded" do
      subject { repr["embed1"] }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/baz" }
    end
    context "non-existent item w/o default" do
      subject { repr["wat"] }
      it { pending; should be_nil }
    end
  end

  describe "#related" do
    context "for existent link" do
      subject { repr.related "link1" }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/bar" }
    end
    context "for existent templated link" do
      subject { repr.related "link2", name: "bob" }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/people?name=bob"  }
    end
    context "for existent embedded" do
      subject { repr.related "embed1" }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/baz" }
    end
    context "non-existent item w/o default" do
      it "raises exception" do
        expect{repr.related 'wat'}.to raise_exception KeyError
      end
    end
  end

  describe "#related_hrefs" do
    context "for existent link" do
      subject { repr.related_hrefs "link1" }
      it { should have(1).item }
      it { should include "http://example.com/bar" }
    end
    context "for existent embedded" do
      subject { repr.related_hrefs "embed1" }
      it { should have(1).item }
      it { should include "http://example.com/baz" }
    end
    context "non-existent item w/o default" do
      it "raises exception" do
        pending
        expect{repr.related_hrefs 'wat'}.to raise_exception KeyError
      end
    end
  end


  subject(:repr) { described_class.new(a_client, halibut_repr) }

  let(:a_client) { HalClient.new }
  let(:halibut_repr) { Halibut::Adapter::JSON.parse(raw_repr) }
  let!(:bar_request) { stub_request(:get, "http://example.com/bar").
    to_return body: %q|{"_links":{"self":{"href":"http://example.com/bar"}}}| }
  let!(:baz_request) { stub_request(:get, "http://example.com/baz").
    to_return body: %q|{"_links":{"self":{"href":"http://example.com/baz"}}}| }
  let!(:people_request) { stub_request(:get, "http://example.com/people?name=bob").
    to_return body: %q|{"_links":{"self":{"href":"http://example.com/people?name=bob"}}}| }


  RSpec::Matchers.define(:include_representation_of) do |url|
    match { |repr_set|
      repr_set.any?{|it| it.href == url}
    }
    failure_message_for_should { |repr_set|
      "Expected representation of <#{url}> but found only #{repr_set.map(&:href)}"
    }
  end
end
