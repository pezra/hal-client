require 'hal_client/curie_resolver'

describe HalClient::CurieResolver do
  describe "#new" do
    it "takes an array of curie definitions" do
      expect(described_class.new([f_ns, b_ns])).to be_kind_of described_class
    end

    it "takes a single curie definition" do
      expect(described_class.new(f_ns)).to be_kind_of described_class
    end
  end

  subject(:resolver) { described_class.new([f_ns, b_ns]) }

  describe "#resolve" do
    it "returns rel name given a standard rel name" do
      expect(resolver.resolve("item")).to eq "item"
    end

    it "returns url given a fully qualified url" do
      expect(resolver.resolve("http://example.com/foo")).to eq "http://example.com/foo"
    end

    it "returns expanded url given a curie in known namespace" do
      expect(resolver.resolve("f:yer")).to eq "foo:yer"
    end

    it "returns unexpanded curie given a curie in unknown namespace" do
      expect(resolver.resolve("ex:yer")).to eq "ex:yer"
    end
  end

  let(:f_ns) { {"name" => "f", "href" => "foo:{rel}", "templated" => true} }
  let(:b_ns) { {"name" => "b", "href" => "bar:{rel}", "templated" => true} }
end
