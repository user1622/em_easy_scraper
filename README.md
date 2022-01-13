# EmScraper
![GitHub Actions CI](https://github.com/user1622/em_easy_scraper/actions/workflows/main.yml/badge.svg)
![Contributors](https://img.shields.io/github/contributors/user1622/em_easy_scraper)
![Activity](https://img.shields.io/github/commit-activity/m/user1622/em_easy_scraper)


Easy scraper tool based on EventMachine library.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'em_easy_scraper'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install em_scraper

## Usage

```ruby
require 'em_easy_scraper'

EmEasyScraper.configure do |config|
  config.redis_url = "redis://:<PASSWORD>@127.0.0.1:991"
  config.auto_delay_call = EmEasyScraper::AutoDelayCall::Redis
  config.provider_plugins << 'performance_tracker'
  config.workers = 1
  config.requests_in_minute = 10
  config.provider_plugins << 'state_manager'
  config.cache = ActiveSupport::Cache::FileStore.new(EmEasyScraper.root.join('tmp/cache'))
end

tasks = (0..10).map { EmEasyScraper::Task.new(url: 'https://stackoverflow.com/') }
tasks += (0..10).map { EmEasyScraper::Task.new(url: 'https://example.com/') }
tasks += (0..10).map { EmEasyScraper::Task.new(url: 'https://www.wikipedia.org/') }
EmEasyScraper::Scraper.new.scrape(tasks)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/user1622/em_scraper.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
