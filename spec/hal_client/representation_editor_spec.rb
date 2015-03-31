require_relative "../spec_helper"
require "hal_client/representation_editor"

RSpec.describe HalClient::RepresentationEditor do
  describe "creation" do
    it "take a representation" do
      expect(described_class.new(a_repr)).to be_kind_of described_class
    end
  end

  subject { described_class.new(a_repr) }

  specify { expect(subject.to_hal).to be_equivalent_json_to raw_hal }
  specify { expect(subject.to_json).to be_equivalent_json_to raw_hal }

  describe "#reject_links" do
    specify { expect(subject.reject_links("up")).not_to have_link "up" }

    it "removes links matching block but not others" do
      altered = subject.reject_links("up") {|repr| %r|/c1$| === repr.href }

      expect(altered).not_to have_link "up", with_href("http://example.com/c1")
      expect(altered).to     have_link "up", with_href("http://example.com/c2")
    end

    specify { expect(subject.reject_links("absent-rel")).to be_equivalent_json_to raw_hal }
    specify { expect(subject.reject_links("about") {|repr| %r|/another$| === repr.href })
              .not_to have_link "about" }
  end

  describe "#reject_embedded" do
    specify { expect(subject.reject_embedded("replies"))
              .not_to have_embedded "replies" }
    specify { expect(subject.reject_embedded("absent-rel"))
              .to be_equivalent_json_to raw_hal }

    it "removes links matching block but not others" do
      altered = subject.reject_embedded("replies") {|repr|  "+1" == repr.property("value") }

      expect(altered).not_to have_embedded "replies", hash_including("value" => "+1")
      expect(altered).to     have_embedded "replies", hash_including("value" => "-1")
    end
  end

  describe "#reject_related" do
    it "rejects from links section" do
      altered = subject.reject_related("up")

      expect(altered).not_to have_link("up")
      expect(altered).not_to have_embedded("up")
    end

    it "rejects from links section matching block" do
      altered = subject.reject_related("up") { |it| %r|/c1$| === it.href }

      expect(altered).not_to have_link "up", with_href("http://example.com/c1")
      expect(altered).to     have_link "up", with_href("http://example.com/c2")
      expect(altered).not_to have_embedded("up")
    end


    it "rejects from embedded section" do
      altered = subject.reject_related("replies")

      expect(altered).not_to have_link("replies")
      expect(altered).not_to have_embedded("replies")
    end

    it "rejects from embedded section matching block" do
      altered = subject.reject_related("replies") {|it| it["value"] == "+1" }

      expect(altered).not_to have_link("replies", hash_including("value" => "+1"))
      expect(altered).not_to have_embedded("replies", hash_including("value" => "+1"))

      expect(altered).to have_link("replies", hash_including("value" => "-1"))
                          .or(have_embedded("replies", hash_including("value" => "-1")))

    end

    specify { expect(subject.reject_related("absent-rel"))
              .to be_equivalent_json_to raw_hal }

  end

  describe "#add_property" do
    it "adds brand new property" do
      expect(subject.add_property("name", "new-name"))
        .to have_property("name", "new-name")
    end

    it "overwrites any previous value in the property" do
      expect(subject).to have_property("age", 10)
      expect(subject.add_property("age", 20)).to have_property("age", 20)
    end
  end

  describe "#add_link" do
    it "adds brand new link rel" do
      expect(subject.add_link("related", "http://example.com/third"))
        .to have_link("related", with_href("http://example.com/third")
                                 .and(not_templated))
    end

    it "adds without replacing existing links" do
      expect(subject.add_link("about", "http://example.com/third"))
        .to have_link("about", with_href("http://example.com/third"))
             .and have_link("about", with_href("http://example.com/another"))
    end

    it "adds templated links" do
      expect(subject.add_link("related", "http://example.com/third{?wat}", templated: true))
        .to have_link "related", with_href("http://example.com/third{?wat}")
                                 .and(be_templated)
    end
  end

  # Background

  let(:a_repr) { HalClient::Representation
                 .new(parsed_json: MultiJson.load(raw_hal)) }

  let(:raw_hal) { <<-HAL }
    { "age": 10
      ,"_links": {
        "self"  : { "href": "http://example.com/a_repr" }
        ,"up"   : [{ "href": "http://example.com/c1" },
                  { "href": "http://example.com/c2" }]
        ,"about": { "href": "http://example.com/another" }
      }
      ,"_embedded": {
        "replies": [
          { "value": "+1" }
          ,{"value": "-1" }
        ]
       }
    }
  HAL

  ANYTHING = ->(_) { true }

  matcher :be_templated do
    match do |actual|
      true == actual["templated"]
    end
  end

  matcher :not_templated do
    match do |actual|
      true != actual["templated"]
    end
  end

  matcher :with_href do |expected_url|
    match do |actual|
      expected_url === actual["href"]
    end
  end

  matcher :have_link do |expected_rel, expected_target=ANYTHING|
    match do |actual_json|
      parsed = MultiJson.load(actual_json.to_hal)

      [parsed["_links"].fetch(expected_rel, [])].flatten
        .any?{|l| expected_target === l }
    end
  end

  matcher :have_property do |key, value|
    match do |actual_json|
      parsed = MultiJson.load(actual_json.to_hal)
      expect(parsed[key]).to eq value
    end
  end

  matcher :have_embedded do |expected_rel, expected_target=ANYTHING|
    match do |actual_json|
      parsed = MultiJson.load(actual_json.to_hal)

      [parsed["_embedded"].fetch(expected_rel, [])].flatten
        .any?{|e| expected_target === e }
    end
  end
end
