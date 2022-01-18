# frozen_string_literal: true

module EmEasyScraper
  class Task
    FIELDS = %i[
      url
      uri
      http_method
      try_count
      request_headers
      follow_location
      proxy
      post_body
      data
      response_size
      response_body
      response_code
      response_headers
      request_started
      request_finished
      doc
      json
    ].freeze

    attr_accessor(*FIELDS)

    def initialize(params = {})
      @try_count = 0
      @follow_location = false
      @data = {}
      initialize_parameters(params)
      @cache = {}
    end

    def first_level?
      @data[:level] == 1
    rescue StandardError
      false
    end

    def success?
      @response_code == 200
    rescue StandardError
      false
    end

    def uri
      return if url.blank?
      return @cache[checksum] if @cache[checksum]

      @cache[checksum] = Addressable::URI.parse(@url)
    end

    def http_method
      @http_method || (post_body.nil? ? :get : :post)
    end

    def response_size
      @response_size ||= response_body.bytesize if response_body.present?
    end

    def doc
      @doc ||= Nokogiri::HTML(response_body) if response_body.present?
    end

    def json
      @json ||= JSON.parse(response_body, symbolize_names: true) if response_body.present?
    end

    def checksum
      Digest::MD5.hexdigest(
        [
          @url,
          @http_method,
          @request_headers,
          @post_body
        ].compact.join('_')
      )
    end

    def to_h
      Hash[instance_variables.map { |name| [name[1..].to_sym, instance_variable_get(name)] }]
    end

    private

    def initialize_parameters(params)
      params.each do |key, value|
        raise(EmEasyScraper::Error, "Invalid parameter #{key}") unless FIELDS.include?(key)

        instance_variable_set("@#{key}", value)
      end
    end
  end
end
