# frozen_string_literal: true

module EmEasyScraper
  module Plugin
    module PerformanceTracker
      def self.prepended(base)
        instance_methods = base.instance_methods - Object.instance_methods - EM::Deferrable.instance_methods
        private_instance_methods = base.private_instance_methods - Object.private_instance_methods -
                                   EM::Deferrable.private_instance_methods
        (instance_methods + private_instance_methods).each do |method|
          define_method method do |*args|
            start = Time.now.to_f
            result = super(*args)
            execution_time = Time.now.to_f - start
            if execution_time > 0.0001
              ::EmEasyScraper.logger.debug("method: #{method}, execution time #{execution_time}")
            end
            result
          end
        end
      end
    end
  end
end
