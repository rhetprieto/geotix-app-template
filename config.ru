require 'voom/presenters/api/app'
require 'voom/presenters/web_client/app'
require_relative "server"

Voom::Presenters::Settings.configure do |config|
    config.presenters.root = __dir__
end


# CORs Support
# You need this if you are allowing direct browser access to this app.
# One example would be if you redirect after install or revoke
# If all interactions are server to server then you don't need this.
require 'rack/cors'
use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: %i(get post)
  end
end

use Voom::Presenters::WebClient::App
run GeotixApp

Voom::Presenters::App.boot!
