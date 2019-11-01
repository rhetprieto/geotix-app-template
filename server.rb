require 'sinatra'
require 'dotenv/load' # Manages environment variables
require 'json'
require 'openssl' # Verifies the webhook signature
require 'logger' # Logs debug statements
require 'pry' if ENV.fetch('RACK_ENV'){'development'} == 'development'
# This is template code to create a Geotix App server.
# You can read more about Geotix Apps here: # https://developer.geotix.io/apps/
#
# On its own, this app does absolutely nothing, except that it can be installed.
# It's up to you to add functionality!
#
# This code is a Sinatra app, for three reasons:
#   1. Because the app will require a landing page for installation.
#   2. To easily handle webhook events.
#   3. It can extend the Geotix User interace using POM json
#
# A Geotix App can be written in any language
# It only needs to have install revoke and either a notify or extend endpoint.
#
class GeotixApp < Sinatra::Application
  include Voom::Presenters::Api::RenderPresenter

  # Your registered app must have a secret set. The secret is used to verify
  # that webhooks are sent by Geotix.
  WEBHOOK_SECRET = ENV.fetch('GEOTIX_WEBHOOK_SECRET','').freeze

  # Turn on Sinatra's verbose logging during development
  configure :development do
    set :logging, Logger::DEBUG
  end


  # Before each request
  before do
    get_request_data(request)
    verify_webhook_signature
  end

  # Install your application
  # Applications can be installed globally (contact Geotix),
  # for a Network Partner (NP) and
  # for an Event Creator (EC) or for both a NP and EC.
  #
  # Perform any setup for your application here specific to WHO registered it
  # The auth_token can be used to access the Geotix API in the same data scope
  # as the user who installed the application.
  #
  # DO NOT store these tokens, they expire and will be of little use to you.
  # DO NOT expose these tokens to the client they should be used only on the server
  #
  # This is called when your app is installed by a user to the Geotix system
  post '/install' do

    # # # # # # # # # # # #
    # ADD YOUR CODE HERE  #
    # # # # # # # # # # # #
    logger.debug{"Install with payload(#{payload})"}
    # return any configuration you want stored.
    # You can return any arbitrary configuration you want it will be passed to you
    # in the body of each call that is made to you.
    # This is a good place to hold installation specific values.
    # content_type :json
    # # You can optionally return configuration specific to your app
    # # The config will be passed to unregister
    # response = {config: {nicks_best_movie: 'they are all so good'},
    #             # if you want to have the user complete additional installation
    #             # You can redirect to your installation page
    #             # This example is going to redirect to the `install.pom` presenter.
    #             # This page can be whatever you need the user to do to complete installation
    #             # or you can skip it all together.
    #             redirect_url: "#{request.base_url}/install"}.to_json
    # body response
    200
  end

  # Revoke (uninstall) your application.
  # When a user uninstalls your application this callback gives you a chance to cleanup.
  #
  # The auth_token can be used to access the Geotix API in the same data scope
  # as the user who installed the application.
  #
  # DO NOT store these tokens, they expire and will be of little use to you.
  # DO NOT send these tokens to the client they should be used only on the server
  post '/revoke' do
    # # # # # # # # # # # #
    # ADD YOUR CODE HERE  #
    # # # # # # # # # # # #
    logger.debug{"Revoke with payload(#{payload})"}

    # response = {# if you want to have the user complete additional revoke steps in your UI
    #             # You can optionally redirect to your revoke/goodbye page
    #             # This will load the `revoke.pom`
    #             # This page can be whatever you need the user to do when they revoke your application
    #             # or you can skip it all together.
    #             redirect_url: "#{request.base_url}/revoke"}.to_json
    # body response
    200 # success status
  end

  # Called when a registered notification event is triggered
  post '/notify' do
    # # # # # # # # # # # #
    # ADD YOUR CODE HERE  #
    # # # # # # # # # # # #
    logger.debug{"Notify(#{event_code}) with payload(#{payload}) and config(#{config})"}
    # success status
    200
  end

  # Called when a registered user interface extension point is triggered
  # Returns Presenters Object Model (POM) json
  post '/extend' do
    content_type :json
    # This is your configuration you setup and returned from register
    # logger.debug { "Extend(#{point_code}) with payload(#{payload}) and config(#{config})" }
    # The extension 'point' in the Geotix user interface
    # These are locations that can be extended.
    body render_presenter(point_code)
    200
  end

  helpers do
    # # # # # # # # # # # # # # # # #
    # ADD YOUR HELPER METHODS HERE  #
    # # # # # # # # # # # # # # # # #

    # Saves the raw payload and converts the payload to JSON format
    def get_request_data(request)
      # request.body is an IO or StringIO object
      # Rewind in case someone already read it
      request.body.rewind
      # The raw text of the body is required for webhook signature verification
      @payload_raw = request.body.read
      begin
        logger.debug { params }
        logger.debug{ @payload_raw.to_s.strip }
        @payload = JSON.parse @payload_raw unless @payload_raw.to_s.strip.empty?
      rescue => e
        logger.warn "Invalid JSON (#{e}): #{@payload_raw}"
      end
    end

    # Returns the config that you stored for your application when it was installed
    def config
      @payload.fetch('config')
    end

    # Returns the event code that you were notified for
    def event_code
      @payload.fetch('event')
    end

    # Returns the extension point code used by the /extend endpoint
    def point_code
      @payload.fetch('point')
    end

    # Returns the data associated with the event
    # Usually contains the id of the subject and the organization_id and portal_id that it originated from
    def payload
      @payload.fetch('payload')
    end

    # Check X-Geotix-Signature to confirm that this webhook was generated by
    # Geotix, and not a malicious third party.
    #
    # Geotix uses the WEBHOOK_SECRET, registered to the Geotix App, to
    # create the hash signature sent in the `X-Geotix-Signature` header of each
    # webhook. This code computes the expected hash signature and compares it to
    # the signature sent in the `X-Geotix-Signature` header. If they don't match,
    # this request is an attack, and you should reject it. Geotix uses the HMAC
    # hexdigest to compute the signature. The `X-Geotix-Signature` looks something
    # like this: "sha1=123456".
    def verify_webhook_signature
      their_signature_header = request.env['HTTP_X_GEOTIX_SIGNATURE'] || 'sha1='
      method, their_digest = their_signature_header.split('=')
      our_digest = OpenSSL::HMAC.hexdigest(method, WEBHOOK_SECRET, "#{auth_token}#{@payload_raw}")
      halt [401, "Signatures don't match."] unless their_digest == our_digest
    end

    # Returns the auth token of the user that invoked your app.
    # It allows you to use the Geotix API with the data access scoped to match
    # the users data scope, and with the privileges that you requested on the API
    # when you setup your application.
    def auth_token
      request.env['HTTP_X_GEOTIX_AUTH_TOKEN']
    end
  end
end
