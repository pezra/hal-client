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

  matcher :be_equivalent_json_to do |expected_json|
    match do |actual_json|
      MultiJson.load(json(expected_json)) == MultiJson.load(json(actual_json))
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
end
