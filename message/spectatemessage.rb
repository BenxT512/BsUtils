require_relative '../stream/byte'

class SpectateMessage
  def initialize
    @stream = ByteStream.new
  end

  def encode(high_id, low_id)
    @stream.write_int(high_id)
    @stream.write_int(low_id)
    @stream.write_byte(1)
    @stream.get_bytes
  end
end
