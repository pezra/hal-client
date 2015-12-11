require_relative "../hal_client"

class HalClient

  # Enumerable for items in a paged collection of HAL representations
  # that are encoded using the IANA standard `item`, `next` and `prev`
  # link rels.
  #
  # This will fetch subsequent pages on iteration
  class Collection
    include Enumerable

    # Initializes a collection starting at `first_page`.
    #
    # first_page - The HalClient::Representation of the first page of
    #   the collection to be iterated over.
    #
    # Raises HalClient::NotACollectionError if `first_page` is not a
    #   page of a collection.
    # Raises ArgumentError if `first_page` is some page other than 
    #   the first of the collection.
    def initialize(first_page)
      (fail NotACollectionError) unless first_page.has_related? "item"
      (fail ArgumentError, "Not the first page of the collection") if first_page.has_related? "prev"

      @first_page = first_page
    end

    # Returns the number of items in the collection if it is fast to
    # calculate.
    #
    # Raises NotImplementedError if any of the pages of the collection
    #   have not already been cached.
    def count(&blk)
      (fail NotImplementedError, "Cowardly refusing to make an arbitrary number of HTTP requests") unless all_pages_cached?

      total = 0
      each_page do |p|
        total += p.related("item").count
      end

      total
    end

    # Iterates over the members of the collection fetching the next
    # page as necessary.
    #
    # Yields the next item of the iteration.
    def each(&blk)
      each_page do |a_page|
        a_page.related("item").each(&blk)
      end
    end

    # Returns one or more randomly selected items from the first page
    # of the collection.
    #
    # count - number of items to return. If specified return type will
    #   an collection. Default: return a single item
    def sample(*arg)
      first_page.related("item").sample(*arg)
    end

    protected

    attr_reader :first_page

    def all_pages_cached?
      ! first_page.has_related?("next")
    end

    def each_page(&blk)
      yield first_page

      cur_page = first_page
      while cur_page.has_related? "next"
        cur_page = cur_page.related("next").first
        yield cur_page
      end
    end
  end
end
