# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
# require "active_model/railtie"
# require 'active_job/railtie'
require 'active_record/railtie' # due to rails bugs, rails won't load without half of these even if unused.
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
# require "action_cable/engine"
# require "sprockets/railtie"
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Slomo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.autoload_paths << Rails.root.join('lib') # Rails 5 apparently no longer autoloads your lib directory
    require "#{Rails.root}/lib/rack/limiter" # Because of the new load order, this goes here until I've fully investigated the new best practices.
    config.middleware.use Rack::Limiter # load our middleware
  end
end
