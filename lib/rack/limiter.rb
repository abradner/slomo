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
      redis = Redis.new
      request_time = Time.now

      # Load existing requests or initialise a new array if none there
      raw_requests = redis.get 'requests'

      requests = raw_requests.present? ? JSON.parse(raw_requests) : []

      # Trim anything older than the window (yay side effects)
      requests.delete_if do |req|
        DateTime.iso8601(req['timestamp']) < request_time - DEFAULT_WINDOW
      end

      # Count what's left and decide what to do
      if requests.count >= LOAD_LIMIT # use >= because we're only counting existing requests.
        # We've exceded our limit so we need to abort execution of the action
        @oldest_request = DateTime.iso8601 requests.first['timestamp']
        return true
      else
        # not limited so push req to redis and continue
        this_req = {
          timestamp: request_time, # when the request was made
          action:    nil, # what was the request (can be used to filter by action)
          source:    nil, # who made the request (can be used to filter by client)
        }.stringify_keys

        requests << this_req
        redis.set 'requests', requests.to_json
        return false
      end
  end

    def respond_limited(request)
      [
        429, # status
        {}, # headers
        "Rate limit exceeded. Try again in #{retry_time(request)} seconds" # body
      ]
    end

    def retry_time(_request)
      # Work out how long we need to wait, rounding up
      DEFAULT_WINDOW - (Time.now - @oldest_request).floor
    end
  end
end
