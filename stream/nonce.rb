require_relative 'blake2b'

class Nonce
  def initialize(nonce: nil, keys: nil)
    if keys
      b2b = {
        b: [0] * 128,
        h: Array.new(16, 0),
        t: 0,
        c: 0,
        outlen: 24
      }
      
      Blake2b.update(b2b, nonce) if nonce
      keys.each { |key| Blake2b.update(b2b, key.bytes) }
      
      @nonce = Blake2b.final(b2b)
    elsif nonce
      @nonce = nonce
    else
      @nonce = Array.new(24) { rand(256) }
    end
  end

  def bytes
    @nonce.pack('C*').force_encoding('BINARY')
  end

  def increment
    num = @nonce[0] | (@nonce[1] << 8) | (@nonce[2] << 16) | (@nonce[3] << 24)
    num = (num + 2) & 0xFFFFFFFF
    @nonce[0] = num & 0xFF
    @nonce[1] = (num >> 8) & 0xFF
    @nonce[2] = (num >> 16) & 0xFF
    @nonce[3] = (num >> 24) & 0xFF
  end
end
