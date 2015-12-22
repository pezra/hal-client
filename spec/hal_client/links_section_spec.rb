require "spec_helper"
require 'hal-client'

describe HalClient::LinksSection, "namespaces embedded" do
  subject(:section) { described_class.new(raw_section) }

  specify { expect(section.hrefs("up"))
    .to contain_exactly "http://example.com/parent" }

  specify { expect(section.hrefs(fully_qualified_first_rel))
    .to contain_exactly "http://example.com/foo" }

  specify { expect(section.hrefs("ns1:first"))
    .to contain_exactly "http://example.com/foo" }

  specify { expect(section.hrefs(fully_qualified_second_rel))
            .to contain_exactly "http://example.com/bar", "http://example.com/baz" }
  
  specify { expect(section.hrefs("ns2:second"))
    .to contain_exactly "http://example.com/bar", "http://example.com/baz" }

  specify { expect(section.hrefs("search"))
      .to all match respond_to(:pattern).and respond_to(:expand) }
  specify { expect(section.hrefs("search").first.pattern).to eq "http://example.com/s{?q}" }

  specify { expect{section.hrefs("nonexistent")}.to raise_error KeyError }

  let(:fully_qualified_first_rel) { "http://rels.example.com/first" }
  let(:fully_qualified_second_rel) { "http://rels.example.com/2/second" }

  let(:raw_section) {
    { "curies" => [{ "name" => "ns1",
                     "href" => "http://rels.example.com/{rel}",
                     "templated" => true},
                   { "name" => "ns2",
                     "href" => "http://rels.example.com/2/{rel}",
                     "templated" => true}],
      "up" => {"href" => "http://example.com/parent"},
      "search" => {"href" => "http://example.com/s{?q}", "templated" => true },
      "ns1:first" => {"href" => "http://example.com/foo"},
      "ns2:second" => [{"href" => "http://example.com/bar"},
                       {"href" => "http://example.com/baz"}]
    } }

  matcher :all do |expected|
    match do |actual|
      actual.all?{|it| expected === it}
    end
  end
end

describe HalClient::LinksSection, "invalid" do
  subject(:section) { described_class.new(raw_section) }

  specify { expect{section.hrefs("bareurl")}
      .to raise_error HalClient::InvalidRepresentationError }

  let(:raw_section) {
    { "bareurl" => "http://example.com/boom" }
  }

end