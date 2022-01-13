# frozen_string_literal: true

module EmEasyScraper
  module Helper
    class ProxyManager < RotationManager
      protected

      def cache_namespace
        'proxy_manager'
      end
    end
  end
end
