class HalClient
  class AnonymousResourceLocator
    def to_s
      "ANONYMOUS(#{object_id})"
    end
    alias_method :to_str, :to_s

    def anonymous?
      true
    end

    def +(other)
      return other if Addressable::Template === other

      Addressable::URI.parse(other)
    end
  end
end