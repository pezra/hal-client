require 'hal_client/collection'

RSpec.describe HalClient::Collection do
  # BACKGROUND

  shared_context "multi-item, multi-page" do
    subject(:collection) { described_class.new(first_page) }
    let!(:second_page_req) { stub_request(:get, second_page.href)
                             .to_return body: second_page.to_json  }

    let(:first_page_href) { "http://example.com/p1" }
    let(:first_page) { collection_page(next_href: second_page_href,
                                       self_href: first_page_href,
                                       items: ["foo", "bar"]) }

    let(:second_page_href) { "http://example.com/p2" }
    let(:second_page) { collection_page(items: ["baz"],
                                        self_href: second_page_href,
                                        prev_href: first_page_href) }

  end

  shared_context "multi-item, single page" do
    subject(:collection) { described_class.new(only_page) }

    let(:only_page) { collection_page(self_href: "http://example.com/p1",
                                       items: ["foo", "bar"]) }
  end

  # END OF BACKGROUND

  describe "creation" do
    subject { described_class }

    specify do
      expect { described_class.new(collection_page) }
        .not_to raise_error
    end

    specify do
      expect { described_class.new(non_first_page) }
        .to raise_error ArgumentError, /first page/
    end

    let(:non_first_page) { collection_page(prev_href: "http://example.com/p1") }
  end

  describe "#each" do
    context do
      include_context "multi-item, multi-page"

      it "fetches all the pages when iterating" do
        collection.each do |it| end

        expect(a_request(:get, second_page.href)).to have_been_made
      end

      it "yields all the items" do
        yielded = collection.map { |it| it.href }
        expect(yielded).to eq ["foo", "bar", "baz"]
      end

    end
  end

  describe "#count" do
    context do
      include_context "multi-item, single page"

      specify { expect(collection.count).to eq 2 }
    end

    context do
      include_context "multi-item, multi-page"

      specify { expect { collection.count }.to raise_exception(NotImplementedError) }
    end
  end

  describe "#sample" do
    include_context "multi-item, multi-page"

    specify { expect( collection.sample ).to be }
    specify { expect( collection.sample ).to be_kind_of HalClient::Representation }
  end

  # BACKGROUND

  let(:hal_client) { HalClient.new }

  def collection_page(opts={})
    next_href = opts[:next_href]
    prev_href = opts[:prev_href]
    self_href = opts.fetch(:self_href, "a_page")
    items = opts.fetch(:items, [])
      .map{|it| {"_links"=>{"self"=>{"href"=>it}}} }

    full = {"_embedded"=>{"item"=>items},
      "_links"=>{"self"=>{"href"=>self_href}}}
    full["_links"]["next"] = {"href" => next_href} if next_href
    full["_links"]["prev"] = {"href" => prev_href} if prev_href

    repr full
  end

  def repr(a_hash)
    HalClient::Representation.new parsed_json: a_hash, hal_client: hal_client
  end
end
