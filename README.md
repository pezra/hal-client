[![Build Status](https://travis-ci.org/pezra/hal-client.png?branch=master)](https://travis-ci.org/pezra/hal-client)
[![Code Climate](https://codeclimate.com/github/pezra/hal-client.png)](https://codeclimate.com/github/pezra/hal-client)

# HalClient

An easy to use interface for REST APIs that use [HAL](http://stateless.co/hal_specification.html).

## Installation

Add this line to your application's Gemfile:

    gem 'hal-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hal-client

## Usage

The first step to using HalClient is to create a `HalClient` instance.

    my_client = HalClient.new

If the API uses one or more a custom mime types we can specify that they be included in the `Accept` header field of each request.

    my_client = HalClient.new(accept: "application/vnd.myapp+hal+json")

### `GET`ting an entry point

Getting API entry points is main use for the HalClient instance. Once you have an entry point we will simply traverse the links on a representation (which uses the client instance indirectly).

    blog = my_client.get("http://blog.me/")

`HalClient::Representation`s expose a `#property` method to retrieve properties from the HAL document.

    blog.property('title')
    #=> "Some Person's Blog"

### Link navigation

Once we have a representation we are going to need to navigate its links. This can be accomplished by using the `#related` method.

    articles = blog.related("item")
    # => #<RepresentationSet:...>

In the example above `item` is the link rel. The `#related` method looks up both embedded representations and links with the rel of `item`. Links are then dereferenced using the same `HalClient` instance used to retrieve the entry point. The dereferenced links and extracted embedded representations are converted into individual `HalClient::Representation`s and packaged into a `HalClient::RepresentationSet`. `HalClient` always returns `RepresentationSet`s when following links, even when there is only one result as doing so tends to result in simpler client code.

`RepresentationSet`s are `Enumerable` so they expose all your favorite methods like `#each`, `#map`, `#any?`, etc. Additionally, `RepresentationSet`s expose a `#related` method which calls `#related` on each member of the set and then merges the results into a new representation set.

    authors = blog.related("author").related("item")
    authors.first.property("name")
    # => "Bob Smith"

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
    

## Contributing

1. Fork it ( http://github.com/pezra/hal-client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
3. Update `lib/hal_client/version.rb` following [semantic versioning rules](http://semver.org/)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
