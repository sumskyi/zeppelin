require 'faraday'
require 'yajl'
require 'time'

# A very tiny Urban Airship Push Notification API client.
#
# Provides thin wrappers around API calls to the most common API tasks. For more
# information on how the requests and responses are formatted, visit the [Urban
# Airship Push Notification API docs](http://urbanairship.com/docs/push.html).
class Zeppelin
  BASE_URI = 'https://go.urbanairship.com'
  PUSH_URI = '/api/push/'
  BATCH_PUSH_URI = '/api/push/batch/'
  BROADCAST_URI = '/api/push/broadcast/'
  SUCCESSFUL_STATUS_CODES = (200..299)
  JSON_HEADERS = { 'Content-Type' => 'application/json' }

  APPLE_REG_EXP = /^[A-Z0-9]{64}$/

  # The connection to `https://go.urbanairship.com`.
  attr_reader :connection, :logger

  # Creates a new client.
  #
  # @param [String] application_key your Urban Airship Application Key
  # @param [String] application_master_secret your Urban Airship Application
  #   Master Secret
  def initialize(application_key, application_master_secret, logger = nil)
    @connection = Faraday::Connection.new(BASE_URI) do |builder|
      builder.request :json
      builder.adapter :net_http
    end
    @logger = logger
    @connection.basic_auth(application_key, application_master_secret)
  end

  # Registers a device token.
  #
  # @param [String] device_token
  # @param [Hash] payload the payload to send during registration
  # @return [Boolean] whether or not the registration was successful
  def register_device_token(device_token, payload = {})
    uri = device_token_uri(device_token)

    if payload.empty?
      response = @connection.put(uri)
    else
      response = @connection.put(uri, payload, JSON_HEADERS)
    end
    logger.info("register_device_token response: #{response.inspect}") if logger
    successful?(response)
  end

  # Retrieves information on a device token.
  #
  # @param [String] device_token
  # @return [Hash, nil]
  def device_token(device_token)
    response = @connection.get(device_token_uri(device_token))
    successful?(response) ? Yajl::Parser.parse(response.body) : nil
  end

  # Deletes a device token.
  #
  # @param [String] device_token
  # @return [Boolean] whether or not the deletion was successful
  def delete_device_token(device_token)
    response = @connection.delete(device_token_uri(device_token))
    successful?(response)
  end

  # Pushes a message.
  #
  # @param [Hash] payload the payload of the message
  # @return [Boolean] whether or not pushing the message was successful
  def push(payload)
    response = @connection.post(PUSH_URI, payload, JSON_HEADERS)
    logger.info("push response: #{response.inspect}") if logger
    successful?(response)
  end

  # Batch pushes multiple messages.
  #
  # @param [<Hash>] payload the payloads of each message
  # @return [Boolean] whether or not pushing the messages was successful
  def batch_push(*payload)
    response = @connection.post(BATCH_PUSH_URI, payload, JSON_HEADERS)
    successful?(response)
  end

  # Broadcasts a message.
  #
  # @param [Hash] payload the payload of the message
  # @return [Boolean] whether or not broadcasting the message was successful
  def broadcast(payload)
    response = @connection.post(BROADCAST_URI, payload, JSON_HEADERS)
    successful?(response)
  end

  # Retrieves feedback on device tokens.
  #
  # This is useful for removing inactive device tokens for the database.
  #
  # @param [Time] since the time to retrieve inactive tokens from
  # @return [Hash, nil]
  def feedback(since)
    response = @connection.get(feedback_uri(since))
    successful?(response) ? Yajl::Parser.parse(response.body) : nil
  end

  private

  def device_token_uri(device_token)
    clean_token = clean_token(device_token)
    if apple?(clean_token)
      "/api/device_tokens/#{clean_token}"
    else
      "/api/apids/#{clean_token}"
    end
  end

  def feedback_uri(since)
    "/api/device_tokens/feedback/?since=#{since.utc.iso8601}"
  end

  def successful?(response)
    SUCCESSFUL_STATUS_CODES.include?(response.status)
  end

  def apple?(clean_token)
    APPLE_REG_EXP.match(clean_token)
  end

  def clean_token(device_token)
    device_token.gsub(' ', '').upcase
  end
end

require 'zeppelin/version'
