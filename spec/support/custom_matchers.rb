module CustomMatchers
  extend RSpec::Matchers::DSL
  matcher :behave_like_a do |expected_class|
    match do |actual_instance|
      (expected_methods(expected_class) - actual_instance.methods).empty?
    end

    failure_message do |actual_instance|
      missing_methods = (expected_methods(expected_class) - actual_instance.methods)

      "expected #{actual_instance} to behave like a #{expected_class} but it was missing #{missing_methods.inspect}"
    end

    def expected_methods(klass)
      klass.instance_methods - Object.instance_methods
    end
  end
  alias_matcher :behave_like_an, :behave_like_a

  matcher :be_equivalent_json_to do |expected_json|
    match do |actual_json|
      @actual = MultiJson.dump(MultiJson.load(json(actual_json)), :pretty => true)

      expected_repr = HalClient::Interpreter.new(MultiJson.load(json(expected_json))).extract_repr
      actual_repr = HalClient::Interpreter.new(MultiJson.load(json(actual_json))).extract_repr

      MultiJson.dump(expected_repr.to_json) == MultiJson.dump(actual_repr.to_json)
    end

    protected

    def json(jsonish)
      if String === jsonish
        jsonish
      else
        jsonish.to_json
      end
    end
  end

  matcher :make_http_request do |expected_request|
    match do |actual_code_under_test|
      actual_code_under_test.call()
      expect(expected_request).to have_been_made
    end

    def supports_block_expectations?
      true
    end
  end

  matcher :be_representation_of do |expected_url|
    match do |actual_repr|
      actual_repr.location == Addressable::URI.parse(expected_url)
    end
  end
  alias_matcher :a_representation_of, :be_representation_of
end
