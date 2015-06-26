require_relative "./spec_helper"
require "hal_client"

describe HalClient do
  describe ".new()" do
    subject { HalClient.new }
    it { should be_kind_of HalClient }
  end

  subject(:client) { HalClient.new }

  describe '.new w/ custom accept' do
    subject { HalClient.new(accept: "application/vnd.myspecialmediatype") }
    it { should be_kind_of HalClient }
  end

  describe "#get(<url>)" do
    subject(:client) { HalClient.new }
    let!(:return_val) { client.get "http://example.com/foo" }

    it "returns a HalClient::Representation" do
      expect(return_val).to be_kind_of HalClient::Representation
    end

    describe "request" do
      subject { request }
      it("should have been made") { should have_been_made }

      it "sends accept header" do
        expect(request.with(headers: {'Accept' => /application\/hal\+json/i})).
          to have_been_made
      end
    end

    context "explicit accept" do
      subject(:client) { HalClient.new accept: 'app/test' }
      it "sends specified accept header" do
        expect(request.with(headers: {'Accept' => /app\/test/i})).
          to have_been_made
      end
    end

    context "explicit content type" do
      subject(:client) { HalClient.new content_type: 'custom' }
      it "does not send the content type header" do
        expect(request.with(headers: {'Accept' => /application\/hal\+json/i})).to have_been_made
      end
    end

    context "explicit authorization helper" do
      subject(:client) { HalClient.new authorization: ->(_url) { "Bearer hello" } }
      it "sends specified accept header" do
        expect(request.with(headers: {'Authorization' => "Bearer hello"})).
          to have_been_made
      end
    end

    context "explicit authorization string" do
      subject(:client) { HalClient.new authorization: "Bearer hello" }
      it "sends specified accept header" do
        expect(request.with(headers: {'Authorization' => "Bearer hello"})).
          to have_been_made
      end
    end

    context "other headers" do
      let(:headers) { {"Authorization" => "Bearer f73c04b0970f1deb6005fab53edd1708"} }
      subject(:client) { HalClient.new headers: headers }
      it "sends the supplied header" do
        expect(request.with(headers: headers)).to have_been_made
      end
    end

    context "header overrides" do
      let!(:return_val) { client.get "http://example.com/foo", { "DummyHeader" => "Test" } }
      it "sends the supplied header" do
        expect(request.with(headers: { "DummyHeader" => "Test" })).to have_been_made
      end
    end
  end

  context "server responds with client error" do
    let!(:request) { stub_request(:any, "http://example.com/foo").
      to_return body: "Bad client! No cookie!", status: 400  }

    it "#get raises HttpClientError" do
      expect{client.get "http://example.com/foo"}.to raise_exception HalClient::HttpClientError
    end

    it "#get attaches response to the raised error" do
      err = client.get("http://example.com/foo") rescue $!
      expect(err.response).to be_kind_of HTTP::Response
    end


    it "#post raises HttpClientError" do
      expect{client.post "http://example.com/foo", "foo"}.to raise_exception HalClient::HttpClientError
    end

    it "#post attaches response to the raise error" do
      err = client.post("http://example.com/foo", "") rescue $!
      expect(err.response).to be_kind_of HTTP::Response
    end
  end

  context "server responds with server error" do
    let!(:request) { stub_request(:any, "http://example.com/foo").
      to_return body: "Bad server! No cookie!", status: 500  }

    it "#get raises HttpServerError" do
      expect{client.get "http://example.com/foo"}.to raise_exception HalClient::HttpServerError
    end

    it "#get attaches response to the raised error" do
      err = client.get("http://example.com/foo") rescue $!
      expect(err.response).to be_kind_of HTTP::Response
    end


    it "#post raises HttpServerError" do
      expect{client.post "http://example.com/foo", "foo"}.to raise_exception HalClient::HttpServerError
    end

    it "#post attaches response to the raise error" do
      err = client.post("http://example.com/foo", "") rescue $!
      expect(err.response).to be_kind_of HTTP::Response
    end
  end

  describe ".get(<url>)" do
    let!(:return_val) { HalClient.get "http://example.com/foo" }

    it "returns a HalClient::Representation" do
      expect(return_val).to be_kind_of HalClient::Representation
    end

    describe "request" do
      subject { request }
      it("should have been made") { should have_been_made }

      it "sends accept header" do
        expect(request.with(headers: {'Accept' => /application\/hal\+json/})).
          to have_been_made
      end
    end
  end

  describe "#post(<url>)" do
    subject(:client) { HalClient.new }
    let(:url) { "http://example.com/foo" }
    let(:return_val) { client.post url, post_data }

    it "returns a HalClient::Representation" do
      expect(return_val).to be_kind_of HalClient::Representation
    end

    context "201 response w/ location header and w/o body" do
      let(:url) { "http://example.com/lhnb" }
      let!(:req) { stub_request(:post, url).
                     to_return(status: 201,
                               body: nil,
                               headers: {"Location" => "http://example.com/new"})
      }

      it "returns a HalClient::Representation" do
        expect(return_val).to be_kind_of HalClient::Representation
      end

      it "returns representation of new resource" do
        expect(return_val.href).to eq "http://example.com/new"
      end
    end

    describe "request" do
      before do return_val end
      subject { post_request }
      it("should have been made") { should have_been_made }

      it "sends content type header" do
        expect(post_request.with(headers: {'Content-Type' => 'application/hal+json'})).
          to have_been_made
      end
    end

    describe "request with different content type" do
      let(:return_val) { client.post url, post_data, "Content-Type" => "text/plain" }
      before do return_val end
      subject { post_request }
      it("should have been made") { should have_been_made }

      it "sends content type header" do
        expect(post_request.with(headers: {'Content-Type' => 'text/plain'})).
          to have_been_made
      end
    end

    context "explicit content type" do
      before do return_val end
      subject(:client) { HalClient.new content_type: 'app/test' }
      it "sends specified content-type header" do
        expect(post_request.with(headers: {'Content-Type' => 'app/test'})).
          to have_been_made
      end
    end

    context "other headers" do
      before do return_val end
      let(:headers) { {"Authorization" => "Bearer f73c04b0970f1deb6005fab53edd1708"} }
      subject(:client) { HalClient.new headers: headers }
      it "sends the supplied header" do
        expect(post_request.with(headers: headers)).to have_been_made
      end
    end

    context "with no response body and no location header" do
      subject { empty_post_request }
      let!(:return_val) { client.post "http://example.com/foo", nil }

      it "returns a 2xx status code in the response" do
        expect(return_val.code.to_s).to match(/^2../)
      end
    end
  end

  describe ".post(<url>)" do
    let!(:return_val) { HalClient.post "http://example.com/foo", post_data }

    it "returns a HalClient::Representation" do
      expect(return_val).to be_kind_of HalClient::Representation
    end

    describe "request" do
      subject { post_request }
      it("should have been made") { should have_been_made }

      it "sends accept header" do
        expect(post_request.with(headers: {'Content-Type' => 'application/hal+json'})).
          to have_been_made
      end
    end
  end

  describe ".delete(<url>)" do
    subject { HalClient.delete "http://example.com/foo" }

    it "returns a HalClient::Representation" do
      expect(subject).to be_kind_of HalClient::Representation
    end
  end

  describe "#delete(<url>)" do
    subject { HalClient.new.delete "http://example.com/foo" }

    it "returns a HalClient::Representation" do
      expect(subject).to be_kind_of HalClient::Representation
    end
  end

  context "get request redirection" do
    let!(:request) { stub_request(:get, "http://example.com/foo").
      to_return(status: 301, headers: { 'Location' => "http://example.com/bar" } ) }

    let!(:second_req) { stub_request(:get, "http://example.com/bar").
      to_return(body: "{}") }

    let!(:response) { client.get "http://example.com/foo" }

    it "follows redirects" do
      expect(second_req).to have_been_made
    end
  end


  let(:post_data) { "ABC" }

  let!(:empty_post_request) { stub_request(:post, "http://example.com/foo").
    with(:body => nil).
    to_return body: nil }

  let!(:post_request) { stub_request(:post, "http://example.com/foo").
    with(:body => post_data).
    to_return body: "{}" }

  let!(:delete_request) { stub_request(:delete, "http://example.com/foo").
    to_return body: "{}" }

  let!(:request) { stub_request(:get, "http://example.com/foo").
    to_return body: "{}" }
end
