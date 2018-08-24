require "hal_client/representation"

RSpec.describe HalClient::Representation do
  let(:raw_repr) { <<-HAL }
{ "prop1": 1
  ,"prop2": 2
  ,"_links": {
    "self": { "href": "http://example.com/foo" }
    ,"link1": { "href": "http://example.com/bar" }
    ,"templated": { "href": "http://example.com/people{?name}"
                ,"templated": true }
    ,"link3": [{ "href": "http://example.com/link3-a" }
               ,{ "href": "http://example.com/link3-b" }]
    ,"nil_link": { "href": null }
    ,"dup": { "href": "http://example.com/dup" }
  }
  ,"_embedded": {
    "embed1": {
      "_links": { "self": { "href": "http://example.com/baz" }}
    }
    ,"dup": {
      "dupProperty": "foo"
      ,"_links": { "self": { "href": "http://example.com/dup" }}
    }
  }
}
HAL
  subject(:repr) { described_class.new(hal_client: a_client,
                                       parsed_json: MultiJson.load(raw_repr)) }

  describe "#post" do
    let!(:post_request) { stub_request(:post, repr.href).to_return(body: "{}") }

    specify { expect(repr.post("abc")).to be_kind_of HalClient::Representation }

    describe "after" do
      before(:each) do
        repr.post("abc")
      end

      it("makes request") do
        expect(post_request.with(:body => "abc",
                                 :headers => {
                                   'Content-Type' => 'application/hal+json'
                                 })
              )
          .to have_been_made
      end

      it("invalidates repr afterwards") do
        expect{
          repr.property("prop1")
        }.to raise_error(HalClient::StaleRepresentationError)
      end
    end
  end

  describe "#put" do
    let!(:put_request) { stub_request(:put, repr.href).to_return(body: "{}") }
    let!(:reload_request) { stub_request(:get, repr.href).to_return(body: raw_repr) }

    specify { expect(repr.put("abc")).to be_kind_of HalClient::Representation }

    describe "after" do
      before(:each) do
        repr.put("abc")
      end

      specify("makes request") do
        expect(put_request.with(:body => "abc",
                                :headers => {'Content-Type' => 'application/hal+json'}))
          .to have_been_made
      end

      it("invalidates repr afterwards") do
        expect{
          repr.property("prop1")
        }.to raise_error(HalClient::StaleRepresentationError)
      end
    end
  end

  describe "#patch" do
    let!(:patch_request) { stub_request(:patch, repr.href).to_return(body: "{}") }
    let!(:reload_request) { stub_request(:get, repr.href).to_return(body: raw_repr) }


    specify { expect(repr.patch("abc")).to be_kind_of HalClient::Representation }

    describe "after" do
      before(:each) do
        repr.patch("abc")
      end

      specify("makes request") do
        expect(patch_request.with(:body => "abc",
                                  :headers => {'Content-Type' => 'application/hal+json'}))
          .to have_been_made
      end

      it("invalidates repr afterwards") do
        expect{
          repr.property("prop1")
        }.to raise_error(HalClient::StaleRepresentationError)
      end
    end
  end

  describe "#to_s" do
    subject(:return_val) { repr.to_s }

    it { is_expected.to match %{#<HalClient::Representation:} }
    it { is_expected.to match %r{http://example.com/foo} }

    context "anonymous" do
      let(:repr) {  described_class.new(hal_client: a_client,
                                        parsed_json: MultiJson.load("{}")) }

      it { is_expected.to match %{#<HalClient::Representation:} }
      it { is_expected.to match /ANONYMOUS/i }
    end
  end

  describe "#form" do
    context "default form" do
      subject(:repr) {
        HalClient::Representation.new(
          hal_client: a_client,
          parsed_json: inject_form(form_json(target: "default-form"), as: "default",
                                   into: {}))
      }

      specify { expect(
                  repr.form
                ).to target "default-form" }

      specify { expect(
                  repr.form
                ).to behave_like_a HalClient::Form }

      specify { expect(
                  repr.form("default")
                ).to target "default-form" }

      specify { expect(
                  repr.form("default")
                ).to behave_like_a HalClient::Form }
    end

    context "non-default form" do
      subject(:repr) {
        HalClient::Representation.new(
          hal_client: a_client,
          parsed_json: inject_form(form_json(target: "foo-form"), as: "foo", into: {}))
      }

      specify { expect(
                  repr.form("foo")
                ).to target "foo-form" }

      specify { expect(
                  repr.form(:foo)
                ).to target "foo-form"
      }

      specify { expect{
                  repr.form("nonexistent")
                }.to raise_error KeyError }
    end

    context "multiple forms" do
      subject(:repr) {
        HalClient::Representation.new(
          hal_client: a_client,
          parsed_json: {}.tap { |hal|
            inject_form(form_json(target: "foo-form"), as: "foo", into: hal)
            inject_form(form_json(target: "bar-form"), as: "bar", into: hal)
          }
        )
      }

      specify { expect(
                  repr.form("foo")
                ).to target "foo-form" }

      specify { expect(
                  repr.form("bar")
                ).to target "bar-form" }
    end

    matcher :target do |expected_target_url|
      match do |actual_form|
        expect(actual_form.target_url.to_s).to eq expected_target_url
      end
    end

    def inject_form(form_json, as:, into: )
      into["_forms"] ||= {}
      into["_forms"][as] = form_json

      into
    end

    def form_json(target:)
      { "_links" => {
          "target" => {
            "href" => target
          }
        },
        "method" => "GET",
        "fields" => []
      }
    end
  end

  context "equality and hash" do
    let(:repr_same_href) { described_class.new(hal_client: a_client,
                                         parsed_json: MultiJson.load(<<-HAL)) }
    { "_links": { "self": { "href": "http://example.com/foo" } } }
    HAL

    let(:repr_diff_href) { described_class.new(hal_client: a_client,
                                         parsed_json: MultiJson.load(<<-HAL)) }
    { "_links": { "self": { "href": "http://DIFFERENT" } } }
    HAL
    let(:repr_no_href) { described_class.new(hal_client: a_client,
                                             parsed_json: MultiJson.load(<<-HAL)) }
    { }
    HAL

    describe "#==" do
      specify { expect(repr == repr_same_href).to eq true }
      specify { expect(repr == repr_diff_href).to eq false }
      specify { expect(repr == repr_no_href).to   eq false }
      specify { expect(repr_no_href == repr).to   eq false }
      specify { expect(repr_no_href == repr_no_href).to eq true }
      specify { expect(repr == Object.new).to eq false }
    end

    describe ".eql?" do
      specify { expect(repr.eql? repr_same_href).to eq true }
      specify { expect(repr.eql? repr_diff_href).to eq false }
      specify { expect(repr.eql? repr_no_href).to   eq false }
      specify { expect(repr_no_href.eql? repr).to   eq false }
      specify { expect(repr_no_href.eql? repr_no_href).to eq true }
      specify { expect(repr.eql? Object.new).to eq false }
    end

    describe "hash" do
      specify{ expect(repr.hash).to eq repr.href.hash }
      specify{ expect(repr_no_href.hash).not_to eq repr_no_href.raw.hash }
    end
  end



  specify { expect(repr.property "prop1").to eq 1 }
  specify { expect{repr.property "nonexistent-prop"}.to raise_exception KeyError }

  specify { expect(repr.property? "prop1").to be true }
  specify { expect(repr.has_property? "prop1").to be true }
  specify { expect(repr.property? "nonexistent-prop").to be false }
  specify { expect(repr.has_property? "nonexistent-prop").to be false }

  specify { expect(repr.properties).to include("prop1" => 1, "prop2" => 2) }
  specify { expect(repr.properties).to_not include("_links" => 1,
                                                   "_embedded" => 2) }

  specify { expect(subject.href.to_s).to eq "http://example.com/foo" }

  describe "#fetch" do
    context "for existent property" do
      subject { repr.fetch "prop1" }
      it { is_expected.to eq 1 }
    end

    context "for existent link" do
      subject { repr.fetch "link1" }
      it { is_expected.to have(1).item }
      it "includes related resource representation" do
        expect(subject.first.href.to_s).to eq "http://example.com/bar"
      end
    end

    context "for existent embedded" do
      subject { repr.fetch "embed1" }
      it { is_expected.to have(1).item }
      it "includes related resource representation" do
        expect(subject.first.href.to_s).to eq "http://example.com/baz"
      end
    end

    context "non-existent item w/o default" do
      it "raises exception" do
        expect{repr.fetch 'wat'}.to raise_exception KeyError
      end
    end

    context "non-existent item w/ default value" do
      subject { repr.fetch "wat", "whatevs" }
      it { is_expected.to eq "whatevs" }
    end

    context "non-existent item w/ default value generator" do
      subject { repr.fetch("wat"){|key| key+"gen" } }
      it { is_expected.to eq "watgen" }
    end
  end

  describe "#[]" do
    context "for existent property" do
      subject { repr["prop1"] }
      it { is_expected.to eq 1 }
    end

    context "for existent link" do
      subject { repr["link1"] }
      it { is_expected.to have(1).item }
      it { is_expected.to include_representation_of "http://example.com/bar" }
    end

    context "for existent embedded" do
      subject { repr["embed1"] }
      it { is_expected.to have(1).item }
      it { is_expected.to include_representation_of "http://example.com/baz" }
    end

    context "non-existent item w/o default" do
      subject { repr["wat"] }
      it { is_expected.to be_nil }
    end
  end

  describe "#related" do
    context "for existent link" do
      subject { repr.related "link1" }
      it { is_expected.to have(1).item }
      it { is_expected.to include_representation_of "http://example.com/bar" }
    end

    context "for existent compound link" do
      subject { repr.related "link3" }
      it { is_expected.to have(2).item }
      it { is_expected.to include_representation_of "http://example.com/link3-a" }
      it { is_expected.to include_representation_of "http://example.com/link3-b" }
    end

    context "for existent templated link" do
      subject { repr.related "templated", name: "bob" }
      it { is_expected.to have(1).item }
      specify { expect(subject.first.href.to_s).to eq(
        "http://example.com/people?name=bob") }
    end

    context "for existent embedded" do
      subject { repr.related "embed1" }
      it { is_expected.to have(1).item }
      it { is_expected.to include_representation_of "http://example.com/baz" }
    end

    context "non-existent item w/o default" do
      it "raises exception" do
        expect{repr.related 'wat'}.to raise_exception KeyError
      end
    end
  end

  describe "#all_links" do
    subject { repr.all_links }

    specify { expect(subject).to include(link1_link) }
    specify { expect(subject).to_not include(link2_link) }

    specify { expect(subject).to include(templated_link) }

    specify { expect(subject).to include(link3a_link) }
    specify { expect(subject).to include(link3b_link) }

    specify { expect(subject
                      .find { |l| l.literal_rel == "dup" }
                      .target['dupProperty'])
              .to eq "foo" }
  end

  specify { expect(repr.related_hrefs "link1")
      .to contain_exactly Addressable::URI.parse("http://example.com/bar") }
  specify { expect(repr.related_hrefs "embed1")
      .to contain_exactly Addressable::URI.parse("http://example.com/baz") }
  specify { expect { repr.related_hrefs 'wat' }.to raise_exception KeyError }

  specify { expect(repr.raw_related_hrefs("templated").map(&:pattern))
      .to contain_exactly "http://example.com/people{?name}" }
  specify { expect(repr.raw_related_hrefs("link1"))
      .to contain_exactly Addressable::URI.parse("http://example.com/bar") }

  specify { expect(subject.has_related? "link1").to be true }
  specify { expect(subject.related? "link1").to be true }
  specify { expect(subject.has_related? "link3").to be true }
  specify { expect(subject.related? "link3").to be true }
  specify { expect(subject.has_related? "embed1").to be true }
  specify { expect(subject.related? "embed1").to be true }

  specify { expect(subject.has_related? "no-such-link-or-embed").to be false }
  specify { expect(subject.related? "no-such-link-or-embed").to be false }
  specify { expect(subject.related? "nil_link").to be false }

  specify { expect(subject.to_json).to be_equivalent_json_to raw_repr }
  specify { expect(subject.to_hal).to be_equivalent_json_to raw_repr }

  context "curie links" do
    let(:raw_repr) { <<-HAL }
{ "_links": {
    "self": { "href": "http://example.com/foo" }
    ,"ex:bar": { "href": "http://example.com/bar" }
    ,"curies": [{"name": "ex", "href": "http://example.com/rels/{rel}", "templated": true}]
  }
}
HAL

    describe "#related return value" do
      subject(:return_val) { repr.related("http://example.com/rels/bar") }
      it { is_expected.to include_representation_of "http://example.com/bar" }
    end

    describe "#[] return value" do
      subject(:return_val) { repr["http://example.com/rels/bar"] }
      it { is_expected.to include_representation_of "http://example.com/bar" }
    end

    describe "#related_hrefs return value" do
      subject(:return_val) { repr.related_hrefs("http://example.com/rels/bar") }
      it { is_expected.to include "http://example.com/bar" }
    end
  end

  context "curie embedded" do
    let(:raw_repr) { <<-HAL }
{ "_links": {
    "self": { "href": "http://example.com/foo" }
    ,"curies": {"name": "ex", "href": "http://example.com/rels/{rel}", "templated": true}
  }
  ,"_embedded": {
    "ex:embed1": { "_links": { "self": { "href": "http://example.com/embed1" } } }
  }
}
HAL

    describe "#related return value " do
      subject(:return_val) { repr.related("http://example.com/rels/embed1") }
      it { is_expected.to include_representation_of "http://example.com/embed1" }
    end

    describe "#[] return value " do
      subject(:return_val) { repr["http://example.com/rels/embed1"] }
      it { is_expected.to include_representation_of "http://example.com/embed1" }
    end

    describe "#related_hrefs return value " do
      subject(:return_val) { repr.related_hrefs("http://example.com/rels/embed1") }
      it { is_expected.to include "http://example.com/embed1" }
    end
  end

  context "invalid link/embedded" do
    let(:raw_repr) { <<-HAL }
{ "_links": {
    "self": { "href": "http://example.com/foo" }
    ,"bare_url": "http://example.com/bar"
  }
  ,"_embedded": {
    "atom": "hello"
    ,"array-of-atoms": [1,2,3]
  }
}
HAL

    specify { expect{repr.related("bare_url")}
        .to raise_error HalClient::InvalidRepresentationError, %r(/_links/bare_url) }
    specify { expect{repr.related("atom")}
        .to raise_error HalClient::InvalidRepresentationError, %r(/_embedded/atom) }
    specify { expect{repr.related("array-of-atoms")}
        .to raise_error HalClient::InvalidRepresentationError, %r(/_embedded/array-of-atoms) }

  end

  specify { expect(repr).to respond_to :as_enum }
  specify { expect(repr).to respond_to :to_enum }

  context "collection" do
    let(:raw_repr) { <<-HAL }
{ "_links": {
    "self": { "href": "http://example.com/foo" }
  }
  ,"_embedded": {
    "item": [
      {"name": " first"}
      ,{"name": "second"}
    ]
  }
}
HAL

    specify { expect(repr.as_enum).to a_kind_of Enumerable }
    specify { expect(repr.as_enum).to have(2).items }

    specify { expect( repr.to_enum ).to be_kind_of Enumerator }
    specify { expect( repr.to_enum(:each) ).to be_kind_of Enumerator }
    specify { expect( repr.to_enum ).to have(2).items }
  end

  # Background

  let(:link1_repr) do
    HalClient::Representation.new(hal_client: a_client, href: "http://example.com/bar")
  end

  let(:link3a_repr) do
    HalClient::Representation.new(hal_client: a_client, href: "http://example.com/link3-a")
  end

  let(:link3b_repr) do
    HalClient::Representation.new(hal_client: a_client, href: "http://example.com/link3-b")
  end


  let(:link1_link) do
    HalClient::SimpleLink.new(rel: 'link1', target: link1_repr, embedded: false)
  end

  let(:link2_link) do
    HalClient::SimpleLink.new(rel: 'link2', target: link1_repr, embedded: false)
  end

  let(:templated_link) do
    HalClient::TemplatedLink.new(rel: 'templated',
                                 template: Addressable::Template.new('http://example.com/people{?name}'),
                                 hal_client: a_client)
  end

  let(:link3a_link) do
    HalClient::SimpleLink.new(rel: 'link3', target: link3a_repr, embedded: false)
  end

  let(:link3b_link) do
    HalClient::SimpleLink.new(rel: 'link3', target: link3b_repr, embedded: false)
  end


  let(:a_client) { HalClient.new }
  let!(:bar_request) { stub_identity_request("http://example.com/bar") }
  let!(:baz_request) { stub_identity_request "http://example.com/baz" }
  let!(:people_request) { stub_identity_request "http://example.com/people?name=bob" }
  let!(:link3_a_request) { stub_identity_request "http://example.com/link3-a" }
  let!(:link3_b_request) { stub_identity_request "http://example.com/link3-b" }

  def stub_identity_request(url)
    stub_request(:get, url).
      to_return body: %Q|{"_links":{"self":{"href":#{url.to_json}}}}|
  end

  matcher :include_representation_of do |url|
    match { |repr_set|
      repr_set.any?{|it| it.href.to_s == url.to_s}
    }
    failure_message { |repr_set|
      "Expected representation of <#{url}> but found only #{repr_set.map(&:href)}"
    }
  end

end

RSpec.describe HalClient::Representation, "w/o hal_client" do
  subject(:repr) { described_class.new(parsed_json: MultiJson.load(raw_repr)) }

  specify { expect(subject.href).to eq "http://example.com/foo" }
  specify { expect(subject.related_hrefs "link1").to include "http://example.com/bar" }
  specify { expect(subject.related("link1").first.href).to eq "http://example.com/bar" }
  specify { expect(subject.related("embed1").first.href).to eq "http://example.com/baz" }


  let(:raw_repr) { <<-HAL }
{ "prop1": 1
  ,"_links": {
    "self": { "href": "http://example.com/foo" }
    ,"link1": { "href": "http://example.com/bar" }
  }
  ,"_embedded": {
    "embed1": {
      "_links": { "self": { "href": "http://example.com/baz" }}
    }
  }
}
  HAL


end
