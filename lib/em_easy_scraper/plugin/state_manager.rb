# frozen_string_literal: true

module EmEasyScraper
  module Plugin
    module StateManager
      def worker_options(worker_number)
        options = {}
        state = restore_state
        if state
          @state = state
          options[:proxy] = @state.dig(:provider_data, :proxy).to_h if @state.dig(:provider_data, :proxy)
          options[:tls] = { cipher_list: @state.dig(:provider_data, :cipher_list) } if @state.dig(:provider_data,
                                                                                                  :cipher_list)
        end
        super.merge(options)
      end

      def after_worker_initialize(worker)
        if defined?(@state)
          worker.context = @state[:context]
          @data = @state[:provider_data]
        end
        super
      end

      def login(worker)
        if defined?(@state)
          ::EmEasyScraper.logger.info("State was restored for worker #{context_key}")
          remove_instance_variable(:@state)
          return { status: Provider::Base::STATUS[:OK] }
        end
        result = super
        result.key?(:deferrable) ? result[:deferrable].callback { save_state(worker) } : save_state(worker)
        result
      end

      def after_re_login_worker(worker, attempt:, login_delay:)
        cache.delete(workers_state_key(context_key))
        ::EmEasyScraper.logger.info("State for worker #{context_key} was removed")
        super
      end

      def before_exit(worker)
        save_state(worker)
        super
      end

      private

      def restore_state
        cache.read(workers_state_key(context_key))
      end

      def save_state(worker)
        cache.write(
          workers_state_key(context_key),
          context: worker.context,
          provider_data: data
        )
        ::EmEasyScraper.logger.info("State was saved for worker #{context_key}")
      end

      def workers_state_key(context_key)
        [
          @worker_number,
          context_key
        ].compact.join(':')
      end
    end
  end
end
