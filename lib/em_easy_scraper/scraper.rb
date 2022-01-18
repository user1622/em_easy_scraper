# frozen_string_literal: true

module EmEasyScraper
  # rubocop:disable Metrics/ClassLength
  class Scraper
    def initialize(opts = {})
      @opts = opts
      @opts[:shared_context] = {}
      @stat = {}
      EM.threadpool_size = Config.instance.threadpool_size
      (@opts[:provider_plugins] || Config.instance.provider_plugins).each do |plugin_class|
        provider_class.send(:prepend, Object.const_get("EmEasyScraper::Plugin::#{plugin_class.classify}"))
      end
      EM.add_shutdown_hook { shutdown }
    end

    def scrape(tasks)
      read, write = IO.pipe
      pid = EM.fork_reactor do
        read.close
        perform_login
        create_crawler_pool
        perform_todo
        schedule_tasks(Array.wrap(tasks))
        EM.add_shutdown_hook { Marshal.dump(@stat, write) }
      end
      write.close
      result = read.read
      Process.wait(pid)
      Marshal.load(result)
    end

    private

    def shutdown
      EmEasyScraper.logger.debug('shutdown')
      @crawler_pool&.contents&.each { |worker| worker.provider.before_exit(worker) }
    end

    def login_pool
      return @login_pool if defined?(@login_pool)

      @login_pool = Pool.new(actions_per_period: 60)
      (@opts[:login_workers] || Config.instance.login_workers).times { @login_pool.add(Object.new) }
      @login_pool
    end

    def perform_login
      login_todo.subscribe do |worker|
        login_pool.perform(nil) { |_| login_worker(worker) }
      end
    end

    # rubocop:disable Metrics/AbcSize
    def login_worker(worker)
      promise = PromiseEm::Promise.new { |resolve, _reject| resolve.call }
                                  .then { process_provider_action(:login, worker: worker) }
                                  .then { process_provider_action(:after_login, worker: worker) }
      promise.then do
        @crawler_pool.add(worker)
        worker.login_attempt = 0
        worker.on_connection_error = ->(error) { EmEasyScraper.logger.error("Connection error: #{error}") }
        worker.successful!
        EmEasyScraper.logger.info("Login success for worker: #{worker.provider.context_key}")
      end.catch do |error|
        worker.login_attempt += 1
        worker.failed!

        EmEasyScraper.logger.error("Can't login worker #{worker.provider.context_key}."\
" One more attempt: #{worker.login_attempt}")
        EmEasyScraper.logger.error(error) if error
        re_login_worker(worker, attempt: worker.login_attempt)
      end
    end
    # rubocop:enable Metrics/AbcSize

    def re_login_worker(worker, attempt: 0, login_delay: 0)
      begin
        worker.close
      rescue StandardError
        nil
      end
      @crawler_pool.remove(worker)
      if attempt >= Config.instance.max_login_try_count
        raise(EmEasyScraper::LoginError, 'A lot of login attempts') unless Config.instance.login_pause_sleep

        EM::Timer.new(Config.instance.login_pause_sleep) do
          create_worker(worker.worker_number, attempt: 0, login_delay: login_delay)
        end
      else
        create_worker(worker.worker_number, attempt: attempt, login_delay: login_delay)
      end
      worker.provider.after_re_login_worker(worker, attempt: attempt, login_delay: login_delay)
      worker.provider = nil
      worker
    end

    def process_provider_action(action, opts = {})
      action_result = case action
                      when :login, :after_login
                        opts[:worker].provider.send(action, opts[:worker])
                      when :pre_crawl, :crawl
                        opts[:worker].provider.send(action, opts[:worker], opts[:task])
                      when :post_crawl
                        opts[:worker].provider.send(action, opts[:worker], opts[:task], opts[:response],
                                                    opts[:response_code])
                      else
                        raise(EmEasyScraper::ProviderError, "Unknown action of provider: #{action}")
                      end

      deferrable = action_result[:deferrable]
      if deferrable
        wait_deferrable(deferrable, action, opts) { send_callback_method(action, action_result, opts) }
      else
        send_callback_method(action, action_result, opts)
      end
    end

    def wait_deferrable(deferrable, action, opts)
      defer = EM::DefaultDeferrable.new
      EmEasyScraper.logger.debug("Wait deferrable after #{action}")
      deferrable.callback do |*args|
        EmEasyScraper.logger.debug('deferrable success')
        begin
          yield
          defer.succeed(*args)
        rescue StandardError => e
          defer.fail(e)
        end
      end
      deferrable.errback do |error|
        if http_client_error?(error)
          process_http_client_error(defer, error.error, opts,
                                    action)
        else
          process_other_error(defer, error, opts, action)
        end
      end
      defer
    end

    def http_client_error?(error)
      error.is_a?(EM::HttpClient)
    end

    def process_http_client_error(defer, error, opts, action)
      error_message = "Deferrable error: #{error},"\
" worker: #{opts[:worker].provider.context_key}, action: #{action},"
      error_message += ", task: #{opts[:task].url}" if opts[:task]
      error_class = continue_work?(error, opts[:worker]) ? EmEasyScraper::ReDownloadError : EmEasyScraper::ProviderError
      crawler_error = error_class.new(error_message)
      crawler_error.set_backtrace(caller)
      EmEasyScraper.logger.debug(error_message)
      defer.fail(crawler_error)
    end

    def process_other_error(defer, error, opts, action)
      error_message = "Deferrable error: #{error},"\
" worker: #{opts[:worker].provider.context_key}, action: #{action}"
      error_message += ", task: #{opts[:task].url}" if opts[:task]
      error_message += "\n#{error.message}"
      crawler_error = ProviderError.new(error_message)
      crawler_error.set_backtrace(error.backtrace || caller)
      EmEasyScraper.logger.debug(error_message)
      defer.fail(crawler_error)
    end

    def continue_work?(error, worker)
      case error
      when /connection closed by server/im
        true
      when /errno::etimedout/im
        worker.provider.data[:worker_timeout_count] ||= 0
        worker.provider.data[:worker_timeout_count] += 1
        worker.provider.data[:worker_timeout_count] < 3
      else
        false
      end
    end

    def send_callback_method(action, action_result, opts)
      callback_method = "process_#{action_result[:status]}".downcase
      unless respond_to?(callback_method, true)
        raise(EmEasyScraper::ProviderError, 'Unexpected status from provider action' \
        "#{action}: #{action_result[:status]}")
      end

      send(callback_method, action, action_result, opts)
    end

    def process_re_login(action, _action_result, opts)
      error_message = "Re login worker #{opts[:worker].provider.context_key} after #{action}"
      error_message += ". Task: #{opts[:task].url}" if opts[:task]
      error = EmEasyScraper::LoginError.new(error_message)
      error.set_backtrace(caller)
      raise(error)
    end

    def process_re_download(action, _action_result, opts)
      error_message = "Re download task: #{opts[:task].url} after #{action}"
      error = EmEasyScraper::ReDownloadError.new(error_message)
      error.set_backtrace(caller)
      raise(error)
    end

    def process_ok(_action, _action_result, _opts)
      true
    end

    def create_crawler_pool
      @crawler_pool = Pool.new(actions_per_period: Config.instance.requests_in_minute)
      @crawler_pool.on_done do
        EmEasyScraper.logger.debug('Crawler pool on done')
        unless Config.instance.daemon
          EmEasyScraper.logger.info('There are no tasks. Stop')
          EM.stop
        end
      end
      on_error = proc do |worker|
        if worker.error.is_a?(EmEasyScraper::ReDownloadError)
          @crawler_pool.add(worker)
        else
          re_login_worker(worker,
                          attempt: worker.login_attempt)
        end
        worker.error = nil
      end
      @crawler_pool.on_error(on_error)
      (@opts[:workers] || Config.instance.workers).times do |worker_number|
        create_worker(worker_number)
      end
    end

    def create_worker(worker_number, attempt: 0, login_delay: 0)
      promise = PromiseEm::Promise.new do |resolve, reject|
        provider = provider_class.new(@opts, worker_number)
        provider.callback { resolve.call(provider) }.errback { |*error| reject.call(*error) }
      end
      promise.then { |provider| Worker.new(provider: provider, worker_number: worker_number) }
             .then { |worker| EM::Timer.new(login_delay.to_i) { login_todo.push(worker) } }

      promise.catch do |error|
        message = "Can't create worker, initialize error: #{error}. Try again #{attempt}"
        EmEasyScraper.logger.error(message)
        if attempt >= Config.instance.max_login_try_count
          raise(EmEasyScraper::Error, "Can't create worker, initialize error: #{error}. Attempt #{attempt - 1}",
                error.backtrace)
        end

        EM.next_tick { create_worker(worker_number, attempt: attempt + 1, login_delay: login_delay) }
      end
    end

    def perform_todo
      todo.subscribe do |task|
        @crawler_pool.perform(task) do |worker|
          promise = PromiseEm::Promise.new { |resolve, _reject| resolve.call }
                                      .catch do |error|
            EmEasyScraper.logger.error("Error #{error.class}: #{error}")
            EmEasyScraper.logger.error(error.backtrace) unless [EmEasyScraper::ReDownloadError,
                                                                EmEasyScraper::LoginError].include?(error.class)
            re_push_task(task)
            worker.error = error
          end

          add_requests_chain(promise, worker, task)
        end
      end
    end

    def add_requests_chain(promise, worker, task)
      promise.then { process_provider_action(:pre_crawl, task: task, worker: worker) }
             .then { process_provider_action(:crawl, task: task, worker: worker) }
             .then do |request|
        fill_task(request, worker, task)
        request
      end
      promise.then do |request|
        process_provider_action(
          :post_crawl,
          task: task,
          worker: worker,
          response: request.response,
          response_code: request.response_header.status,
          request: request
        )
      end
      promise.then do
        EM.next_tick do
          worker.provider.parse(task)
          schedule_tasks(worker.provider.scheduled_tasks)
          worker.provider.scheduled_tasks.clear
        end
      end
    end

    def fill_task(request, worker, task)
      task.response_body = request.response
      task.response_code = request.response_header.status
      task.response_headers = request.response_header.to_h
      task.proxy = worker.provider.data[:proxy]
      task.data[:level] ||= 0
      task.data[:level] += 1
    end

    def provider_class
      @provider_class ||= Object.const_get("EmEasyScraper::Provider::#{(@opts[:provider] ||
        Config.instance.provider).classify}")
    end

    def login_todo
      @login_todo ||= EM::Channel.new
    end

    def todo
      @todo ||= EM::Channel.new
    end

    def schedule_tasks(tasks)
      tasks.each { |task| push_task(task) }
    end

    def push_task(task)
      todo.push(task)
    end

    def re_push_task(task)
      task.try_count += 1
      if task.try_count > Config.instance.max_task_try_count
        @stat[:not_downloaded_tasks] ||= []
        @stat[:not_downloaded_tasks] << task
        EmEasyScraper.logger.warn("Can't download task #{task.url} after #{task.try_count} attempts. Skip")
      else
        push_task(task)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
