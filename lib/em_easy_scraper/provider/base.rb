# frozen_string_literal: true

module EmEasyScraper
  module Provider
    # rubocop:disable Metrics/ClassLength
    class Base
      include EM::Deferrable

      STATUS = {
        OK: :OK,
        RE_LOGIN: :RE_LOGIN,
        RE_DOWNLOAD: :RE_DOWNLOAD
      }.freeze

      attr_accessor :worker_number, :crawler_number, :data, :scheduled_tasks

      def initialize(opts, worker_number)
        @worker_number = worker_number
        @scheduled_tasks = []
        @data = {}
        @opts = opts
        succeed if self.class.to_s == 'EmEasyScraper::Provider::Base'
      end

      def rate_limit_key(task)
        ['rate_limit', task.uri.host].join(':')
      end

      def worker_options(_worker_number)
        { connect_timeout: 15, inactivity_timeout: 20 }
      end

      def after_worker_initialize(_worker); end

      def request_options(uri, task)
        { path: uri.request_uri, body: task.post_body, head: task.request_headers, keepalive: true, redirects: 2 }
      end

      def after_re_login_worker(*_args); end

      def login(_worker)
        { status: STATUS[:OK] }
      end

      def after_login(_worker)
        { status: STATUS[:OK] }
      end

      def pre_crawl(_worker, _task)
        { status: STATUS[:OK] }
      end

      def crawl(worker, task)
        update_connection_host(worker, task)
        uri = worker.provider.prepare_uri(task)
        http_method = task.http_method
        request = worker.send(http_method, worker.provider.request_options(uri, task))
        {
          status: STATUS[:OK],
          deferrable: request
        }
      end

      def post_crawl(_worker, _task, _response, _response_code)
        { status: STATUS[:OK] }
      end

      def parse(_task); end

      def schedule_task(task)
        @scheduled_tasks << task
      end

      def context_key
        'context_key'
      end

      def on_request(_client, _headers, _body)
        true
      end

      def on_response(_response)
        true
      end

      def prepare_uri(task)
        task.uri
      rescue StandardError => e
        EmEasyScraper.logger.error("Task: #{task}")
        raise e
      end

      def request_headers(_uri, request_headers, _post_body)
        return request_headers if request_headers.any?

        {
          "Host": nil,
          "User-Agent": 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:69.0) Gecko/20100101 Firefox/69.0',
          "Accept": 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          "Accept-Language": 'en-US,en;q=0.5',
          "Accept-Encoding": 'gzip, deflate, br',
          "Referer": nil,
          "Connection": 'keep-alive',
          "Cookie": nil,
          "Upgrade-Insecure-Requests": '1',
          "Cache-Control": 'max-age=0'
        }
      end

      def before_exit(_worker); end

      private

      # rubocop:disable Metrics/AbcSize
      def update_connection_host(worker, task)
        uri = worker.provider.prepare_uri(task)
        worker.uri = URI.parse(worker.uri) if worker.uri.is_a?(String)
        if uri.host != worker.uri.host
          worker.uri = uri.dup
          worker.connopts.tls[:sni_hostname] = worker.uri.host
          worker.connopts.https = worker.uri.scheme == 'https' unless worker.connopts.proxy
          unless worker.connopts.proxy
            worker.connopts.instance_variable_set(:@port,
                                                  worker.uri.port || (worker.uri.scheme == 'https' ? 443 : 80))
          end
          worker.connopts.instance_variable_set(:@host, worker.uri.host) unless worker.connopts.proxy
          if worker.conn
            old_conn = worker.conn
            def old_conn.unbind(*args); end
            worker.unbind
          end
        end
        worker.uri.path = ''
        worker.uri.query = nil
      end
      # rubocop:enable Metrics/AbcSize

      def cache
        EmEasyScraper::Config.instance.cache
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
