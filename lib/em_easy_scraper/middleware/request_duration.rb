# frozen_string_literal: true

module EmEasyScraper
  module Middleware
    class RequestDuration
      def request(client, head, body)
        worker = client.conn
        worker.finished_at = nil
        worker.started_at = Time.now.to_f
        [head, body]
      end

      def response(resp)
        worker = resp.conn
        worker.finished_at = Time.now.to_f
        resp
      end
    end
  end
end
