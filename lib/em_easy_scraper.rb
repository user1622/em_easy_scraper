# frozen_string_literal: true

require 'singleton'
require 'json'

require 'eventmachine'
require 'active_support/all'
require 'em-http-request'
require 'em-hiredis'
require 'promise_em'
require 'http-cookie'

require_relative 'em_easy_scraper/core_ext/http_connection'
require_relative 'em_easy_scraper/core_ext/connect'
require_relative 'em_easy_scraper/core_ext/hiredis'

# Simple Scraper based on EventMachine
module EmEasyScraper
  class Error < StandardError; end
  class ProviderError < StandardError; end
  class ReDownloadError < StandardError; end
  class LoginError < StandardError; end
  class HelperError < StandardError; end

  autoload(:Scraper, 'em_easy_scraper/scraper')
  autoload(:Config, 'em_easy_scraper/config')
  autoload(:Pool, 'em_easy_scraper/pool')
  autoload(:Worker, 'em_easy_scraper/worker')
  autoload(:Task, 'em_easy_scraper/task')
  autoload(:WorkerContext, 'em_easy_scraper/worker_context')
  autoload(:RedisConnection, 'em_easy_scraper/redis_connection')

  module Middleware
    autoload(:HeadersManager, 'em_easy_scraper/middleware/headers_manager')
    autoload(:HttpVerbose, 'em_easy_scraper/middleware/http_verbose')
    autoload(:RequestDuration, 'em_easy_scraper/middleware/request_duration')
  end

  module Provider
    autoload(:Base, 'em_easy_scraper/provider/base')
  end

  module Plugin
    autoload(:PerformanceTracker, 'em_easy_scraper/plugin/performance_tracker')
    autoload(:CsvContentHandler, 'em_easy_scraper/plugin/csv_content_handler')
    autoload(:StateManager, 'em_easy_scraper/plugin/state_manager')
    autoload(:ProxyManager, 'em_easy_scraper/plugin/proxy_manager')
  end

  module AutoDelayCall
    autoload(:Base, 'em_easy_scraper/auto_delay_call/base')
    autoload(:Memory, 'em_easy_scraper/auto_delay_call/memory')
    autoload(:Redis, 'em_easy_scraper/auto_delay_call/redis')
  end

  module Helper
    autoload(:RotationManager, 'em_easy_scraper/helper/rotation_manager')
    autoload(:ProxyManager, 'em_easy_scraper/helper/proxy_manager')
  end

  class << self
    def configure
      yield(Config.instance)
    end

    def env
      Object.const_defined?('Rails') ? Rails.env : ENV.fetch('APP_ENV', 'development')
    end

    def production?
      Object.const_defined?('Rails') ? Rails.env.production? : env == 'production'
    end

    def development?
      Object.const_defined?('Rails') ? Rails.env.development? : env == 'development'
    end

    def test?
      Object.const_defined?('Rails') ? Rails.env.test? : env == 'test'
    end

    def logger
      Config.instance.logger
    end

    def root
      Pathname.new(File.expand_path('../', __FILE__))
    end
  end
end
