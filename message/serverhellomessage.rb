require_relative '../stream/byte'

class ServerHelloMessage
  def initialize
    @stream = ByteStream.new
  end

  def decode(data)
    # idk
  end

  def process(messaging)
    messaging.send_pepper_login
  end
end
