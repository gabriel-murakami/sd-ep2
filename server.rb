require 'socket'
require 'json'
require 'redis'
require "active_support/core_ext/hash/indifferent_access"

class Server
  attr_reader :ip, :port, :redis_key, :redis

  def initialize(ip, port)
    @ip = ip
    @port = port
    @redis = Redis.new
    @redis_key = "server:#{ip}:#{port}"
  end

  def start_server
    redis_put(initial_params)

    puts "[START SERVER] URL: #{ip}:#{port}"

    server = TCPServer.open(ip, port)

    loop do
      t = Thread.new do
        client = server.accept
        handle_message(parse_message(client.gets))
        client.close
      end

      t.join
    end
  end

  private

  def initial_params
    { default_server: { value: 'default_server', timestamp: current_timestamp } }
  end

  def parsed_redis
    JSON.parse(redis.get(redis_key)).with_indifferent_access
  end

  def redis_put(params, hash = {})
    params.each do |k1, v1|
      hash[k1] = v1 if hash[k1].nil?

      v1.each do |k2, v2|
        hash[k1][k2] = v2
      end
    end

    redis.set(redis_key, hash.to_json)
  end

  def current_timestamp
    Time.now.strftime("%H%M%S%L")
  end

  def handle_message(message)
    case message[:code]
    when 'PUT'
    when 'GET'
      puts "[GET] #{message.inspect}"

      c_ip, c_port = [message[:ip], message[:port]]

      send_message(c_ip, c_port, get_response_message(message))
    end
  end

  def get_response_message(message)
    return { code: 'GET_OK', value: nil } unless parsed_redis[message[:key]]

    registry = parsed_redis[message[:key]]

    { code: 'GET_OK', key: message[:key], value: registry[:value], timestamp: registry[:timestamp] }
  end

  def parse_message(message)
    JSON.parse(message, symbolize_names: true)
  end

  def send_message(ip, port, message)
    socket = TCPSocket.open(ip, port)
    socket.write(message.to_json)
    socket.close
  end
end
