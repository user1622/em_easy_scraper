# frozen_string_literal: true

module EmEasyScraper
  # Singleton class for redis connection
  class RedisConnection
    include Singleton

    def initialize
      EM::Hiredis::Client.load_scripts_from(EmEasyScraper.root.join('lib/em_easy_scraper/lua_scripts'))
    end

    def respond_to_missing?(name, include_private)
      redis.respond_to_missing?(name, include_private)
    end

    def method_missing(symbol, *args)
      redis.send(symbol, *args)
    end

    protected

    def redis
      return @redis if defined?(@redis)

      @redis = EM::Hiredis.connect(Config.instance.redis_url)
      @redis.errback { |error| ::EmEasyScraper.logger.fatal(error) }
      @redis.configure_inactivity_check(5, 5)
      EM.add_shutdown_hook { remove_instance_variable(:@redis) }
      @redis
    end
  end
end
