[![Build Status](https://travis-ci.org/pezra/hal-client.png?branch=master)](https://travis-ci.org/pezra/hal-client)
[![Code Climate](https://codeclimate.com/github/pezra/hal-client.png)](https://codeclimate.com/github/pezra/hal-client)

# HalClient

An easy to use client interface for REST APIs that use [HAL](http://stateless.co/hal_specification.html).

## Installation

Add this line to your application's Gemfile:

    gem 'hal-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hal-client

Usage
-----

The first step in using a HAL based API is getting a representation of one of its entry point. The simplest way to do this is using the `get` class method of `HalClient`.

    blog = HalClient.get("http://blog.me/")
    # => #<Representation: http://blog.me/>

`HalClient::Representation`s expose a `#property` method to retrieve properties from the HAL document.

    blog.property('title')
    #=> "Some Person's Blog"

### Link navigation

Once we have a representation we will want to navigate its links. This can be accomplished using the `#related` method.

    articles = blog.related("item")
    # => #<RepresentationSet:...>

In the example above `item` is the link rel. The `#related` method extracts embedded representations and dereferences links with the specified rel. The resulting representations are packaged into a `HalClient::RepresentationSet`. `HalClient` always returns `RepresentationSet`s when following links, even when there is only one result. `RepresentationSet`s are `Enumerable` so they expose all your favorite methods like `#each`, `#map`, `#any?`, etc. `RepresentationSet`s expose a `#related` method which calls `#related` on each member of the set and then merges the results into a new representation set.

    all_the_authors = blog.related("author").related("item")
    all_the_authors.first.property("name")
    # => "Bob Smith"

#### CURIEs

Links specified using a compact URI (or CURIE) as the rel are fully supported. They are accessed using the fully expanded version of the curie. For example, given a representations of an author:

    { "name": "Bob Smith,
      "_links": {
        "so:homeLocation": { "href": "http://example.com/denver" },
        "curies": [{ "name": "so", "href": "http://schema.org/{rel}", "templated": true }]
    }}

Bob's home location can be retrieved with

    author.related("http://schema.org/homeLocation")
    # => #<Representation: http://example.com/denver>

Links are always accessed using the full link relation, rather than the CURIE, because the document producer can use any arbitrary string as the prefix. This means that clients must not make any assumptions regarding what prefix will be used because it might change over time or even between documents.

### Templated links

The `#related` methods takes a `Hash` as its second argument which is used to expand any templated links that are involved in the navigation.

    old_articles = blog.related("index", before: "2013-02-03T12:30:00Z")
    # => #<RepresentationSet:...>

Assuming there is a templated link with a `before` variable this will result in a request being made to `http://blog.me/archive?before=2013-02-03T12:30:00Z`, the response parsed into a `HalClient::Representation` and that being wrapped in a representation set. Any options for which there is not a matching variable in the link's template will be ignored. Any links with that rel that are not templates will be dereferenced normally.

### Identity

All `HalClient::Representation`s exposed an `#href` attribute which is its identity. The value is extracted from the `self` link in the underlying HAL document.

    blog.href # => "http://blog.me/"

### Hash like interface

`Representation`s expose a `Hash` like interface. Properties, and related representations can be retrieved using the `#[]` and `#fetch` method.

    blog['title'] # => "Some Person's Blog"
    blog['item']  # =>  #<RepresentationSet:...>

### Custom media types

If the API uses one or more a custom mime types we can specify that they be included in the `Accept` header field of each request.

    my_client = HalClient.new(accept: "application/vnd.myapp+hal+json")
    my_client.get("http://blog.me/")
    # => #<Representation: http://blog.me/>

## Contributing

1. Fork it ( http://github.com/pezra/hal-client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Implement your improvement
4. Update `lib/hal_client/version.rb` following [semantic versioning rules](http://semver.org/)
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create new Pull Request
