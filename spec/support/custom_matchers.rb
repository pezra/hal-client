module CustomMatchers
  extend RSpec::Matchers::DSL

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
end
