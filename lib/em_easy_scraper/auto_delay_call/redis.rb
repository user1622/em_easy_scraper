# frozen_string_literal: true

module EmEasyScraper
  module AutoDelayCall
    class Redis < Base
      def calculate_delay(key)
        redis.calculate_delay([key], [@normal_delay])
      end

      private

      def redis
        @redis ||= RedisConnection.instance
      end
    end
  end
end
