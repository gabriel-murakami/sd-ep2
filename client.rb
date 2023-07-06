require 'socket'
require 'json'
require 'redis'
require "active_support/core_ext/hash/indifferent_access"

# {
#   key_1: { value: 123, timestamp: '20103402' }
# }

class Client
  attr_reader :ip, :port, :redis_key, :redis

  def initialize(ip, port)
    @ip = ip
    @port = port
    @redis = Redis.new
    @redis_key = "client:#{ip}:#{port}"
  end

  def execute
    redis_put(initial_params)

    menu_thread = Thread.new { menu }
    listener_thread = Thread.new { listener }

    menu_thread.join
    listener_thread.join
  end

  def menu
    loop do
      puts "1) PUT\n2) GET\n"
      print 'Escolha uma ação: '
      op = gets.chomp.to_i

      case op
      when 1
      when 2
        print 'Insira a chave procurada: '
        key = gets.chomp

        send_message('localhost', sort_server, get_message(key))
      end
    end
  end

  def listener
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
    { default_client: { value: 'default_client', timestamp: current_timestamp } }
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

  def get_message(key)
    timestamp = parsed_redis[key] ? parsed_redis[key][:timestamp] : current_timestamp

    { code: 'GET', key: key, timestamp: timestamp, ip: ip, port: port }
  end

  def sort_server
    # [10097, 10098, 10099].sample
    [10097].sample
  end

  def handle_message(message)
    case message[:code]
    when 'PUT_OK'
      params = { message[:key] => { timestamp: message[:timestamp] } }

      redis_put(params, parsed_redis)
    when 'GET_OK'
      return puts "\nChave não encontrada" unless message[:value]

      puts "\n[GET_OK] #{message}"

      params = {
        message[:key] => {
          value: message[:value],
          timestamp:  message[:timestamp]
        }
      }

      redis_put(params, parsed_redis)
    end
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
