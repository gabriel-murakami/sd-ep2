require_relative 'client'

client = Client.new('localhost', 11001)
client.execute
