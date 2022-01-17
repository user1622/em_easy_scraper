# frozen_string_literal: true

module EmEasyScraper
  class Proxy
    def initialize(uri, type = '')
      @uri = uri
      @type = type
    end

    def self.parse(proxy_line)
      uri, type = proxy_line.strip.split('@@@')
      new(Addressable::URI.parse(uri), type)
    end

    def to_s
      [@uri.to_s, @type].join('@@@')
    end

    def to_h
      proxy = {
        host: @uri.host,
        port: @uri.port
      }
      proxy[:authorization] = [@uri.user, @uri.password] if @uri.userinfo
      proxy[:type] = :socks5 if @type == 'socks5'
      proxy
    end

    def hash
      to_s.hash
    end

    def eql?(other)
      other.class == self.class && other.to_s == to_s
    end

    def <=>(other)
      if other.to_s < to_s
        1
      elsif other.to_s > to_s
        -1
      else
        0
      end
    end
  end

  module Plugin
    module ProxyManager
      module ClassMethods
        def read_proxies
          raise NotImplementedError unless defined?(super)

          super
        end
      end

      def initialize(*_args)
        super
        @proxy_ban_period ||= 5.minutes
        unless Helper::ProxyManager.opts
          proxy_data = self.class.read_proxies
          Helper::ProxyManager.opts = {
            cache: cache,
            namespace: contex_key,
            data: proxy_data
          }
        end
        @proxy_manager = Helper::ProxyManager.instance
      end

      def self.prepended(base)
        class << base
          prepend ClassMethods
        end
      end

      def rate_limit_key(_)
        [super, Digest::MD5.hexdigest(data[:proxy].to_s)].join(':')
      end

      def worker_options(worker_number)
        options = super
        if options.key?(:proxy)
          @proxy_manager.data.delete_if { |element| element[:element].to_h == options[:proxy] }
        else
          data[:proxy] = @proxy_manager.pop
          options.merge!(proxy: data[:proxy].to_h)
          ::EmEasyScraper.logger.debug("New proxy: #{data[:proxy]} for worker #{context_key}")
        end
        options
      end

      def after_re_login_worker(worker, attempt:, login_delay:)
        if data[:proxy]
          @proxy_manager.push(data[:proxy], ban_time: @proxy_ban_period)
          ::EmEasyScraper.logger.debug("Proxy #{data[:proxy]} was banned")
        end
        super
      end
    end
  end
end
