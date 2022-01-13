# frozen_string_literal: true

module EmEasyScraper
  class Worker
    AUX_KEYS = %i[provider context started_at finished_at].freeze
    attr_accessor :provider, :worker_number, :login_attempt, :context, :started_at, :finished_at, :connection

    def initialize(provider:, worker_number:)
      @provider = provider
      @worker_number = worker_number
      @login_attempt = 0
      @context = WorkerContext.new
      @provider = provider
      @connection = EM::HttpRequest.new('https://www.example.com', provider.worker_options(worker_number))
      @connection.use(Middleware::HeadersManager)
      @connection.use(Middleware::RequestDuration)
      @connection.use(Middleware::HttpVerbose) if Config.instance.http_verbose
      create_accessors(@connection)
      provider.after_worker_initialize(self)
    end

    def method_missing(symbol, *args)
      @connection.send(symbol, *args)
    end

    def respond_to_missing?(name, include_private)
      @connection.send(:respond_to_missing?, name, include_private)
    end

    def rate_limit_key(task)
      provider.rate_limit_key(task)
    end

    private

    def create_accessors(connection)
      connection.class.send(:attr_accessor, :worker)
      connection.worker = self

      connection.class_eval do
        AUX_KEYS.each do |key|
          define_method(key) { worker.send(key) }
          define_method("#{key}=") { |value| worker.send("#{key}=", value) }
        end
      end
    end
  end
end
