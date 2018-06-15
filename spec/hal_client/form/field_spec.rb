require "hal_client/form/field"

RSpec.describe HalClient::Form::Field do
  describe ".new" do
    specify { expect(
                described_class.new({"name" => "rating", "type" => "string"})
              ).to behave_like_a described_class }
    specify { expect(
                described_class.new({ "name" => "rating",
                                      "type" => "string",
                                      "path" => "/foo/bar",
                                      "value" => "ok",
                                      "displayText" => "Rating",
                                      "validations" => {
                                        "required" => true,
                                        "regex" => "(good)|(ok)|(bad)"
                                      },
                                      "multiple" => true,
                                      "accepted" => {
                                        "groupedValues" => [
                                          { "key" => "group1",
                                            "displayText" => "Group 1",
                                            "values" => [
                                              { "value" => "val1id",
                                                "key" => "val1",
                                                "displayText" => "Value 1"
                                              }
                                            ]
                                          }
                                        ]
                                      }
                                    })
              ).to behave_like_a described_class }
  end

  describe "#extract_answer(answers)" do
    context "no default value" do
      subject { described_class.new(string_field_json) }

      it "handles string answer keys" do
        expect(
          subject.extract_answer("rating" => "bad")
        ).to eq "bad"
      end

      it "coerces non-string answers" do
        expect(
          subject.extract_answer("rating" => URI("http://example.com/ratings/good"))
        ).to eq "http://example.com/ratings/good"
      end

      it "handles symbol answer keys" do
        expect(
          subject.extract_answer(rating: "bad")
        ).to eq "bad"
      end

      it "returns nil if answer is missing" do
        expect(
          subject.extract_answer(foo: 1)
        ).to be nil
      end
    end

    context "with default value" do
      subject {
        described_class.new(field_json(name: "rating", value: "ok"))
      }

      it "returns default value when answer is missing" do
        expect(
          subject.extract_answer(foo: 1)
        ).to eq "ok"
      end

      it "returns answer when available" do
        expect(
          subject.extract_answer(rating: "bad")
        ).to eq "bad"
      end

    end

    context "hidden field" do
      subject {
        described_class.new(field_json(type: "hidden", name: "rating", value: "ok"))
      }

      it "ignore answer and use default" do
        expect(
          subject.extract_answer(rating: "bad")
        ).to eq "ok"
      end
    end
  end

  describe "#path" do
    context "path explicitly specified" do
      subject { described_class.new(field_json(path: "/rating/value")) }

      it "returns the path" do
        expect(
          subject.path
        ).to eq "/rating/value"
      end
    end

    context "path omitted" do
      subject { described_class.new(field_json(path: MISSING)) }

      it "returns the path" do
        expect(
          subject.path
        ).to be nil
      end
    end
  end

  MISSING = Object.new

  def field_json(type: "string", name: "rating", path: MISSING, value: MISSING)
    { "name" => name,
      "type" => type }
    .tap{|f|
      f["path"] = path if provided?(path)
      f["value"] = value if provided?(value)
    }
  end

  def provided?(thing)
    MISSING != thing
  end

  def string_field_json
    field_json(type: "string")
  end

  def string_field_json_with_default
    field_json(type: "string", value: "ok")
  end

  def hidden_field_json
    field_json(type: "hidden", value: "ok")
  end

end
