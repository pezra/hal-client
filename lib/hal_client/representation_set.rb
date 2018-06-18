require 'forwardable'

class HalClient

  # A collection HAL representations
  class RepresentationSet
    include Enumerable
    extend Forwardable

    def initialize(reprs)
      @reprs = reprs
    end

    def_delegators :reprs, :each, :count, :empty?, :any?, :sample

    # Returns representations of resources related via the specified
    #   link rel or the specified default value.
    #
    # name_or_rel - The name of property or link rel of interest
    # options - optional keys and values with which to expand any
    #   templated links that are encountered
    # default_proc - an option proc that will be called with `name`
    #  to produce default value if the specified property or link does not
    #  exist
    #
    # Raises KeyError if the specified link does not exist
    #   and no default_proc is provided.
    def related(link_rel, options={})
      raise KeyError unless has_related? link_rel
      RepresentationSet.new flat_map{|it| it.related(link_rel, options){[]}.to_a }
    end

    # Returns true if any member representation contains a link
    # (including embedded links) whose rel is `link_rel`.
    #
    # link_rel - The link rel of interest
    def related?(link_rel)
      any? {|it| it.has_related?(link_rel) }
    end
    alias_method :has_related?, :related?

    # Post a `Representation` or `String` to the resource.
    #
    # NOTE: This only works for a single representation.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#post`
    def post(data, options={})
      raise NotImplementedError, "We only posts to singular resources." if count > 1
      first.post(data, options)
    end

    # Put a `Representation` or `String` to the resource.
    #
    # NOTE: This only works for a single representation.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#put`
    def put(data, options={})
      raise NotImplementedError, "We only puts to singular resources." if count > 1
      first.put(data, options)
    end

    # Patch a `Representation` or `String` to the resource.
    #
    # NOTE: This only works for a single representation.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#patch`
    def patch(data, options={})
      raise NotImplementedError, "We only patchs to singular resources." if count > 1
      first.patch(data, options)
    end


    # Returns the specified `Form`
    #
    # form_id - the string or symbol id of the form of interest. Default: `"default"`
    #
    # Raises `KeyError` if the specified form doesn't exist, or if there are duplicates.
    def form(form_id="default")
      self
        .map { |r|
          begin
            r.form(form_id)
          rescue KeyError
            nil
          end }
        .compact
        .tap do |fs|
          raise KeyError, "Duplicate `#{form_id}` forms exist" if fs.count > 1
        end
        .first
    end

    protected

    attr_reader :reprs
  end
end
