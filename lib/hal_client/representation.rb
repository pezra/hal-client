require 'forwardable'
require 'addressable/template'

require 'hal_client'
require 'hal_client/representation_set'

class HalClient
  class Representation
    extend Forwardable

    def initialize(hal_client, parsed_json)
      @hal_client = hal_client
      @raw = parsed_json
    end

    MISSING = Object.new

    def property(name, default=MISSING, &default_proc)
      default_proc ||= ->(_){ default} if default != MISSING

      raw.fetch(name.to_s, &default_proc)
    end

    def href
      link_section.fetch("self").fetch("href")
    end


    def fetch(item_key, default=MISSING, &default_proc)
      default_proc ||= ->(_){default} if default != MISSING

      property(item_key) {
        related(item_key, &default_proc)
      }
    end

    def [](item_key)
      fetch(item_key, nil)
    end

    # If the link(s) are templated they will be expanded using
    # `options` before the links are followed.
    def related(link_rel, options = {}, &default_proc)
      default_proc ||= ->(link_rel){
        raise KeyError, "No resources are related via `#{link_rel}`"
      }

      embedded = embedded(link_rel) rescue nil
      linked = linked(link_rel, options) rescue nil

      if !embedded.nil? or !linked.nil?
        RepresentationSet.new (Array(embedded) + Array(linked))
      else
        default_proc.call link_rel
      end
    end

    def related_hrefs(link_rel, options={}, &default_proc)
      default_proc ||= ->(link_rel){
        raise KeyError, "No resources are related via `#{link_rel}`"
      }

      embedded = boxed embedded_section.fetch(link_rel, nil)
      linked = boxed link_section.fetch(link_rel, nil)

      if !embedded.nil? or !linked.nil?
        Array(embedded).map{|it| it.fetch("_links").fetch("self").fetch("href") rescue nil} +
          Array(linked).map{|it| it.fetch("href", nil) }.
          compact
      else
        default_proc.call link_rel
      end
    end

    protected
    attr_reader :raw, :hal_client

    def link_section
      @link_section ||= raw.fetch("_links", {})
    end

    def embedded_section
      @embedded_section ||= raw.fetch("_embedded", {})
    end

    def embedded(link_rel)
      relations = boxed embedded_section.fetch(link_rel)

      relations.map{|it| Representation.new hal_client, it}
    end

    def linked(link_rel, options)
      relations = boxed link_section.fetch(link_rel)

      relations.
        map {|link| href_from link, options }.
        map {|href| hal_client.get href }
    end


    def boxed(list_hash_or_nil)
      if Hash === list_hash_or_nil
        [list_hash_or_nil]
      else
        list_hash_or_nil
      end
    end

    def href_from(link, options)
      raw_href = link.fetch('href')

      if link.fetch('templated', false)
        Addressable::Template.new(raw_href).expand(options).to_s
      else
        raw_href
      end
    end

  end
end
