require "hal_client"

RSpec.describe "Navigation" do
  include ApiStubber

  let(:client) { HalClient.new }

  it "allows visiting a resource" do
    stub_api do
      defresource("http://blog.me/")
    end

    entrypoint = client.get("http://blog.me/")

    expect(entrypoint).to behave_like_a HalClient::Representation
    expect(entrypoint).to be_representation_of "http://blog.me/"
  end

  it "allows following a simple link" do
    stub_api do
      deflink("author", from: "http://blog.me/", to: "http://blog.me/john-doe")
    end

    destination = client.get("http://blog.me/")
                  .related("author")

    expect(destination).to behave_like_a HalClient::RepresentationSet
    expect(destination).to include a_representation_of "http://blog.me/john-doe"
  end

  it "allows following a simple link with curied rel" do
    stub_api do
      deflink("curies", from: "http://blog.me/", to: "http://myschema.org/{rel}", name: "blog", templated: true)
      deflink("blog:posts", from: "http://blog.me/", to: "http://blog.me/posts")
    end

    destination = client.get("http://blog.me/")
                  .related("blog:posts")

    expect(destination).to behave_like_a HalClient::RepresentationSet
    expect(destination).to include a_representation_of "http://blog.me/posts"
  end

  it "allows following a simple link with fully qualified rel" do
    stub_api do
      deflink("curies", from: "http://blog.me/", to: "http://myschema.org/{rel}", name: "blog", templated: true)
      deflink("blog:posts", from: "http://blog.me/", to: "http://blog.me/posts")
    end

    destination = client.get("http://blog.me/")
                  .related("http://myschema.org/posts")

    expect(destination).to behave_like_a HalClient::RepresentationSet
    expect(destination).to include a_representation_of "http://blog.me/posts"
  end

  it "allows following a multiple links with the same rel" do
    stub_api do
      deflink("item", from: "http://blog.me/", to: "http://blog.me/posts/1")
      deflink("item", from: "http://blog.me/", to: "http://blog.me/posts/2")
    end

    posts = client.get("http://blog.me/")
            .related("item")

    expect(posts).to behave_like_a HalClient::RepresentationSet
    expect(posts).to include a_representation_of "http://blog.me/posts/1"
    expect(posts).to include a_representation_of "http://blog.me/posts/2"
  end

  it "allows following same rel from multiple 'currents'" do
    stub_api do
      deflink("item", from: "http://blog.me/", to: "http://blog.me/posts/1")
      deflink("item", from: "http://blog.me/", to: "http://blog.me/posts/2")

      deflink("author", from: "http://blog.me/posts/1", to: "http://blog.me/john-doe")
      deflink("author", from: "http://blog.me/posts/2", to: "http://blog.me/john-doe")
    end

    post_authors = client.get("http://blog.me/")
                   .related("item")
                   .related("author")

    expect(post_authors).to behave_like_a HalClient::RepresentationSet
    expect(post_authors).to include a_representation_of "http://blog.me/john-doe"
  end

  it "allows checking if link exists" do
    stub_api do
      deflink("author", from: "http://blog.me/", to: "http://blog.me/john-doe")
    end

    expect(
      client.get("http://blog.me/").related?("author")
    ).to be true

    expect(
      client.get("http://blog.me/").related?("nonexistent")
    ).to be false
  end

  it "allows following an embedded link" do
    stub_api do
      defembedded("author", from: "http://blog.me/", to: "http://blog.me/john-doe")
    end

    destination = client.get("http://blog.me/")
                  .related("author")

    expect(destination).to behave_like_a HalClient::RepresentationSet
    expect(destination).to include a_representation_of "http://blog.me/john-doe"
  end

  it "allows following a relative link" do
    stub_api do
      deflink("author", from: "http://blog.me/", to: "/john-doe")
    end

    destination = client.get("http://blog.me/")
                  .related("author")

    expect(destination).to behave_like_a HalClient::RepresentationSet
    expect(destination).to include a_representation_of "http://blog.me/john-doe"
  end


  # Background

end