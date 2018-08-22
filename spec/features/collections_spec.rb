require "hal_client"

RSpec.describe "Collections" do
  include ApiStubber

  let(:client) { HalClient.new }

  it "supports treating rfc 6573 collections as enumerable" do
    stub_api do
      deflink("item", from: "http://blog.me/posts", to: "http://blog.me/posts/1")
      deflink("item", from: "http://blog.me/posts", to: "http://blog.me/posts/2")
    end

    collection = client.get("http://blog.me/posts").to_enum

    expect(collection).to behave_like_a Enumerable
    expect(collection).to have(2).items
    expect(collection).to include a_representation_of "http://blog.me/posts/1"
    expect(collection).to include a_representation_of "http://blog.me/posts/2"
  end

  it "supports multipage collections" do
    stub_api do
      deflink("item", from: "http://blog.me/posts", to: "http://blog.me/posts/1")
      deflink("item", from: "http://blog.me/posts", to: "http://blog.me/posts/2")
      deflink("next", from: "http://blog.me/posts", to: "http://blog.me/posts?p2")
      deflink("item", from: "http://blog.me/posts?p2", to: "http://blog.me/posts/3")
      deflink("item", from: "http://blog.me/posts?p2", to: "http://blog.me/posts/4")
    end

    collection = client.get("http://blog.me/posts").to_enum

    expect(collection).to behave_like_a Enumerable
    expect(collection).to have(4).items
    expect(collection).to include a_representation_of "http://blog.me/posts/1"
    expect(collection).to include a_representation_of "http://blog.me/posts/2"
    expect(collection).to include a_representation_of "http://blog.me/posts/3"
    expect(collection).to include a_representation_of "http://blog.me/posts/4"
  end

  # Background

  matcher :be_representation_of do |expected_url|
    match do |actual_repr|
      actual_repr.href == expected_url
    end
  end

  alias_matcher :a_representation_of, :be_representation_of
end