require_relative '../stream/byte'

class OwnHomeDataMessage
  def initialize
    @stream = ByteStream.new
  end

  def decode(data)
    # idk
  end

  def process(messaging)
    messaging.send_set_name
  end
end
