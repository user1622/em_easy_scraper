# frozen_string_literal: true

module EmEasyScraper
  module AutoDelayCall
    class Memory < Base
      def initialize(*_args)
        super
        @actions = {}
      end

      def calculate_delay(key)
        since_last_call = if @actions.key?(key)
                            Time.now.to_i - @actions[key]
                          else
                            @normal_delay
                          end

        if since_last_call < @normal_delay
          @normal_delay - since_last_call
        else
          @actions[key] = Time.now.to_i
          0
        end
      end
    end
  end
end
