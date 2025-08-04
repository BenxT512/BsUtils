require_relative '../stream/byte'

class FriendMessage
  def initialize
    @stream = ByteStream.new
  end

  def encode(high_id, low_id)
    @stream.write_int(high_id)
    @stream.write_int(low_id)
    @stream.write_int(3)
    @stream.write_int(1)
    @stream.get_bytes
  end
end
