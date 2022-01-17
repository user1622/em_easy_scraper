# frozen_string_literal: true

module EmEasyScraper
  class Config
    include Singleton

    DEFAULT_SETTINGS = {
      crawler_number: 1,
      workers: 1,
      login_workers: 1,
      login_pause_sleep: nil,
      max_login_try_count: 3,
      threadpool_size: 1,
      http_verbose: EmEasyScraper.development?,
      provider: 'base',
      provider_plugins: [],
      logger: Logger.new($stdout),
      daemon: false,
      requests_in_minute: 10,
      cache: ActiveSupport::Cache::MemoryStore.new,
      redis_url: nil,
      auto_delay_call: EmEasyScraper::AutoDelayCall::Memory
    }.freeze

    attr_accessor(*DEFAULT_SETTINGS.keys)

    def initialize
      DEFAULT_SETTINGS.each { |key, value| instance_variable_set("@#{key}", value) }
    end
  end
end
