# frozen_string_literal: true

# require 'redis'

module Rack
  class Limiter
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      respond_limited(request) && return if limited?(request)

      app.call(env)
    end

    private

    def limited?
      true
    end

    def respond_limited
      [
        429, # status
        {}, # headers
        "Rate limit exceeded. Try again in #{retry_time} seconds" # body
      ]
    end

    def retry_time
      0
    end
  end
end
