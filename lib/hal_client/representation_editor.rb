require 'hal_client'
require 'forwardable'

class HalClient

  # Provides ability to edit a representation. Editing a
  # representation is useful in writable APIs as a way to update
  # resources.
  #
  # This class will not actually modify the underlying representation
  # in any way.
  #
  # Example:
  #
  # ```ruby
  #   altered_doc = HalClient::RepresentationEditor.new(some_doc)
  #     .reject_relate("author") { |it| it["name"]  = "John Plagiarist" }
  # ```
  class RepresentationEditor
    extend Forwardable

    # Initialize a new representation editor.
    #
    # a_representation - The representation from which you want to
    #   start. This object will *not* be modified!
    # raw - Not for public use! Used internally for handling multi-
    #   staged changes.
    def initialize(a_representation, raw = a_representation.raw)
      @orig_repr = a_representation
      @raw = raw
    end
    protected :initialize

    attr_reader :raw

    # Returns true if this, or any previous, editor actually changed the hal
    # representation.
    def dirty?
      new_repr = Representation.new(parsed_json: raw)

      orig_repr.properties != new_repr.properties ||
        orig_repr.all_links != new_repr.all_links
    end

    # Returns the raw json representation of this representation
    def to_json
      MultiJson.dump(raw)
    end
    alias_method :to_hal, :to_json

    # Returns a RepresentationEditor for a representation like the
    # current one but without the specified links and/or embeddeds.
    #
    # rel - The relationship type to remove or filter
    # blk - When given only linked and embedded resource for whom
    #   the block returns true will be rejected.
    #
    # Options
    #
    #   ignore - one or more categories of things to ignore. Valid
    #     values are: :broken_links. Default: []
    #
    # Yields Representation of the target for each link/embedded.
    def reject_related(rel, ignore: [], &blk)
      reject_links(rel, ignore: ignore, &blk).reject_embedded(rel, ignore: ignore, &blk)
    end

    # Returns a RepresentationEditor for a representation like the
    # current one but without the specified links.
    #
    # rel - The relationship type to remove or filter
    # blk - When given only links to resources for whom
    #   the block returns true will be rejected.
    #
    # Options
    #
    #   ignore - one or more categories of things to ignore. Valid
    #     values are: :broken_links. Default: []
    #
    # Yields Representation of the target for each link.
    def reject_links(rel, ignore: [], &blk)
      reject_from_section("_links",
                          rel,
                          ->(l) {Representation.new(href: l["href"],
                                                    hal_client: hal_client)},
                          ignoring(ignore, blk))
    end

    # Returns a RepresentationEditor for a representation like the
    # current one but without the specified embedded resources.
    #
    # rel - The relationship type to remove or filter
    # blk - When given only embedded resources for whom
    #   the block returns true will be rejected.
    #
    # Options
    #
    #   ignore - one or more categories of things to ignore. Valid
    #     values are: :broken_links. Default: []
    #
    # Yields Representation of the target for each embedded.
    def reject_embedded(rel, ignore: [], &blk)
      reject_from_section("_embedded",
                          rel,
                          ->(e) {Representation.new(parsed_json: e,
                                                    hal_client: hal_client)},
                          ignoring(ignore, blk))
    end

    # Returns a RepresentationEditor exactly like this one except that
    # is has an additional link to the specified target with the
    # specified rel.
    #
    # rel - The type of relationship this link represents
    # target - URL of the target of the link
    # opts
    #   :templated - is this link templated? Default: false
    def add_link(rel, target, opts={})
      templated = opts.fetch(:templated, false)

      link_obj = { "href" => target.to_s }
      link_obj = link_obj.merge("templated" => true) if templated

      with_new_link = Array(raw.fetch("_links", {}).fetch(rel, [])) + [link_obj]
      updated_links_section =  raw.fetch("_links", {}).merge(rel => with_new_link)

      self.class.new(orig_repr, raw.merge("_links" => updated_links_section))
    end

    # Returns a RepresentationEditor exactly like this one except that
    # is has an new or overwritten property value
    #
    # key - The name of the property
    # value - Value to place in the property
    def set_property(key, value)
      self.class.new(orig_repr, raw.merge(key => value))
    end

    protected

    attr_reader :orig_repr

    def Array(thing)
      if Hash === thing
        [thing]
      else
        Kernel.Array(thing)
      end
    end

    def hal_client
      orig_repr.hal_client
    end

    def reject_from_section(name, rel, coercion, filter=nil)
      return self unless raw.fetch(name, {}).has_key?(rel)

      filtered_rel = if filter
        [raw[name].fetch(rel,[])].flatten
          .reject{|it| filter.call(coercion.call(it)) }
      else
        []
      end

      new_sec = if filtered_rel.empty?
                  raw[name].reject{|k,_| rel == k}
                else
                  raw[name].merge(rel => filtered_rel )
                end

      self.class.new(orig_repr, raw.merge(name => new_sec))
    end

    def ignoring(criteria, filter)
      Array(criteria)
        .reduce(filter) {|f, c|
          case c
          when :broken_links
            ->(*args) { begin
                          f.call(*args)
                        rescue HalClient::HttpClientError
                          false
                        end }
          else
            fail ArgumentError, "Unsupported ignore criteria: #{c}"
          end
        }
    end
  end
end
