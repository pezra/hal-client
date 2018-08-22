require "hal_client"

RSpec.describe "Unsafe (PUT, POST, etc) requests" do
  include ApiStubber

  let(:client) { HalClient.new }

  it "allows PUTting to a resource" do
    stub_api do
      defresource("http://blog.me/", "title" => "My Blog")
    end

    expect(
      client.get("http://blog.me/")
      .put('{ "title": "Her Blog" }')
    ).to be_kind_of HalClient::Representation

    expect(WebMock)
      .to have_requested(:put, "http://blog.me/")
           .with(headers: {'Content-Type' => 'application/hal+json'},
                 body: '{ "title": "Her Blog" }')
  end

  it "allows POSTing to a resource" do
    stub_api do
      defresource("http://blog.me/posts")
    end

    expect(
      client.get("http://blog.me/posts")
      .post('{ "title": "My new post" }')
    ).to be_kind_of HalClient::Representation

    expect(WebMock)
      .to have_requested(:post, "http://blog.me/posts")
           .with(headers: {'Content-Type' => 'application/hal+json'},
                 body: '{ "title": "My new post" }')
  end

  it "allows PATCHing to a resource" do
    stub_api do
      defresource("http://blog.me/posts/1")
    end

    expect(
      client.get("http://blog.me/posts/1")
      .patch('{ "title": "My old post" }')
    ).to be_kind_of HalClient::Representation

    expect(WebMock)
      .to have_requested(:patch, "http://blog.me/posts/1")
           .with(headers: {'Content-Type' => 'application/hal+json'},
                 body: '{ "title": "My old post" }')
  end


end