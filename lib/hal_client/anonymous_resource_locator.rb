class HalClient
  class AnonymousResourceLocator
    def to_s
      "ANONYMOUS(#{object_id})"
    end
    alias_method :to_str, :to_s

    def anonymous?
      true
    end
  end
end