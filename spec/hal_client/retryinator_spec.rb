require 'hal_client/errors'
require 'hal_client/retryinator'

RSpec.describe HalClient::Retryinator do

  let(:max_tries) { 5 }
  let(:mock_response) { double(Http::Response, body: '', code: 200)}
  subject { described_class.new(max_tries: max_tries, duration: 0) }

  context "the passed block always raises an error" do
    let(:never_the_charm) { CharmMaker.new(:never, mock_response) }

    it "raises an error and tries the maximum number of times" do
      expect do
        subject.retryable { never_the_charm.call }
      end.to raise_error(HalClient::HttpError)

      expect(never_the_charm.attempts_made).to eq(max_tries)
    end
  end

  context "the server returns a success response" do
    let(:first_time_is_the_charm) { CharmMaker.new(1, mock_response) }

    it "returns the response" do
      expect(subject.retryable {first_time_is_the_charm.call}).to eq(first_time_is_the_charm.response)
    end

    it "calls the block once" do
      subject.retryable { first_time_is_the_charm.call }

      expect(first_time_is_the_charm.attempts_made).to eq(1)
    end
  end

  context "the server returns an error response" do
    before do
      allow(mock_response).to receive(:code).and_return(500)
    end

    let(:returns_error_reponses) { CharmMaker.new(1, mock_response) }

    it "retries the request the maximum number of times" do
      subject.retryable { returns_error_reponses.call }

      expect(returns_error_reponses.attempts_made).to eq(max_tries)
    end

    it "returns the response" do
      expect(subject.retryable { returns_error_reponses.call }).to eq(returns_error_reponses.response)
    end
  end

  class CharmMaker
    attr_accessor :attempts_made, :charm, :response

    def initialize(charm, response)
      @attempts_made = 0
      @charm = charm
      @response = response
    end

    def call
      self.attempts_made = self.attempts_made + 1

      if charm == :never || self.attempts_made < charm
        raise HalClient::HttpError.new("message", response)
      else
        response
      end
    end
  end

end
