require "hal_client"

RSpec.describe "Properties on single representation" do
  include ApiStubber

  let(:client) { HalClient.new }

  it "allows accessing string properties" do
    stub_api do
      defresource("http://blog.me/",
                 "title" => "My Blog")
    end

    entrypoint = client.get("http://blog.me/")

    expect(
      entrypoint.property("title")
    ).to eq "My Blog"
  end

  it "allows accessing number properties" do
    stub_api do
      defresource("http://blog.me/",
                 "visitorCount" => 42)
    end

    entrypoint = client.get("http://blog.me/")

    expect(
      entrypoint.property("visitorCount")
    ).to eq 42
  end

  it "allows accessing null properties" do
    stub_api do
      defresource("http://blog.me/",
                 "tagLine" => nil)
    end

    entrypoint = client.get("http://blog.me/")

    expect(
      entrypoint.property("tagLine")
    ).to be nil
  end

  it "allows accessing object properties" do
    stub_api do
      defresource("http://blog.me/",
                  "geo" => {"latitude" => 39.73, "longitude" => -104.96})
    end

    entrypoint = client.get("http://blog.me/")

    expect(
      entrypoint.property("geo")
    ).to eq({"latitude" => 39.73, "longitude" => -104.96})
  end

  it "allows accessing list properties" do
    stub_api do
      defresource("http://blog.me/",
                  "categories" => ["personal", "professional"])
    end

    entrypoint = client.get("http://blog.me/")

    expect(
      entrypoint.property("categories")
    ).to match ["personal", "professional"]
  end

    it "provides hash like interface for properties" do
    stub_api do
      defresource("http://blog.me/",
                 "title" => "My Blog")
    end

    entrypoint = client.get("http://blog.me/")

    expect(
      entrypoint["title"]
    ).to eq "My Blog"
  end

  it "allows specifying default values" do
    stub_api do
      defresource("http://blog.me/")
    end

    entrypoint = client.get("http://blog.me/")

    expect(
      entrypoint.property("nonexistent") { "my default value"}
    ).to eq "my default value"
  end

end