require 'hal_client/form/field'
require 'hana'

class HalClient

  # A single [Dwolla HAL
  # form](https://github.com/Dwolla/hal-forms). Instances of this
  # class allow client so complete and submit individual forms.
  #
  # This is an incomplete implementation of the spec. Thus far it
  # supports string and hidden fields with JSON encoding. Enhancements
  # are requested.
  class Form

    # Initializes a newly created form
    #
    # parsed_json - a Hash create by parsing the JSON.
    # hal_client - the `HalClient` with which to submit the new form.
    def initialize(parsed_json, hal_client)
      @hal_client = hal_client
      @target_tmpl = extract_target_tmpl(parsed_json)
      @method = extract_method(parsed_json)
      @content_type = extract_content_type(parsed_json)
      @fields = extract_fields(parsed_json)
    end


    # Returns the `Addressable::URI` to which this form is targeted
    def target_url(answers={})
      target_tmpl.expand(answers)
    end

    # Returns the `HalClient::Representation` returned from submitting
    # the form.
    #
    # answers - `Hash` containing the answer key to submit. Keys are
    # be the field names; values are the values to submit.
    def submit(answers={})
      if :get == method
        hal_client.get(target_url(answers))
      else
        hal_client.public_send(method, target_url(answers), body(answers), "Content-Type" => content_type)
      end
    end

    protected

    attr_reader :target_tmpl, :method, :hal_client, :content_type, :fields

    def extract_target_tmpl(parsed_json)
      tmpl_str = parsed_json
                 .fetch("_links")
                 .fetch("target")
                 .fetch("href")

      Addressable::Template.new(tmpl_str)

    rescue KeyError
      raise ArgumentError, "form has no target href"
    end

    def extract_method(parsed_json)
      parsed_json
        .fetch("method")
        .downcase
        .to_sym

    rescue KeyError
      raise ArgumentError, "form doesn't specify a method"
    end

    def extract_content_type(parsed_json)
      return nil if :get == method

      parsed_json
        .fetch("contentType") { raise  ArgumentError, "form doesn't specify a content type" }
    end

    def extract_fields(parsed_json)
      parsed_json
        .fetch("fields") { raise  ArgumentError, "form doesn't have a field member" }
        .map { |field_json| Field.new(field_json) }
    end

    def body(answers)
      case content_type
      when /json$/i
        build_json_body(answers)
      else
        raise NotImplementedError, "#{content_type} is not a supported content type"
      end
    end

    def build_json_body(answers)
      fields.reduce({}) { |body_thus_far, field|
        json_inject_answer(body_thus_far, field.extract_answer(answers), field.path)
      }
    end

    def json_inject_answer(body, answer, path)
      patch = Hana::Patch.new [
        { 'op' => 'add', 'path' => path, 'value' => answer }
      ]

      patch.apply(body)
    end
  end
end
