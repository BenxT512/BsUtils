require_relative '../stream/byte'

class NameMessage
  def initialize
    @stream = ByteStream.new
  end

  def encode
    @stream.write_string("fmznkdv >3")
    @stream.write_vint(1)
    @stream.get_bytes
  end
end
