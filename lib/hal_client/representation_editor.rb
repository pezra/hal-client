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
  #     .reject_related("author") { |it| it["name"]  = "John Plagiarist" }
  # ```
  class RepresentationEditor
    extend Forwardable

    # Initialize a new representation editor.
    #
    # a_representation - The representation to edit. This object will
    #   *not* be modified!
    # original_representation - *PRIVATE* used for multistage editing
    def initialize(a_representation, original_representation = a_representation)
      @repr = a_representation
      @orig_repr = original_representation
    end

    # Returns raw (parse json) version of the edited resource
    def raw
      repr.raw
    end

    # Returns true if this, or any previous, editor actually changed the hal
    # representation.
    #
    # ---
    #
    # Anonymous entries are hard to deal with in a logically clean way. We fudge
    # it a bit by treating anonymous resources with the same raw value as equal.
    def dirty?
      orig_repr.properties != repr.properties ||
        sans_anon(orig_repr.all_links) != sans_anon(repr.all_links) ||
        raw_anons(orig_repr.all_links) != raw_anons(repr.all_links)
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
      reject_embedded(rel, ignore: ignore, &blk).reject_links(rel, ignore: ignore, &blk)
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
      blk ||= ->(_target){true}


      (candidates, safe)= repr
                          .all_links
                          .partition{|link| link.rel?(rel) }

      selected = candidates.reject(&link_checker(blk, ignore))

      new_repr = Representation.new(repr.href,
                                    repr.properties,
                                    safe+selected,
                                    repr.hal_client)

      self.class.new(new_repr, orig_repr)
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
      blk ||= ->(_target){true}

      (embedded, links) = repr
                          .all_links
                          .partition(&:embedded?)

      (candidates, safe)= embedded
                          .partition{|link| link.rel?(rel) }

      selected = candidates.reject(&link_checker(blk, ignore))

      new_repr = Representation.new(repr.href,
                                    repr.properties,
                                    links+safe+selected,
                                    repr.hal_client)

      self.class.new(new_repr, orig_repr)

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
      raise ArgumentError, "target must not be nil or empty" if target.nil? || target.empty?
      templated = opts.fetch(:templated, false)

      new_link =
        if templated
          tmpl = if target.respond_to?(:pattern)
                   target
                 else
                   Addressable::Template.new(target)
                 end

          TemplatedLink.new(rel: rel,
                            template: tmpl,
                            hal_client: repr.hal_client)
        else
          SimpleLink.new(rel: rel,
                         target: RepresentationFuture.new(target, repr.hal_client),
                         embedded: false)
        end

      new_repr = Representation.new(repr.href,
                                    repr.properties,
                                    repr.all_links + [new_link],
                                    repr.hal_client)

      self.class.new(new_repr, orig_repr)
    end

    # Returns a RepresentationEditor exactly like this one except that
    # is has an new or overwritten property value
    #
    # key - The name of the property
    # value - Value to place in the property
    def set_property(key, value)
      new_repr = Representation.new(repr.href,
                                    repr.properties.merge(key => value),
                                    repr.all_links,
                                    repr.hal_client)

      self.class.new(new_repr, orig_repr)
    end

    protected

    attr_reader :orig_repr, :repr

    def link_checker(blk, ignore)
      if Array(ignore).include?(:broken_links)
        ->(l) {
          begin
            blk.call(l.target)
          rescue HalClient::HttpError
            false
          end
        }
      else
        ->(l) {
          blk.call(l.target)
        }
      end
    end

    def sans_anon(links)
      links.reject { |l| AnonymousResourceLocator === l.raw_href}
        .to_set
    end

    def raw_anons(links)
      links
        .select { |l| AnonymousResourceLocator === l.raw_href}
        .map!{ |l| l.target.raw }
        .to_set
    end

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
