# frozen_string_literal: true

require 'redis'
require 'json'

class HomeController < ApplicationController
  def index
    render json: 'ok'
  end
end
