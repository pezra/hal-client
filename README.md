# HalClient

Provides an easy to use interface for interacting is REST APIs that use [HAL](http://stateless.co/hal_specification.html).

## Installation

Add this line to your application's Gemfile:

    gem 'hal-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hal-client

## Usage

    blog = HalClient.new.get("http://blog.me/")
    blog.href # => "http://blog.me/"
    blog.fetch("title") # => "A Great Blog"
    blog.fetch("item") # => #<RepresentationSet:...>
    blog.related("item") # => #<RepresentationSet:...>
    post = blog.fetch("item").first # => #<Represenation:...>
    post.href # => "http://blog.me/posts/1"

## Contributing

1. Fork it ( http://github.com/pezra/hal-client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Update `lib/hal_client/version.rb` following [semantic versioning rules](http://semver.org/)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
