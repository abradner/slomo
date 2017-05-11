# frozen_string_literal: true

require 'redis'
require 'json'

class HomeController < ApplicationController
  DEFAULT_WINDOW = 1.hour
  LOAD_LIMIT = 100

  # Exporting these so they can be used in rspec before i properly refactor this
  def self.DEFAULT_WINDOW
    DEFAULT_WINDOW
  end

  def self.LOAD_LIMIT
    LOAD_LIMIT
  end

  before_action :check_rate

  def index
    render json: 'ok'
  end

  private

  def check_rate
    redis = Redis.new
    request_time = Time.now

    # Load existing requests or initialise a new array if none there
    raw_requests = redis.get 'requests'

    requests = raw_requests.present? ? JSON.parse(raw_requests) : []

    # Trim anything older than the window (yay side effects)
    requests.delete_if do |req|
      req['timestamp'] < request_time - DEFAULT_WINDOW
    end

    # Count what's left and decide what to do
    if requests.count >= LOAD_LIMIT # use >= because we're only counting existing requests.
      # We've exceded our limit so we need to abort execution of the action

      #Work out how long we need to wait, rounding up
      wait_required = DEFAULT_WINDOW - (Time.now - DateTime.iso8601(requests.first['timestamp'])).floor
      render json: "Rate limit exceeded. Try again in #{wait_required} seconds", status: 429
    else
      # not limited so push req to redis and continue
      this_req = {
        timestamp: request_time, # when the request was made
        action:    nil, # what was the request (can be used to filter by action)
        source:    nil, # who made the request (can be used to filter by client)
      }.stringify_keys

      requests << this_req
      redis.set 'requests', requests.to_json
      return true
  end

    # TODO: use a queue or pubsub rather than just klobbering the  shift and push to create a queue
  end
end
