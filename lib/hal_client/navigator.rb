class HalClient
  # A description of how to navigate an API. This class follows a builder pattern
  # for defining sequential navigation steps. After you have defined the steps you
  # want to take, use `#to_enum` to return a lazy enumerable of the results of your
  # navigation steps.
  #
  # Example:
  # nav = Navigator.new
  #                .follow('https://rels.example.com/posts')
  #                .paged_collection
  #                .select(->(repr) { /dogs/i === repr['title'] })
  # nav.to_enum(blog)
  class Navigator
    def initialize
      @steps = []
    end

    # Follow the given rel on each of the `Representation`s that result from the
    # previous step. Note: use `#paged_collection` below instead of `follow`ing
    # the `"item"` rel to deal with paged collections correctly
    #
    # Lazily calls `related` on each element of the enumerable and unwraps the
    # resulting `RepresentationSet`. Probably won't work after a `flat_map`
    #
    # rel - a string
    #
    # Returns: self so you can chain step additions
    def follow(rel)
      return paged_collection if rel == "item"

      @steps << ->(enum_thus_far) {
        Enumerator::Lazy.new(enum_thus_far.each) do |yielder, repr|
          repr.related(rel) { [] }.each { |r| yielder << r }
        end
      }
      self
    end

    # Lazily enumerates the result of calling `to_enum` on the elements of the
    # enumerable. Use this instead of `follow`ing the `"item"` rel, as it deals
    # with paged corrections correctly.
    #
    # Returns: self so you can chain step additions
    def paged_collection
      @steps << ->(enum_thus_far) {
        Enumerator::Lazy.new(enum_thus_far) do |yielder, repr|
          repr.to_enum.each { |r| yielder << r }
        end
      }
      self
    end

    # Filter the results of the previous step.
    #
    # filter_func - a block that takes an element of the enumerable and returns
    # true or false.
    #
    # Returns: self so you can chain step additions
    def select(&filter_func)
      @steps << ->(enum_thus_far) {
        enum_thus_far.select(&filter_func)
      }
      self
    end

    # Transform the list
    #
    # mapping_func - a block that takes an element of the enumerable and returns
    #                whatever you want
    #
    # Returns: self so you can chain step additions
    def flat_map(&mapping_func)
      @steps << ->(enum_thus_far) {
        enum_thus_far.flat_map(&mapping_func)
      }
      self
    end

    # A lazy enumerable of representations that results from following each of the
    # steps in this Navigator on the given initial representations.
    def to_enum(*initial_reprs)
      @steps = [->(r) { r }] if @steps.count.zero?

      @steps.reduce(initial_reprs.lazy) do |enum_thus_far, next_step|
        next_step.call(enum_thus_far)
      end.select(&:present?)
    end
  end
end
