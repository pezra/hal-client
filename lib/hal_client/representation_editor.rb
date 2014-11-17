require 'hal_client'
require 'forwardable'

class HalClient

  # Provides ability to edit a representation. Editing a
  # representation is useful in writable APIs as a way to update
  # resources.
  #
  # This class will not actually modify the underlying representation
  # in any way.
  class RepresentationEditor
    extend Forwardable

    # a_representation - The representation from which you want to
    # start. This object will *not* be modified!
    def initialize(a_representation, raw = a_representation.send(:raw))
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
    def reject_related(rel)
      reject_links(rel).reject_embedded(rel)
    end

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
      orig_repr.send(:hal_client)
    end
  end
end
