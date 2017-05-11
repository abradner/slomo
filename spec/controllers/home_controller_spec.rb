# frozen_string_literal: true

require 'rails_helper'
require 'time'
require 'json'
require 'redis'

DEFAULT_WINDOW = HomeController.DEFAULT_WINDOW # 1.hour
LOAD_LIMIT = HomeController.LOAD_LIMIT # 100

RSpec.describe HomeController, type: :controller do
  before :all do
    @redis = Redis.new
  end

  before :each  do
    @redis.flushdb
  end

  describe 'GET index' do
    it "INTEGRATION: has a 200 status code and returns 'ok' on the first request" do
      get :index
      expect(response.status).to eq(200)
      expect(response.body).to eq('ok')
    end
    it "INTEGRATION: should give a 429 status code and NOT return 'ok' when we excede a threshold in a given window" do
      time_zero = Time.now

      # Perform the complete request LOAD_LIMIT times
      LOAD_LIMIT.times do
        get :index
      end

      elapsed_time = Time.now - time_zero

      # once more to actually exceed the limiter
      get :index

      # this is just in case the suite was frozen or took longer than the window to run
      expect(elapsed_time).to be_between(0, DEFAULT_WINDOW)
      # TODO: change to a more concrete assertion.

      expect(response.status).to eq(429)
      expect(response.body).to_not eq('ok')
    end

    it "INTEGRATION: shouldgive a 200 OK if we've been previously limited but no longer are" do
      requests = build_requests(LOAD_LIMIT, proc { Time.now - DEFAULT_WINDOW })
      @redis.set 'requests', requests.to_json

      get :index

      expect(response.status).to eq(200)
      expect(response.body).to eq('ok')
    end

    it 'INTEGRATION: should insert requests with a sane timestamp' do
      time_start = Time.now
      sleep 0.01 # ruby timestamp comparison is only down to the milisecond. lets make sure this never affects our tests
      get :index
      time_end = Time.now

      requests = JSON.parse @redis.get('requests')
      expect(requests.length).to eq(1) # we definitely should only have one record right now
      expect(requests.first['timestamp']).to be_between(time_start, time_end)
    end

    it 'when blocking a request, should return the right amount of time until the oldest historic successful request expires' do
      requests = build_requests
      @redis.set 'requests', requests.to_json

      time_start = Time.now
      sleep 0.01 # ruby timestamp comparison is only down to the milisecond. lets make sure this never affects our tests
        get :index
      time_end = Time.now

      time_elapsed = time_end - time_start

      # We want to report in seconds rounded up, so round down our elapsed time
      expected_wait = DEFAULT_WINDOW - time_elapsed.floor

      expect(response.status).to eq(429)
      expect(extract_int(response.body)).to be_within(time_elapsed).of(expected_wait)
    end

    it "Should insert new requests into the store if they're successful" do
      get :index
      new_requests = JSON.parse @redis.get('requests')
      expect(new_requests.length).to eq(1)
    end

    it "should not insert new requests into the store if they're blocked" do
      requests = build_requests
      @redis.set 'requests', requests.to_json

      old_requests = JSON.parse @redis.get('requests')
      expect(old_requests.length).to eq(LOAD_LIMIT)

      get :index

      new_requests = JSON.parse @redis.get('requests')
      expect(new_requests.length).to eq(LOAD_LIMIT)
    end

    it 'Should clear out stale requests' do
      requests = build_requests(LOAD_LIMIT, proc { Time.now - DEFAULT_WINDOW })
      @redis.set 'requests', requests.to_json

      get :index

      new_requests = JSON.parse @redis.get('requests')
      expect(new_requests.length).to eq(1)
    end
  end

  describe 'Smoothing' do
    # High level behaviour test. # TODO refine this into a less vague test case
    it "should smooth request limiting over a small window and not allow exhaustion in the first  ia 429 status code and NOT returns 'ok' when we excede a threshold in a given window"
  end
end

# This helper just builds an array of N requests, with an optional custom proc being run for the timestamp
# Defaults arre LOAD_LIMIT requests timestamped at the moment they're invoked (which will all be within a few ms of each other)
def build_requests(quantity = LOAD_LIMIT, timestamp_proc = proc { Time.now })
  requests = []
  quantity.times do
    requests << {
      timestamp: timestamp_proc.call, # run whatever logic has been passed in to calculate a timestamp
      action:    nil, # not yet implemented
      source:    nil, # not yet implemented
    }.stringify_keys
  end
  requests
end

def extract_int(string)
  match = /([0-9]+)/.match(string)
  return match[0].to_i if match.present?
  return nil
end
