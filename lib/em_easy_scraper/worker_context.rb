# frozen_string_literal: true

module EmEasyScraper
  class WorkerContext
    attr_reader :stored_cookies
    attr_accessor :ignore_cookie_regexp

    def initialize
      @stored_cookies = HTTP::CookieJar.new
    end

    def stored_cookies=(cookies)
      @stored_cookies = cookies || HTTP::CookieJar.new
    end

    def add_cookies(cookies)
      cookies.each do |cookie|
        add_cookie(cookie)
      end
    end

    def add_cookie(cookie)
      return if cookie.expires && cookie.expires <= Time.now
      return if ignore_cookie_regexp && cookie.name =~ ignore_cookie_regexp

      @stored_cookies.add(cookie)
    end

    def delete_cookie(cookie)
      return if cookie.expires && cookie.expires <= Time.now

      @stored_cookies.delete(cookie)
    end

    def cookies_as_str(url)
      cookies = @stored_cookies.cookies(url).map(&:to_s).join('; ')
      cookies.blank? ? nil : cookies
    end

    def clear_cookies(url)
      @stored_cookies.cookies(url).each do |cookie|
        @stored_cookies.delete(cookie)
      end
    end

    def update_cookie(headers, url)
      headers.each do |name, value|
        parse_cookie_lines(value, Addressable::URI.encode_component(url)) if name == EM::HttpClient::SET_COOKIE
      end
    end

    def marshal_dump
      [@stored_cookies.to_yaml, ignore_cookie_regexp.to_s]
    end

    def marshal_load(array)
      @stored_cookies, @ignore_cookie_regexp, = array
      @stored_cookies = YAML.load(@stored_cookies)
      @ignore_cookie_regexp = @ignore_cookie_regexp.blank? ? nil : Regexp.new(ignore_cookie_regexp)
    end

    private

    def parse_cookie_lines(lines, url)
      Array(lines).each do |line|
        @stored_cookies.parse(line, url) do |cookie|
          add_cookie(cookie)
        end
      end
    end
  end
end
