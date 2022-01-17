# frozen_string_literal: true

module EmEasyScraper
  module Helper
    class ProxyManager < RotationManager
      protected

      def cache_namespace
        ['proxy_manager', self.class.opts[:namespace]].join(':')
      end
    end
  end
end
