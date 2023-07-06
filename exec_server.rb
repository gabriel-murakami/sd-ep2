require_relative 'server'

server = Server.new('localhost', 10097)
server.start_server
