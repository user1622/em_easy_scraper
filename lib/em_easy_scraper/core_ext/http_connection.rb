# frozen_string_literal: true

module EventMachine
  class HttpConnection
    attr_accessor :on_connection_error

    # rubocop:disable Metrics/AbcSize
    def connection_completed(*_args)
      @peer = @conn.get_peername
      if @connopts.socks_proxy?
        socksify(client.req.uri.host, client.req.uri.inferred_port, *@connopts.proxy[:authorization]) { start }
      elsif @connopts.connect_proxy?
        connectify(client.req.uri.host, client.req.uri.inferred_port, *@connopts.proxy[:authorization]) { start }
        @connect_deferrable.errback do |error|
          on_connection_error&.call(error)
        end
      else
        start
      end
    end
    # rubocop:enable Metrics/AbcSize

    def redirect(client, new_location)
      client.req.instance_variable_set(:@method, 'GET')
      client.req.instance_variable_set(:@body, nil)
      old_location = client.req.uri
      new_location = client.req.set_uri(new_location)
      if client.req.keepalive
        if old_location.origin != new_location.origin
          client.conn.uri = client.req.uri
          client.conn.connopts.https = new_location.scheme == 'https'
          client.conn.activate_connection(client)
        else
          @clients.push(client)
          client.connection_completed
        end
      else
        @pending.push(client)
      end
    end
  end
end
