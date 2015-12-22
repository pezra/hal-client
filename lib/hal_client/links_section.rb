class HalClient

  # Encapsulates a "_links" section.
  class LinksSection
    UNSET = Object.new

    def initialize(section, base_url: )
      @namespaces = CurieResolver.new(section.fetch("curies"){[]})

      @section = section.merge(fully_qualified(section))
      @base_url = base_url
    end

    attr_reader :namespaces

    # Returns the URLs or URL templates of each link with the
    # specified rel in this section.
    #
    # link_rel - The fully qualified link relation
    # default_proc - (optional) A proc to execute to create a
    #   default value if the specified link_rel does not exist
    #
    # Yields the link_rel to the default_proc if the specified
    # link_rel is not present and returns the return value of the
    # default_proc.
    #
    # Raises KeyError if the specified link_rel is not present and no
    # default_value or default_proc are provided.
    def hrefs(link_rel, &default_proc)
      default_proc ||= ->(link_rel){
        raise KeyError, "No resources are related via `#{link_rel}`"
      }

      return default_proc.call(link_rel) unless section.key? link_rel

      [section.fetch(link_rel)]
        .flatten
        .map{|link| resolve_to_url(link)}
    end

    protected

    attr_reader :section, :base_url

    def resolve_to_url(link)
      (fail HalClient::InvalidRepresentationError) unless link.respond_to? :fetch

      url = base_url + link.fetch("href")
      is_templated = link.fetch("templated", false)

      if is_templated
        Addressable::Template.new(url.to_s)
      else
        url.to_s
      end

    rescue KeyError
      fail HalClient::InvalidRepresentationError
    end

    def fully_qualified(relations_section)
      Hash[relations_section.map {|rel, link_info|
        [(namespaces.resolve rel), link_info]
      }]
    end

  end
end
