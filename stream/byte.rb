class ByteStream
  attr_accessor :offset
  attr_reader :payload

  def initialize(obj = [])
    @payload = obj.is_a?(Array) ? obj.dup : obj.bytes
    @offset = 0
  end

  def set(obj)
    @payload = obj.is_a?(Array) ? obj.dup : obj.bytes
    @offset = 0
  end

  def write(byte)
    @payload[@offset] = byte & 0xFF
    @offset += 1
  end

  def read
    return 0 if @offset >= @payload.size
    byte = @payload[@offset]
    @offset += 1
    byte
  end

  def write_uint(value)
    write(value)
  end

  def write_byte(byte)
    write(byte)
  end

  def write_boolean(value)
    write(value ? 1 : 0)
  end

  def write_int(value)
    write((value >> 24) & 0xFF)
    write((value >> 16) & 0xFF)
    write((value >> 8) & 0xFF)
    write(value & 0xFF)
  end

  def write_string(str)
    return write_int(-1) if str.nil? || str.empty?
    
    bytes = str.bytes
    write_int(bytes.length)
    bytes.each { |b| write(b) }
  end

  def write_vint(value)
    temp = (value >> 31) ^ (value << 1)
    return write_byte(0) if temp == 0

    v1 = ((value >> 25) & 0x40) | (value & 0x3F)
    v2 = (value ^ (value >> 31)) >> 6

    if v2 == 0
      write_byte(v1)
    else
      write_byte(v1 | 0x80)
      loop do
        bits = v2 & 0x7F
        v2 >>= 7
        write_byte(bits | (v2 > 0 ? 0x80 : 0))
        break if v2 == 0
      end
    end
  end

  def write_data_reference(a, b)
    write_vint(a)
    write_vint(b) if a != 0
  end

  def read_int
    (read << 24) | (read << 16) | (read << 8) | read
  end

  def read_byte
    read
  end

  def read_bytes(size)
    return [] if size <= 0
    @offset += size
    @payload[@offset - size, size]
  end

  def read_boolean
    read != 0
  end

  def read_string
    len = read_int
    return "" if len <= 0 || len == 0xFFFFFFFF
    read_bytes(len).pack('C*').force_encoding('UTF-8')
  end

  def read_vint
    result = 0
    shift = 0
    seventh = 0
    msb = 0
    n = 0

    loop do
      b = read
      if shift == 0
        seventh = (b & 0x40) >> 6
        msb = (b & 0x80) >> 7
        n = (b << 1) & ~0x181
        b = n | (msb << 7) | seventh
      end

      result |= (b & 0x7F) << shift
      shift += 7
      break if (b & 0x80) == 0
    end

    (result >> 1) ^ (-(result & 1))
  end

  def get_bytes
    @payload[0...@offset]
  end
end
