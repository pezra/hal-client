require 'hal-client'

require "hal_client/link"

RSpec.describe HalClient::Link do

  subject(:link) { HalClient::SimpleLink.new(rel: rel_1, target: repr_1) }

  describe "#initialize" do
    it "requires a target" do
      expect { HalClient::SimpleLink.new(rel: rel_1) }.to raise_error(ArgumentError)
    end

    it "doesn't allow both target and template" do
      expect {
        HalClient::SimpleLink.new(rel: rel_1, target: repr_1, template: template_1)
      }.to raise_error(ArgumentError)
    end

    it "requires target to be a Representation" do
      expect {
        HalClient::SimpleLink.new(rel: rel_1, target: template_1)
      }.to raise_error(ArgumentError)
    end

    it "requires template to be an Addressable::Template" do
      expect {
        HalClient::TemplatedLink.new(rel: rel_1, template: repr_1)
      }.to raise_error(ArgumentError)
    end
  end

  describe ".new_from_link_entry" do
    it "creates an instance of Link" do
      my_link = described_class.new_from_link_entry(hash_entry: link_entry_hash(href: href_1),
                                                    hal_client: a_client,
                                                    curie_resolver: curie_resolver,
                                                    base_url: href_1)
      expect(my_link).to be_a(HalClient::Link)
    end

    it "handles relative hrefs" do
      input_hash = link_entry_hash(href: relative_href_1)
      base_url = Addressable::URI.parse(href_1)

      my_link = described_class.new_from_link_entry(hash_entry: input_hash,
                                                    hal_client: a_client,
                                                    curie_resolver: curie_resolver,
                                                    base_url: base_url)
      expect(my_link.raw_href).to eq((base_url + relative_href_1).to_s)
    end

    it "handles hrefs with a nil value" do
      input_hash = link_entry_hash(href: nil)
      base_url = Addressable::URI.parse(href_1)

      my_link = described_class.new_from_link_entry(hash_entry: input_hash,
                                                    hal_client: a_client,
                                                    curie_resolver: curie_resolver,
                                                    base_url: base_url)

      expect(my_link.raw_href).to eq(base_url.to_s)
    end
  end

  describe ".new_from_embedded_entry" do
    it "creates an instance of Link" do
      my_link = described_class.new_from_embedded_entry(hash_entry: embedded_entry_hash,
                                                        hal_client: a_client,
                                                        curie_resolver: curie_resolver,
                                                        base_url: href_1)
      expect(my_link).to be_a(HalClient::Link)
    end

    it "handles relative hrefs" do
      input_hash = embedded_entry_hash(href: relative_href_1)
      base_url = Addressable::URI.parse(href_1)

      my_link = described_class.new_from_embedded_entry(hash_entry: input_hash,
                                                        hal_client: a_client,
                                                        curie_resolver: curie_resolver,
                                                        base_url: base_url)
      expect(my_link.raw_href).to eq((base_url + relative_href_1).to_s)
    end
  end

  describe "#href" do
    specify { expect(link.raw_href).to eq('http://example.com/href_1') }
    specify { expect(templated_link1.raw_href).to eq('http://example.com/people{?name}') }
  end

  describe "#templated?" do
    specify { expect(link.templated?).to be false }
    specify { expect(templated_link1.templated?).to be true }
  end

  context "equality and hash" do
    let(:link_same_target_same_rel) { HalClient::SimpleLink.new(target: repr_1, rel: rel_1) }

    let(:link_same_target_diff_rel) { HalClient::SimpleLink.new(target: repr_1, rel: rel_2) }
    let(:link_diff_target_same_rel) { HalClient::SimpleLink.new(target: repr_2, rel: rel_1) }
    let(:link_diff_target_diff_rel) { HalClient::SimpleLink.new(target: repr_2, rel: rel_2) }

    let(:link_same_non_fetched) { HalClient::SimpleLink.new(target: href_only_repr, rel: rel_1) }

    let(:same_as_templated_link1) do
      HalClient::TemplatedLink
        .new(rel: 'templated_link',
             template: Addressable::Template.new('http://example.com/people{?name}'))
    end

    let(:templated_link2) do
      HalClient::TemplatedLink
        .new(rel: 'templated_link',
             template: Addressable::Template.new('http://example.com/places{?name}'))
    end

    let(:template_but_not_a_template) do
      HalClient::TemplatedLink
        .new(rel: 'rel_1',
             template: Addressable::Template.new('http://example.com/href_1'))
    end

    describe "#==" do
      specify { expect(link == link_same_target_same_rel).to eq true }
      specify { expect(link == link_same_non_fetched).to eq true }

      specify { expect(link == link_same_target_diff_rel).to eq false }
      specify { expect(link == link_diff_target_same_rel).to eq false }
      specify { expect(link == link_diff_target_diff_rel).to eq false }

      specify { expect(templated_link1 == same_as_templated_link1).to eq true }
      specify { expect(templated_link1 == templated_link2).to eq false }

      specify { expect(link == template_but_not_a_template).to eq false }

      specify { expect(full_uri_link_1 == curied_link_1).to eq true }

      specify { expect(link == Object.new).to eq false }
    end

    describe ".eql?" do
      specify { expect(link.eql? link_same_target_same_rel).to eq true }
      specify { expect(link.eql? link_same_non_fetched).to eq true }

      specify { expect(link.eql? link_same_target_diff_rel).to eq false }
      specify { expect(link.eql? link_diff_target_same_rel).to eq false }
      specify { expect(link.eql? link_diff_target_diff_rel).to eq false }

      specify { expect(templated_link1.eql? same_as_templated_link1).to eq true }
      specify { expect(templated_link1.eql? templated_link2).to eq false }

      specify { expect(link.eql? template_but_not_a_template).to eq false }

      specify { expect(full_uri_link_1.eql? curied_link_1).to eq true }

      specify { expect(link.eql? Object.new).to eq false }
    end

    describe "hash" do
      specify{ expect(link.hash).to eq link_same_target_same_rel.hash }
      specify{ expect(link.hash).to eq link_same_non_fetched.hash }

      specify{ expect(link.hash).to_not eq link_same_target_diff_rel.hash }
      specify{ expect(link.hash).to_not eq link_diff_target_same_rel.hash }
      specify{ expect(link.hash).to_not eq link_diff_target_diff_rel.hash }

      specify { expect(templated_link1.hash).to eq(same_as_templated_link1.hash) }
      specify { expect(templated_link1.hash).to_not eq(templated_link2.hash) }

      specify { expect(link.hash).to_not eq(template_but_not_a_template.hash)}

      specify { expect(full_uri_link_1.hash).to eq(curied_link_1.hash) }
    end

  end


  # Background

  let(:a_client) { HalClient.new }

  let(:rel_1) { 'rel_1' }
  let(:rel_2) { 'rel_2' }

  let(:full_uri_rel_1) { 'http://example.com/rels/rel_1' }
  let(:full_uri_link_1) { HalClient::SimpleLink.new(rel: full_uri_rel_1, target: repr_1) }

  let(:curie_resolver) do
    HalClient::CurieResolver.new({
                                   'name' => 'ex',
                                   'href' => 'http://example.com/rels/{rel}',
                                   'templated' => true
                                 })
  end

  let(:curied_rel_1) { 'ex:rel_1' }

  let(:curied_link_1) do
    HalClient::SimpleLink.new(rel: curied_rel_1, target: repr_1, curie_resolver: curie_resolver)
  end

  let(:href_1) { 'http://example.com/href_1' }
  let(:href_2) { 'http://example.com/href_2' }

  let(:relative_href_1) { 'path/to/href_1' }

  def link_entry_hash(options = {})
    href = options[:href] || href_1
    rel = options[:rel] || rel_1
    templated = options[:templated] || nil

    hash_data = { 'href' => href }
    hash_data['templated'] = templated if templated

    {
      rel: rel,
      data: hash_data
    }
  end

  def embedded_entry_hash(options = {})
    href = options[:href] || href_1
    rel = options[:rel] || rel_1

    {
      rel: rel,
      data: { '_links' => { 'self' => { 'href' => href } } }
    }
  end

  def raw_repr(options = {})
    href = options[:href] || href_1

    <<-HAL
      {
         "prop1": 1
        ,"prop2": 2
        ,"_links": {
          "self": { "href": "#{href}" }
          ,"link1": { "href": "http://example.com/bar" }
          ,"templated_link": { "href": "http://example.com/people{?name}"
                      ,"templated": true }
          ,"link3": [{ "href": "http://example.com/link3-a" }
                     ,{ "href": "http://example.com/link3-b" }]
        }
        ,"_embedded": {
          "embed1": {
            "_links": { "self": { "href": "http://example.com/baz" }}
          }
        }
      }
    HAL
  end

  def href_only_raw_repr(options = {})
    href = options[:href] || href_1

    <<-HAL
      {
        "_links": {
          "self": { "href": "#{href}" }
        }
      }
    HAL
  end

  def href_only_repr(options = {})
    href = options[:href] || href_1

    HalClient::Representation.new(hal_client: a_client,
                                  parsed_json: MultiJson.load(href_only_raw_repr(href: href)))
  end

  let(:repr_1) do
    HalClient::Representation.new(hal_client: a_client,
                                  parsed_json: MultiJson.load(raw_repr))
  end

  let(:repr_2) do
    HalClient::Representation.new(hal_client: a_client,
                                  parsed_json: MultiJson.load(raw_repr(href: href_2)))
  end

  let(:template_1) { Addressable::Template.new('http://example.com/people{?name}') }

  let(:templated_link1) { HalClient::TemplatedLink.new(rel: 'templated_link', template: template_1) }

end
