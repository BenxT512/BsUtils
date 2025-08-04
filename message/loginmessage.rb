require_relative '../stream/byte'

class LoginMessage
  def initialize
    @stream = ByteStream.new
  end

  def encode
    @stream.write_int(0) # high
    @stream.write_int(0) # low
    @stream.write_string("") # token

    @stream.write_int(46)
    @stream.write_int(1)
    @stream.write_int(209)
    @stream.write_string("e13eb3b80ac96ef51c3baa7eb25064aadfe00fed")

    @stream.write_string("")
    @stream.write_data_reference(1, 0)
    @stream.write_string("en-US")
    @stream.write_string("")
    @stream.write_boolean(false)
    @stream.write_string("3")
    @stream.write_string("2")
    @stream.write_boolean(true)
    @stream.write_string("3")
    @stream.write_int(1448)
    @stream.write_vint(0)
    @stream.write_string("3")

    @stream.write_string("")
    @stream.write_string("3")
    @stream.write_vint(0)

    @stream.write_string("3")
    @stream.write_string("3")
    @stream.write_string("3")

    @stream.write_string("3S")

    @stream.write_boolean(false)
    @stream.write_string("3")
    @stream.write_string("3")
    
    @stream.get_bytes
  end
end
