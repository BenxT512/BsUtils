require_relative 'clienthellomessage'
require_relative 'loginmessage'
require_relative 'friendmessage'
require_relative 'spectatemessage'
require_relative 'namemessage'
require_relative 'logiclasermessagefactory'
require_relative '../stream/peppercrypto'
require_relative '../stream/byte'

class Queue
  def initialize
    @data = []
  end

  def add(bytes)
    @data.concat(bytes)
  end

  def size
    @data.size
  end

  def read_uint_be(offset, length)
    value = 0
    length.times do |i|
      value = (value << 8) | @data[offset + i]
    end
    value
  end

  def shift(size)
    result = @data[0...size]
    @data = @data[size..-1] || []
    result
  end

  def reset
    @data = []
  end
end

class Messaging
  attr_reader :client, :queue, :crypto, :high_id, :low_id, :wws

  def initialize(client, queue, high_id, low_id, wws)
    @client = client
    @queue = queue
    @high_id = high_id
    @low_id = low_id
    @wws = wws  # 1 - friend, 2 - spectate
    @crypto = PepperCrypto.new
  end

  def pending_job?
    return false if @queue.size < 7
    length = @queue.read_uint_be(2, 3)
    @queue.size >= 7 + length
  end

  def update
    buffer = @queue.shift(7)
    type = (buffer[0] << 8) | buffer[1]
    length = @queue.read_uint_be(0, 3)
    version = (buffer[5] << 8) | buffer[6]
    
    data = @queue.shift(length)
    payload = @crypto.decrypt(type, data.pack('C*'))
    
    unless payload
      puts "Failed to decrypt message type: #{type}"
      return
    end
    
    payload_bytes = payload.bytes
    puts "Received message type: #{type}, length: #{length}, version: #{version}"
    
    message = LogicLaserMessageFactory.create_message_by_type(type, @wws)
    if message
      stream = ByteStream.new(payload_bytes)
      message.decode(stream) if message.respond_to?(:decode)
      message.process(self) if message.respond_to?(:process)
    else
      puts "Ignoring unsupported message: #{type}"
    end
  end

  def send_pepper_authentication
    message = ClientHelloMessage.new
    encrypt_and_write_to_socket(10100, 0, message.encode)
  end

  def send_pepper_login
    message = LoginMessage.new
    encrypt_and_write_to_socket(10101, 0, message.encode)
  end

  def send_friend
    message = FriendMessage.new
    encrypt_and_write_to_socket(10502, 0, message.encode(@high_id, @low_id))
  end

  def send_spectate
    message = SpectateMessage.new
    encrypt_and_write_to_socket(14104, 0, message.encode(@high_id, @low_id))
  end

  def send_set_name
    message = NameMessage.new
    encrypt_and_write_to_socket(10212, 0, message.encode)
  end

  private

  def encrypt_and_write_to_socket(type, version, data)
    encrypted = @crypto.encrypt(type, data.pack('C*')).unpack('C*')
    length = encrypted.size
    
    header = [
      (type >> 8) & 0xFF,
      type & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
      (version >> 8) & 0xFF,
      version & 0xFF
    ]
    
    packet = header + encrypted
    @client.write(packet.pack('C*'))
    puts "Sent message type: #{type}, length: #{length}"
  end
end
