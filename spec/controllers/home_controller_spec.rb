require 'rails_helper'
require 'time'
require 'json'

DEFAULT_WINDOW = HomeController.DEFAULT_WINDOW || 1.hour
LOAD_LIMIT = HomeController.LOAD_LIMIT || 100

RSpec.describe HomeController, type: :controller do

  describe "GET index" do
    it "has a 200 status code and returns 'ok' on the first request" do
      get :index
      expect(response.status).to eq(200)
      expect(response.body).to eq('ok')
    end
    it "should give a 429 status code and NOT return 'ok' when we excede a threshold in a given window" do

      time_zero = Time.now

      LOAD_LIMIT.times do
        get :index
      end

      elapsed_time = Time.now - time_zero
      
      # once more to actually exceed the limiter
      get :index

      expect(elapsed_time).to be_between(0,DEFAULT_WINDOW)  #TODO change to a more concrete assertion.

      expect(response.status).to eq(429)
      expect(response.body).to_not eq('ok')
    end

  end

  describe 'Smoothing' do
    # High level behaviour test. # TODO refine this into a less vague test case
    it "should smooth request limiting over a small window and not allow exhaustion in the first  ia 429 status code and NOT returns 'ok' when we excede a threshold in a given window" do
      get :index
      expect(response.status).to eq(200)
      expect(response.body).to eq('ok')
    end
  end
end