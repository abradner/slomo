class HomeController < ApplicationController
  DEFAULT_WINDOW = 1.hour
  LOAD_LIMIT = 100
  def index
    render json: 'ok'
  end

  def self.DEFAULT_WINDOW
    DEFAULT_WINDOW
  end
  def self.LOAD_LIMIT
    LOAD_LIMIT
  end
  
end
