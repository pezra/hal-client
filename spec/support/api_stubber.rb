require 'json'

module ApiStubber
  def defresource(url, props={})
    url = url(url)

    resources[url] ||= ResourceDesc.new(url, [LinkDesc.new("self", url)], props, [])
  end

  def deflink(rel, to:, from:, name: nil, templated: false)
    source = defresource(from)
    defresource(url(to, base_url: from))

    LinkDesc.new(rel, url(to), templated, name)
      .tap do |l| source.links << l end
  end

  def defembedded(rel, to:, from:)
    source = defresource(from)
    dest_url = url(to, base_url: from)

    EmbeddedDesc.new(rel, ResourceDesc.new(dest_url, [LinkDesc.new("self", dest_url)], {}, []))
      .tap do |e| source.embedded << e end
  end

  ResourceDesc = Struct.new(:url, :links, :props, :embedded) do
    def to_hal
      JSON.pretty_generate(hal_hash)
    end

    def hal_hash
      props.merge(links_hash).merge(embedded_hash)
    end

    protected

    def links_hash
      { "_links" =>
          links
            .group_by { |l| l.rel}
            .map { |(rel, ls)|
              [rel, ls.map { |l| l.hal_hash }]
            }
            .map{ |(rel, ls)|
              [rel, (ls.count > 1 ? ls : ls.first)]
            }
            .to_h
      }
    end

    def embedded_hash
      { "_embedded" =>
          embedded
            .group_by { |l| l.rel}
            .map { |(rel, ls)|
              [rel, ls.map { |l| l.dest.hal_hash }]
            }
            .map{ |(rel, ls)|
              [rel, (ls.count > 1 ? ls : ls.first)]
            }
            .to_h
      }
    end
  end

  LinkDesc = Struct.new(:rel, :href, :templated, :name) do
    def hal_hash
      hsh = {"href" => self.href}

      hsh = hsh.merge("templated" => true) if self.templated
      hsh = hsh.merge("name" => self.name) if self.name

      hsh
    end
  end

  EmbeddedDesc = Struct.new(:rel, :dest)

  def resources
    @resources ||= {}
  end

  def stub_api(&blk)
    blk.call

    stub_http_requests
  end

  def stub_http_requests
    resources.each do |(_url, r)|
      stub_request(:get, r.url.to_s)
        .to_return(headers: {'Content-Type' => 'application/hal+json'},
                   body: r.to_hal)

      stub_request(:put, r.url.to_s)
        .to_return{|req| {headers: {'Content-Type' => 'application/hal+json'},
                          body: req.body} }

      stub_request(:post, r.url.to_s)
        .to_return{|req| {headers: {'Content-Type' => 'application/hal+json'},
                          status: 201,
                          body: req.body} }

      stub_request(:patch, r.url.to_s)
        .to_return{|req| {headers: {'Content-Type' => 'application/hal+json'},
                          body: req.body} }


    end
  end

  def url(urlish, base_url: nil)
    return urlish if Addressable::URI == urlish and base_url.nil?


    if base_url
      url(base_url) + urlish
    else
      Addressable::URI.parse(urlish)
    end
  end
end
