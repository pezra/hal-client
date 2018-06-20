require "hal_client/form"
require "hal-client"

RSpec.describe HalClient::Form do
  describe ".new" do
    specify { expect( HalClient::Form.new(fieldless_get_form, a_client) ).to behave_like_a HalClient::Form }
  end

  describe "#target_url" do
    context "vanilla target" do
      subject { HalClient::Form.new(fieldless_get_form, a_client) }

      specify { expect( subject.target_url ).to eq(Addressable::URI.parse("http://example.com")) }
    end

    context "templated target" do
      subject { HalClient::Form.new(get_form_with_fields_and_templated_target, a_client) }

      specify { expect( subject.target_url(rating: 4, description: "pretty good" ) )
                .to eq(Addressable::URI.parse("http://example.com/?description=pretty%20good&rating=4")) }

    end
  end

  describe "#submit" do
    context "fieldless GET form" do
      subject { HalClient::Form.new(fieldless_get_form, a_client) }
      let!(:get_request) { stub_request(:get, subject.target_url).to_return(body: "") }

      specify { expect{ subject.submit }.to make_http_request(get_request) }
    end

    context "GET form w/ fields and templated target" do
      subject { HalClient::Form.new(get_form_with_fields_and_templated_target, a_client) }

      specify {
        expect{
          subject.submit(rating: 4, description: "pretty good")
        }.to make_http_request(
               stub_request(:get, subject.target_url(rating: 4, description: "pretty good"))
             )
      }
    end

    context "POST form w/ fields and json content type" do
      subject { HalClient::Form.new(post_form_with_fields_and_json_content_type, a_client) }

      specify {
        expect{
          subject.submit(rating: "ok", description: "pretty good")
        }.to make_http_request(
               stub_request(:post, subject.target_url)
               .with(body: { rating: "ok", description: "pretty good" },
                     headers: { "Content-Type" => "application/json" })
             )
      }
    end

  end

  # Background

  def fieldless_get_form
    { "_links" => {
        "target" => {
          "href" => "http://example.com"
        }
      },
      "method" => "GET",
      "fields" => []
    }
  end

  def get_form_with_fields_and_templated_target
    { "_links" => {
        "target" => {
          "href" => "http://example.com/{?description,rating}",
          "templated" => true
        }
      },
      "method" => "GET",
      "fields" => [
        { "name" => "rating",
          "type" => "string" },
        { "name" => "description",
          "type" => "text" }
      ]
    }
  end

  def post_form_with_fields_and_json_content_type
    { "_links" => {
        "target" => {
          "href" => "http://example.com/"
        }
      },
      "method" => "POST",
      "contentType" => "application/json",
      "fields" => [
        { "name" => "rating",
          "type" => "number",
          "path" => "/rating" },
        { "name" => "description",
          "type" => "text",
          "path" => "/description" }
      ]
    }
  end

  def a_client
    HalClient.new
  end
end
