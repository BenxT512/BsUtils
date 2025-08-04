#!/usr/bin/env ruby
require 'socket'
require 'thread'
require_relative 'stream/byte'
require_relative 'message/messaging'

class GetID
  TAG_CHARS = '0289PYLQGRJCUV'

  def initialize(tag)
    @tag = tag
  end

  def call
    tag = @tag[1..-1] 
    id = 0
    
    tag.each_char do |char|
      index = TAG_CHARS.index(char)
      raise "Invalid character in tag: #{char}" unless index
      id *= TAG_CHARS.length
      id += index
    end
    
    high = id % 256
    low = (id - high) >> 8
    
    [high, low]
  end
end

class BrawlStarsClient
  def initialize(host, port, high_id, low_id, action)
    @host = host
    @port = port
    @high_id = high_id
    @low_id = low_id
    @action = action 
    @done = false
  end

  def done?
    @done
  end

  def run
    socket = TCPSocket.new(@host, @port)
    queue = []  
    messaging = Messaging.new(socket, queue, @high_id, @low_id, @action)
    messaging.send_pepper_authentication
    
    loop do
      ready = IO.select([socket], nil, nil, 0.1)
      if ready && ready[0].include?(socket)
        data = socket.recv(2048)
        break if data.empty?
        queue.concat(data.bytes)
      end
      
      # Process queue
      while !queue.empty? && messaging.pending_job?
        messaging.update
      end
      
      if messaging.done? || socket.closed?
        break
      end
    end
    
    socket.close
    @done = true
  rescue => e
    puts "Error in client: #{e.message}"
    socket.close if socket && !socket.closed?
  end
end

def show_help
  puts "Commands:"
  puts "  friend [tag] - Send 30 friend requests to player"
  puts "  spectate [tag] [count] - Send spectators to player (max 200)"
  puts "  friendstage [tag] - Send friend requests (stage server)"
  puts "  spectatestage [tag] [count] - Send spectators (stage server)"
  puts "  help - Show this help"
  puts "  credit - Show credits"
  puts "  exit - Exit the program"
end

def show_credit
  puts "Credits:"
  puts "  github.com/FMZNkdv - port on ruby"
end

def run_client(host, port, tag, action, count = 1)
  get_id = GetID.new(tag)
  high, low = get_id.call
  puts "Target: #{tag} | High ID: #{high} | Low ID: #{low}"

  count.times do
    client = BrawlStarsClient.new(host, port, high, low, action)
    Thread.new { client.run }
  end
end

puts "Brawl Stars Client CLI"
puts "Type 'help' for available commands"

loop do
  print "> "
  input = gets.chomp
  args = input.split(' ')
  command = args.shift.downcase

  case command
  when 'friend'
    tag = args[0]
    unless tag && tag.start_with?('#')
      puts "Invalid tag. Usage: friend #[tag]"
      next
    end
    
    run_client('game.brawlstarsgame.com', 9339, tag, :friend, 30)
    puts "Sent 30 friend requests to #{tag}"

  when 'spectate'
    tag = args[0]
    count = args[1]&.to_i
    
    unless tag && tag.start_with?('#') && count && count > 0 && count <= 200
      puts "Usage: spectate #[tag] [count] (count between 1 and 200)"
      next
    end
    
    run_client('game.brawlstarsgame.com', 9339, tag, :spectate, count)
    puts "Sent #{count} spectators to #{tag}"

  when 'friendstage'
    tag = args[0]
    unless tag && tag.start_with?('#')
      puts "Invalid tag. Usage: friendstage #[tag]"
      next
    end
    
    run_client('52.50.103.4', 9339, tag, :friend, 30)
    puts "Sent 30 friend requests (stage) to #{tag}"

  when 'spectatestage'
    tag = args[0]
    count = args[1]&.to_i
    
    unless tag && tag.start_with?('#') && count && count > 0 && count <= 200
      puts "Usage: spectatestage #[tag] [count] (count between 1 and 200)"
      next
    end
    
    run_client('52.50.103.4', 9339, tag, :spectate, count)
    puts "Sent #{count} spectators (stage) to #{tag}"

  when 'help'
    show_help

  when 'credit'
    show_credit

  when 'exit'
    break

  else
    puts "Unknown command. Type 'help' for available commands."
  end
end
