# frozen_string_literal: true

module EmEasyScraper
  module Middleware
    class HttpVerbose
      # rubocop:disable Metrics/AbcSize
      def request(client, head, body)
        uri = client.req.uri.dup
        query = []
        query += uri.query.split('&') if uri.query.present?
        query += client.req.query.map { |param| param.join('=') } if client.req.query.present?
        uri.query = query.uniq.join('&') if query.any?
        warn client.conn.connopts.proxy if client.conn.connopts.proxy.present?
        warn client.conn.connopts.tls if client.conn.connopts.tls.present?
        warn "#{client.req.method} #{client.req.path} HTTP/1.1"
        warn client.req.headers.to_a.map { |header| header.join(': ') }.join("\n")
        warn "\r\n"
        warn "#{body} \r\n" if body
        warn "\n"
        [head, body]
      end
      # rubocop:enable Metrics/AbcSize

      def response(resp)
        warn resp.req.uri.to_s
        warn "HTTP/#{resp.response_header.http_version} #{resp.response_header.status}"\
" #{resp.response_header.http_reason}"
        warn resp.response_header.to_a.map { |header| header.join(': ') }.join("\n")
        warn "\r\n"
        resp
      end
    end
  end
end
