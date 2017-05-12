# frozen_string_literal: true

require 'rack/test'
require 'rack/limiter'

# require 'rails_helper'
# require 'time'
require 'json'
require 'redis'

DEFAULT_WINDOW = Rack::Limiter.DEFAULT_WINDOW # 1.hour
LOAD_LIMIT = Rack::Limiter.LOAD_LIMIT # 100

describe Rack::Limiter do
  include Rack::Test::Methods
  include_context 'slomo_test'
  let(:app) { described_class.new(target_app) }

  before :all do
    @redis = Redis.new
  end

  before :each  do
    @redis.flushdb
  end

  describe 'GET index' do
    it 'when blocking a request, should return the right amount of time until the oldest historic successful request expires' do
      requests = build_requests
      @redis.set 'requests', requests.to_json

      time_start = Time.now
      sleep 0.01 # ruby timestamp comparison is only down to the milisecond. lets make sure this never affects our tests
      get '/'
      time_end = Time.now

      time_elapsed = time_end - time_start

      # We want to report in seconds rounded up, so round down our elapsed time
      expected_wait = DEFAULT_WINDOW - time_elapsed.floor

        expect(last_response.status).to eq(429)
      expect(extract_int(last_response.body)).to be_within(time_elapsed).of(expected_wait)
    end

    it "Should insert new requests into the store if they're successful" do
      get '/'
      new_requests = get_requests
      expect(new_requests.length).to eq(1)
    end

    it "should not insert new requests into the store if they're blocked" do
      requests = build_requests
      @redis.set 'requests', requests.to_json

      old_requests = get_requests
      expect(old_requests.length).to eq(LOAD_LIMIT)

      get '/'

      new_requests = get_requests
      expect(new_requests.length).to eq(LOAD_LIMIT)
    end

    it 'Should clear out stale requests' do
      requests = build_requests(LOAD_LIMIT, proc { Time.now - DEFAULT_WINDOW })
      @redis.set 'requests', requests.to_json

      get '/'

      new_requests = get_requests
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
  nil
end

def get_requests
  JSON.parse(@redis.get('requests') || '[]', quirks_mode: true)
end
