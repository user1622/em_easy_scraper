# frozen_string_literal: true

module EmEasyScraper
  module Middleware
    class HeadersManager
      # rubocop:disable Metrics/AbcSize
      def request(client, head, body)
        worker = client.conn
        worker.provider.on_request(client, head, body)
        client.req.headers.clear if client.redirect?
        head = worker.provider.request_headers(client.req.uri, client.req.headers, body)
        head.transform_keys! { |key| key.to_s.downcase }
        head['host'] = client.req.uri.host if head.key?('host')
        head['user-agent'] = worker.provider.data[:user_agent] if head.key?('user-agent') && head['user-agent'].nil?
        head['content-length'] = body.to_s.bytesize if head.key?('content-length') && head['content-length'].nil?
        head['referer'] = @referer if head.key?('referer') && head['referer'].nil? && @referer
        if head.key?('cookie') && (head['cookie'].nil? || client.redirect?)
          head['cookie'] = worker.context.cookies_as_str(client.req.uri)
        end
        head.compact!

        client.req.instance_variable_set(:@headers, head)
        [head, body]
      end
      # rubocop:enable Metrics/AbcSize

      def response(resp)
        worker = resp.conn
        worker.provider.on_response(resp)
        worker.context.update_cookie(resp.response_header, resp.req.uri.to_s)
        @referer = resp.req.uri.to_s
        resp
      end
    end
  end
end
