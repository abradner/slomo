# frozen_string_literal: true

# require 'redis'
require 'active_support/core_ext/numeric/time' # for convenience methods like 1.hour

module Rack
  class Limiter
    attr_reader :app
    DEFAULT_WINDOW = 1.hour
    LOAD_LIMIT = 100

    # Exporting these so they can be used in rspec before i properly refactor this
    def self.DEFAULT_WINDOW
      DEFAULT_WINDOW
    end

    def self.LOAD_LIMIT
      LOAD_LIMIT
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      return respond_limited(request) if limited?(request)

      @app.call(env)
    end

    private

    def limited?(_request)
      true
    end

    def respond_limited(request)
      [
        429, # status
        {}, # headers
        "Rate limit exceeded. Try again in #{retry_time(request)} seconds" # body
      ]
    end

    def retry_time(_request)
      0
    end
  end
end
