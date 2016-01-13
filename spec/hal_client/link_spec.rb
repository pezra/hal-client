require 'hal-client'

require_relative "../spec_helper"

require "hal_client/link"

describe HalClient::Link do

  subject(:link) { described_class.new(rel: rel_1, target: repr_1) }

  # Background

  let(:a_client) { HalClient.new }

  let(:rel_1) { 'rel_1' }
  let(:rel_2) { 'rel_2' }

  let(:href_1) { 'http://example.com/href_1' }
  let(:href_2) { 'http://example.com/href_2' }

  def raw_repr(href: href_1)
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

  def raw_repr2(href: href_1)
    <<-HAL
      {
        "_links": {
          "self": { "href": "#{href}" }
        }
      }
    HAL
  end

  let(:repr_1) do
    HalClient::Representation.new(hal_client: a_client,
                                  parsed_json: MultiJson.load(raw_repr))
  end

  let(:repr_2) do
     HalClient::Representation.new(hal_client: a_client,
                                  parsed_json: MultiJson.load(raw_repr(href: href_2)))
  end

  let(:repr_1_non_fetched) do
    HalClient::Representation.new(hal_client: a_client,
                                  parsed_json: MultiJson.load(raw_repr2))
  end

  let(:templated_link1) do
    HalClient::Link.new(rel: 'templated_link',
                        template: Addressable::Template.new('http://example.com/people{?name}'))
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
    let(:link_same_target_same_rel) { HalClient::Link.new(target: repr_1, rel: rel_1) }

    let(:link_same_target_diff_rel) { HalClient::Link.new(target: repr_1, rel: rel_2) }
    let(:link_diff_target_same_rel) { HalClient::Link.new(target: repr_2, rel: rel_1) }
    let(:link_diff_target_diff_rel) { HalClient::Link.new(target: repr_2, rel: rel_2) }

    let(:link_same_non_fetched) { HalClient::Link.new(target: repr_1_non_fetched, rel: rel_1) }

    let(:same_as_templated_link1) do
      HalClient::Link.new(rel: 'templated_link',
                          template: Addressable::Template.new('http://example.com/people{?name}'))
    end

    let(:templated_link2) do
      HalClient::Link.new(rel: 'templated_link',
                          template: Addressable::Template.new('http://example.com/places{?name}'))
    end

    let(:template_but_not_a_template) do
      HalClient::Link.new(rel: 'rel_1',
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
    end

  end


end