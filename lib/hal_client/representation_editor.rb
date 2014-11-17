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

    # Returns the raw json representation of this representation
    def to_json
      raw.to_json
    end
    alias_method :to_hal, :to_json

    # Returns a RepresentationEditor for a representation like the
    # current one but without the specified links and/or embeddeds.
    #
    # rel - The relationship type to remove or filter
    # blk - When given only linked and embedded resource for whom
    #   the block returns true will be rejected.
    #
    # Yields Representation of the target for each link/embedded.
    def reject_related(rel, &blk)
      reject_links(rel, &blk).reject_embedded(rel, &blk)
    end

    # Returns a RepresentationEditor for a representation like the
    # current one but without the specified links.
    #
    # rel - The relationship type to remove or filter
    # blk - When given only links to resources for whom
    #   the block returns true will be rejected.
    #
    # Yields Representation of the target for each link.
    def reject_links(rel, &blk)
      return self unless raw.fetch("_links", {}).has_key?(rel)

      filtered_rel = if block_given?
                       filtered =
                         [raw["_links"][rel]].flatten
                         .reject{|it| blk.call(Representation.new(href: it["href"],
                                                                  hal_client: hal_client)) }
                     else
                       []
                     end


      new_links = if filtered_rel.empty?
                    raw["_links"].reject{|k,_| rel == k}
                  else
                    raw["_links"].merge(rel => filtered_rel )
                  end

      self.class.new(orig_repr, raw.merge("_links" => new_links))
    end

    # Returns a RepresentationEditor for a representation like the
    # current one but without the specified embedded resources.
    #
    # rel - The relationship type to remove or filter
    # blk - When given only embedded resources for whom
    #   the block returns true will be rejected.
    #
    # Yields Representation of the target for each embedded.
    def reject_embedded(rel, &blk)
      return self unless raw.fetch("_embedded", {}).has_key?(rel)

      filtered_rel = if block_given?
                       filtered =
                         [raw["_embedded"][rel]].flatten
                         .reject{|it| blk.call(Representation.new(parsed_json: it,
                                                                  hal_client: hal_client)) }
                     else
                       []
                     end

      new_embedded = if filtered_rel.empty?
                       raw["_embedded"].reject{|k,_| rel == k}
                     else
                       raw["_embedded"].merge(rel => filtered_rel )
                     end



      self.class.new(orig_repr, raw.merge("_embedded" => new_embedded))
    end

    protected

    attr_reader :orig_repr, :raw

    def hal_client
      orig_repr.hal_client
    end
  end
end
