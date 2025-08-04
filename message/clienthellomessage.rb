require_relative '../stream/byte'

class ClientHelloMessage
  def initialize
    @stream = ByteStream.new
  end

  def encode
    @stream.write_int(2)
    @stream.write_int(34)
    @stream.write_int(46)
    @stream.write_int(1)
    @stream.write_int(209)
    @stream.write_string("e13eb3b80ac96ef51c3baa7eb25064aadfe00fed")
    @stream.write_int(0)
    @stream.write_int(0)
    @stream.get_bytes
  end
end
