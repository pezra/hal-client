require "hal_client/representation"

RSpec.describe HalClient::Representation do

  describe ".new" do
    specify {
      expect(
        described_class.new(Addressable::URI.parse("http://example.com/"),
                            properties_hash,
                            links_list,
                            a_client)
      ).to behave_like_a described_class
    }

    let(:properties_hash) { {} }
    let(:links_list) { [] }
  end

  subject(:repr) {
    described_class.new(Addressable::URI.parse("http://example.com/"), {}, [], a_client)
  }

  describe "#post" do
    let!(:post_request) { stub_request(:post, subject.href).to_return(body: "{}") }

    specify { expect(repr.post("abc")).to be_kind_of HalClient::Representation }

    describe "after" do
      subject { repr }

      before(:each) do
        subject.post("abc")
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
        expect( subject ).to be_stale
      end
    end
  end

  describe "#put" do
    subject { repr }

    let!(:put_request) { stub_request(:put, subject.href).to_return(body: "{}") }

    specify { expect(subject.put("abc")).to be_kind_of HalClient::Representation }

    describe "after" do
      before(:each) do
        subject.put("abc")
      end

      specify("makes request") do
        expect(put_request.with(:body => "abc",
                                :headers => {'Content-Type' => 'application/hal+json'}))
          .to have_been_made
      end

      it("invalidates repr afterwards") do
        expect( subject ).to be_stale
      end
    end
  end

  describe "#patch" do
    subject { repr }

    let!(:patch_request) { stub_request(:patch, subject.href).to_return(body: "{}") }

    specify { expect(subject.patch("abc")).to be_kind_of HalClient::Representation }

    describe "after" do
      before(:each) do
        subject.patch("abc")
      end

      specify("makes request") do
        expect(patch_request.with(:body => "abc",
                                  :headers => {'Content-Type' => 'application/hal+json'}))
          .to have_been_made
      end

      it("invalidates repr afterwards") do
        expect( subject ).to be_stale
      end
    end
  end

  describe "#href" do
    subject { repr(url: "http://example.com/href") }

    specify { expect( subject.href ).to behave_like_an Addressable::URI }
    specify { expect( subject.href ).to eq Addressable::URI.parse("http://example.com/href") }

    context "w/o hal_client" do
      let(:a_client) { nil }
      subject { repr(url: "http://example.com/href") }

      specify { expect( subject.href ).to eq Addressable::URI.parse("http://example.com/href") }
    end
  end

  describe "#location" do
    specify { expect( subject.location ).to behave_like_an Addressable::URI }
    specify { expect( subject.location ).to eq Addressable::URI.parse("http://example.com") }
  end

  describe "#to_s" do
    subject { repr(url: "http://example.com/to-s") }

    specify { expect( subject.to_s ).to match %{#<HalClient::Representation} }
    specify { expect( subject.to_s ).to match %r{http://example.com/to-s} }

    context "anonymous" do
      subject {
        repr(url: :anon )
      }

      specify { expect( subject.to_s ).to match %{#<HalClient::Representation} }
      specify { expect( subject.to_s ).to match /ANONYMOUS/i }
    end
  end

  describe "#form" do
    context "default form" do
      subject { repr(props: { "_forms" =>
                              { "default" => form_json(target: "default-form") }
                            } ) }

      specify { expect(
                  subject.form
                ).to target "default-form" }

      specify { expect(
                  subject.form
                ).to behave_like_a HalClient::Form }

      specify { expect(
                  subject.form("default")
                ).to target "default-form" }

      specify { expect(
                  subject.form("default")
                ).to behave_like_a HalClient::Form }
    end

    context "non-default form" do
      subject {
        repr(props: { "_forms" =>
                      { "foo" => form_json(target: "foo-form") }
                    } ) }

      specify { expect(
                  subject.form("foo")
                ).to target "foo-form" }

      specify { expect(
                  subject.form(:foo)
                ).to target "foo-form"
      }

      specify { expect{
                  subject.form("nonexistent")
                }.to raise_error KeyError }
    end

    context "multiple forms" do
      subject {
        repr(props: { "_forms" =>
                      { "foo" => form_json(target: "foo-form"),
                        "bar" => form_json(target: "bar-form") }
                    } ) }

      specify { expect(
                  subject.form("foo")
                ).to target "foo-form" }

      specify { expect(
                  subject.form("bar")
                ).to target "bar-form" }
    end

    matcher :target do |expected_target_url|
      match do |actual_form|
        expect(actual_form.target_url.to_s).to eq expected_target_url
      end
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
    describe "#==" do
      specify { expect(
                  repr(url: "http://example.com/") == repr(url: "http://example.com/")
                ).to eq true }
      specify { expect(
                  repr(url: "http://example.com/") == repr(url: "http://example.com/bar")
                ).to eq false }
      specify { expect(
                  repr(url: "http://example.com/") == repr(url: :anon)
                ).to eq false }
      specify { expect(
                  repr(url: :anon) == repr(url: "http://example.com/")
                ).to eq false }
      specify { expect(
                  repr(url: :anon) == repr(url: :anon)
                ).to eq false }
      specify { expect(
                  repr(url: "http://example.com/") == Object.new
                ).to eq false }
    end

    describe ".eql?" do
      specify { expect(
                  repr(url: "http://example.com/").eql? repr(url: "http://example.com/")
                ).to eq true }
      specify { expect(
                  repr(url: "http://example.com/").eql? repr(url: "http://example.com/bar")
                ).to eq false }
      specify { expect(
                  repr(url: "http://example.com/").eql? repr(url: :anon)
                ).to eq false }
      specify { expect(
                  repr(url: :anon).eql? repr(url: "http://example.com/")
                ).to eq false }
      specify { expect(
                  repr(url: :anon).eql? repr(url: :anon)
                ).to eq false }
      specify { expect(
                  repr(url: "http://example.com/").eql? Object.new
                ).to eq false }
    end

    describe "hash" do
      specify{ expect(repr(url: "http://example.com/").hash).to eq repr(url: "http://example.com/").hash }
    end

  end

  describe "#property" do
    specify { expect(repr(props: {"prop1" => 1}).property "prop1").to eq 1 }
    specify { expect{repr().property "nonexistent-prop"}.to raise_exception KeyError }
    specify { expect(repr(props: {"prop1" => 1}).property? "prop1").to be true }
  end

  describe "#property?" do
    specify { expect(repr(props: {"prop1" => 1}).property? "prop1").to be true }
    specify { expect(repr().property? "nonexistent-prop").to be false }
  end

  describe "#has_property?" do
    specify { expect(repr(props: {"prop1" => 1}).has_property? "prop1").to be true }
    specify { expect(repr().has_property? "nonexistent-prop").to be false }
  end

  describe "#properties" do
    specify { expect(
                repr(props: {"prop1" => 1, "prop2" => 2}).properties
              ).to include("prop1" => 1, "prop2" => 2) }
  end

  describe "#fetch" do
    context "for existent property" do
      subject { repr(props: {"prop1" => 1}).fetch "prop1" }
      it { is_expected.to eq 1 }
    end

    context "for existent link" do
      subject { repr(links: [link(rel: "link1")]).fetch "link1" }

      it { is_expected.to have(1).item }
      it "includes related resource representation" do
        expect(subject.first.location.to_s).to eq "http://example.com/other"
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
      subject { repr(props: {"prop1" => 1}) }
      specify { expect( subject["prop1"] ).to eq 1 }
    end

    context "for existent link" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/other")]) }

      specify { expect( subject["link1"] ).to have(1).item }
      specify { expect( subject["link1"] ).to include_representation_of "http://example.com/other" }
    end

    context "non-existent item w/o default" do
      subject { repr }

      specify { expect( subject["wat"] ).to be_nil }
    end
  end

  describe "#related" do
    context "for existent link" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }
      specify { expect( subject.related("link1") ).to have(1).item }
      specify { expect( subject.related("link1") ).to include_representation_of "http://example.com/bar" }
    end

    context "for existent compound link" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar"),
                             link(rel: "link1", href: "http://example.com/baz")]) }

      specify { expect( subject.related("link1") ).to have(2).item }
      specify { expect( subject.related("link1") ).to include_representation_of "http://example.com/bar" }
      specify { expect( subject.related("link1") ).to include_representation_of "http://example.com/baz" }
    end

    context "for existent templated link" do
      subject { repr(links: [tmpl_link(rel: "link1", href: "http://example.com/{name}")]) }

      specify { expect( subject.related("link1", name: "bob") ).to have(1).item }
      specify { expect(
                  subject.related("link1", name: "bob")
                ).to include_representation_of("http://example.com/bob") }
    end

    context "non-existent item w/o default" do
      it "raises exception" do
        expect{ repr.related 'wat'}.to raise_exception KeyError
      end
    end

    context "simple links w/o hal_client" do
      let(:a_client) { nil }
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }
      
      specify { expect( subject.related("link1") ).to have(1).item }
      specify { expect( subject.related("link1") ).to include_representation_of "http://example.com/bar" }
    end

  end

  describe "#all_links" do
    subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }

    specify { expect( subject.all_links ).to have(1).item }
    specify { expect( subject.all_links ).to include link_to("http://example.com/bar", rel: "link1") }

    context "multiple rels" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar"),
                             link(rel: "link2", href: "http://example.com/bar")]) }

      specify { expect( subject.all_links ).to have(2).items }
      specify { expect( subject.all_links ).to include link_to("http://example.com/bar", rel: "link1") }
      specify { expect( subject.all_links ).to include link_to("http://example.com/bar", rel: "link2") }
    end

    context "multiple links, single rels" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar"),
                             link(rel: "link1", href: "http://example.com/baz")]) }

      specify { expect( subject.all_links ).to have(2).items }
      specify { expect( subject.all_links ).to include link_to("http://example.com/bar", rel: "link1") }
      specify { expect( subject.all_links ).to include link_to("http://example.com/baz", rel: "link1") }
    end

    context "templated links" do
      subject { repr(links: [tmpl_link(rel: "link1", href: "http://example.com/{name}")]) }

      specify { expect( subject.all_links ).to have(1).item }
      specify { expect( subject.all_links ).to include link_to("http://example.com/{name}", rel: "link1") }
    end
  end

  describe "#related_hrefs" do
    subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }

    specify { expect(
                subject.related_hrefs "link1"
              ).to contain_exactly Addressable::URI.parse("http://example.com/bar") }
    specify { expect { subject.related_hrefs 'wat' }.to raise_exception KeyError }

    context "embedded link" do
      subject { repr(links: [embedded_link(rel: "embed1", href: "http://example.com/embedded")]) }

      specify { expect(
                  subject.related_hrefs("embed1")
                ).to contain_exactly Addressable::URI.parse("http://example.com/embedded") }
    end

    context "templated link" do
      subject { repr(links: [tmpl_link(rel: "tmpl1", href: "http://example.com/{name}")]) }

      specify { expect(
                  subject.related_hrefs("tmpl1", name: "foo")
                ).to contain_exactly Addressable::URI.parse("http://example.com/foo") }
    end

    context "simple links w/o hal_client" do
      let(:a_client) { nil }
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }

      specify { expect( subject.related_hrefs("link1") ).to contain_exactly Addressable::URI.parse("http://example.com/bar") }
    end

  end

  describe "#raw_related_hrefs" do
    subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }

    specify { expect( subject.raw_related_hrefs("link1") ).to have(1).item }
    specify { expect(
                subject.raw_related_hrefs "link1"
              ).to include Addressable::URI.parse("http://example.com/bar") }

    specify { expect { subject.raw_related_hrefs 'wat' }.to raise_exception KeyError }

    context "embedded link" do
      subject { repr(links: [embedded_link(rel: "embed1", href: "http://example.com/embedded")]) }

      specify { expect(
                  subject.raw_related_hrefs("embed1")
                ).to include Addressable::URI.parse("http://example.com/embedded") }
    end

    context "templated link" do
      subject { repr(links: [tmpl_link(rel: "tmpl1", href: "http://example.com/{name}")]) }

      specify { expect(
                  subject.raw_related_hrefs("tmpl1")
                ).to include Addressable::Template.new("http://example.com/{name}") }
    end
  end

  describe "#has_related?" do
    specify { expect(subject.has_related? "no-such-link-or-embed").to be false }

    context "simple link" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }

      specify { expect(subject.has_related? "link1").to be true }
    end

    context "templated link" do
      subject { repr(links: [link(rel: "tmpl1", href: "http://example.com/{name}")]) }

      specify { expect(subject.has_related? "tmpl1").to be true }
    end

    context "embedded link" do
      subject { repr(links: [embedded_link(rel: "embed1", href: "http://example.com/embedded")]) }

      specify { expect(subject.has_related? "embed1").to be true }
    end
  end

  describe "#related?" do
    specify { expect( subject.related? "no-such-link-or-embed" ).to be false }

    context "simple link" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }

      specify { expect( subject.related? "link1" ).to be true }
    end

    context "templated link" do
      subject { repr(links: [link(rel: "tmpl1", href: "http://example.com/{name}")]) }

      specify { expect( subject.related? "tmpl1" ).to be true }
    end

    context "embedded link" do
      subject { repr(links: [embedded_link(rel: "embed1", href: "http://example.com/embedded")]) }

      specify { expect( subject.related? "embed1" ).to be true }
    end
  end

  describe "#to_json" do
    subject { repr(props: {}, links: []) }

    specify { expect( subject.to_json ).to be_equivalent_json_to "{}" }

    describe "properties" do
      subject { repr(props: {"str" => "foo", "num" => 42, "bool" => false, "null" => nil}) }
      specify { expect( subject.to_json ).to be_equivalent_json_to(<<~JSON) }
          { "str": "foo", "num": 42, "bool": false, "null": null }
        JSON
    end

    describe "singular links" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }

      specify { expect( subject.to_json ).to be_equivalent_json_to(<<~JSON) }
        { "_links": { "link1": { "href": "http://example.com/bar" } } }
      JSON
    end

    describe "plural links" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar"),
                             link(rel: "link1", href: "http://example.com/baz")]) }

      specify { expect( subject.to_json ).to be_equivalent_json_to(<<~JSON) }
        { "_links": { "link1": [ { "href": "http://example.com/bar" },
                                 { "href": "http://example.com/baz" } ] } }
      JSON
    end

    describe "templated links" do
      subject { repr(links: [tmpl_link(rel: "link1", href: "http://example.com/{var}")]) }

      specify { expect( subject.to_json ).to be_equivalent_json_to(<<~JSON) }
        { "_links": { "link1": { "href": "http://example.com/{var}", "templated": true } } }
      JSON
    end

    describe "embedded links" do
      subject { repr(links: [embedded_link(rel: "link1", href: "http://example.com/bar")]) }

      specify { expect( subject.to_json ).to be_equivalent_json_to(<<~JSON) }
        { "_embedded": { "link1": { "_links": { "self": { "href": "http://example.com/bar"} } } } }
      JSON
    end
  end

  describe "#to_hal" do
    subject { repr(props: {}, links: []) }

    specify { expect( subject.to_hal ).to be_equivalent_json_to "{}" }

    describe "properties" do
      subject { repr(props: {"str" => "foo", "num" => 42, "bool" => false, "null" => nil}) }
      specify { expect( subject.to_hal ).to be_equivalent_json_to(<<~JSON) }
          { "str": "foo", "num": 42, "bool": false, "null": null }
        JSON
    end

    describe "singular links" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar")]) }

      specify { expect( subject.to_hal ).to be_equivalent_json_to(<<~JSON) }
        { "_links": { "link1": { "href": "http://example.com/bar" } } }
      JSON
    end

    describe "plural links" do
      subject { repr(links: [link(rel: "link1", href: "http://example.com/bar"),
                             link(rel: "link1", href: "http://example.com/baz")]) }

      specify { expect( subject.to_hal ).to be_equivalent_json_to(<<~JSON) }
        { "_links": { "link1": [ { "href": "http://example.com/bar" },
                                 { "href": "http://example.com/baz" } ] } }
      JSON
    end

    describe "templated links" do
      subject { repr(links: [tmpl_link(rel: "link1", href: "http://example.com/{var}")]) }

      specify { expect( subject.to_hal ).to be_equivalent_json_to(<<~JSON) }
        { "_links": { "link1": { "href": "http://example.com/{var}", "templated": true } } }
      JSON
    end

    describe "embedded links" do
      subject { repr(links: [embedded_link(rel: "link1", href: "http://example.com/bar")]) }

      specify { expect( subject.to_hal ).to be_equivalent_json_to(<<~JSON) }
        { "_embedded": { "link1": { "_links": { "self": { "href": "http://example.com/bar"} } } } }
      JSON
    end
  end

  describe  "#to_enum" do
    subject { repr(links: [embedded_link(rel: "item", href: "http://example.com/bar"),
                           embedded_link(rel: "item", href: "http://example.com/baz")])}

    specify { expect( subject.to_enum ).to behave_like_a Enumerator }
    specify { expect( subject.to_enum(:each) ).to behave_like_a Enumerator }
    specify { expect( subject.to_enum ).to have(2).items }
  end

  # Background

  def repr(url: "http://example.com/", props: {}, links: [])
    url = if :anon == url
            HalClient::AnonymousResourceLocator.new()
          else
            Addressable::URI.parse(url)
          end

    described_class.new(url, props, links, a_client)
  end

  def link(rel: "related", href: "http://example.com/other")
    url = Addressable::URI.parse(href)

    HalClient::SimpleLink.new(rel: rel, target: HalClient::RepresentationFuture.new(url, a_client), embedded: false)
  end

  def tmpl_link(rel: "related", href: "http://example.com/{name}")
    tmpl = Addressable::Template.new(href)

    HalClient::TemplatedLink.new(rel: rel, template: tmpl, hal_client: a_client)
  end

  def embedded_link(rel: "related", href: "http://example.com/other")
    url = Addressable::URI.parse(href)

    HalClient::SimpleLink.new(rel: rel,
                              target: HalClient::Representation.new(url, {}, [link(rel: "self", href: href)], a_client),
                              embedded: true)
  end

  let(:a_client) { HalClient.new }

  matcher :include_representation_of do |url|
    match { |repr_set|
      repr_set.any?{|it| it.location.to_s == url.to_s}
    }
    failure_message { |repr_set|
      "Expected representation of <#{url}> "#but found only #{repr_set.map(&:to_s)}"
    }
  end

  matcher :link_to do |url, opts|
    rel_matcher = if opts && opts.key?(:rel)
                    ->(actual_rel) { actual_rel == opts[:rel] }
                  else
                    ->(_) { true }
                  end

    match { |actual_link|
      actual_link.href_str == url &&
        rel_matcher.call(actual_link.literal_rel)
    }
  end
end
