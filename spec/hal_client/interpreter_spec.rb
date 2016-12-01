require 'hal_client/interpreter'

RSpec.describe HalClient::Interpreter do
  let(:hal_client) { HalClient.new }

  describe ".new" do
    specify { expect(described_class.new({}, hal_client)).to be_kind_of described_class }
  end


  describe "#extract_props" do
    subject { described_class.new(parsed_json, hal_client) }
    let(:parsed_json) { {"num" => 1,
                         "_links" => {},
                         "_embedded" => {}
                        } }

    specify { expect(subject.extract_props).to be_kind_of Hash }
    specify { expect(subject.extract_props).to include("num") }
    specify { expect(subject.extract_props).not_to include("_links") }
    specify { expect(subject.extract_props).not_to include("_embedded") }
  end


  describe "#extract_links" do
    subject { described_class.new({}, hal_client) }

    specify { expect(subject.extract_links).to be_kind_of Enumerable }

    context "with out links" do
      subject { described_class.new({}, hal_client) }

      specify { expect(subject.extract_links).to be_empty }
    end

    context "with links" do
      subject { described_class.new(links_json, hal_client) }
      let(:links_json) { {"_links" => {
                            "foo" => { "href" => "http://example.com/foo" },
                            "bar" => [ { "href" => "http://example.com/bar1" },
                                       { "href" => "http://example.com/bar2" } ],
                            "tmpl" =>  { "href" => "http://example.com/foo{?q}",
                                         "templated" => true},
                            "mixed" => [ { "href" => "http://example.com/foo" },
                                         { "href" => "http://example.com/foo{?q}",
                                           "templated" => true } ]
                          } } }

      specify { expect(subject.extract_links).not_to be_empty }
      specify { expect(subject.extract_links)
                .to include link_matching("foo", "http://example.com/foo") }
      specify { expect(subject.extract_links)
                .to include link_matching("bar", "http://example.com/bar1") }
      specify { expect(subject.extract_links)
                .to include link_matching("bar", "http://example.com/bar2") }
      specify { expect(subject.extract_links)
                .to include link_matching("mixed", "http://example.com/foo") }

      specify { expect(subject.extract_links)
                .to include templated_link_matching("tmpl", "http://example.com/foo{?q}") }
      specify { expect(subject.extract_links)
                .to include templated_link_matching("mixed", "http://example.com/foo{?q}") }
    end

    context "with embedded" do
      subject { described_class.new(embedded_json, hal_client) }
      let(:embedded_json) { {"_links" => {
                               "foo" => { "href" => "http://example.com/foo" }
                             },
                             "_embedded" => {
                               "bar" => { "_links" => { "self" => { "href" => "http://example.com/bar" } } },
                               "baz" => [ { "_links" => { "self" => { "href" => "http://example.com/baz1" } } },
                                          { "_links" => { "self" => { "href" => "http://example.com/baz2" } } } ]
                             }
                            } }

      specify { expect(subject.extract_links).not_to be_empty }
      specify { expect(subject.extract_links).to include link_matching("foo", "http://example.com/foo") }
      specify { expect(subject.extract_links).to include link_matching("bar", "http://example.com/bar") }
      specify { expect(subject.extract_links).to include link_matching("baz", "http://example.com/baz1") }
      specify { expect(subject.extract_links).to include link_matching("baz", "http://example.com/baz2") }
    end

    context "curies" do
      let(:raw_repr) { <<-HAL }
{ "_links": {
    "self": { "href": "http://example.com/foo" }
    ,"ex:bar": { "href": "http://example.com/bar" }
    ,"curies": [{"name": "ex", "href": "http://example.com/rels/{rel}", "templated": true}]
  }
}
HAL

      subject { described_class.new(MultiJson.load(raw_repr), hal_client) }

      specify { expect(subject.extract_links).to include link_matching("ex:bar", "http://example.com/bar") }
      specify { expect(subject.extract_links).to include link_matching("http://example.com/rels/bar", "http://example.com/bar") }

    end
  end

  matcher :link_matching do |rel, target_url|
    match { |actual_link|
      (actual_link.literal_rel == rel || actual_link.fully_qualified_rel == rel) &&
            actual_link.target_url == target_url
    }
  end

  matcher :templated_link_matching do |rel, target_url|
    match { |actual_link|
      (actual_link.literal_rel == rel || actual_link.fully_qualified_rel == rel) &&
        actual_link.raw_href == Addressable::Template.new(target_url) &&
        actual_link.templated?
    }
  end

end
