# frozen_string_literal: true

EventMachine::Connectify::CONNECT.class_eval do
  def connect_parse_response
    unless @connect_data =~ %r{\AHTTP/1\.[01] 200 .*\r\n\r\n}m
      raise EventMachine::Connectify::CONNECTError.new, "Unexpected response: #{@connect_data}"
    end

    connect_unhook
  rescue EventMachine::Connectify::CONNECTError => e
    @connect_deferrable.fail(e)
  end
end
