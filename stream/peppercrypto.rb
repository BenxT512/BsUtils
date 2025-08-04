require_relative 'blake2b'
require_relative 'nonce'
require 'rbnacl'

class PepperCrypto
  def initialize
      @server_public_key = from_hex("KEY BRAWL STARS")
    @client_secret_key = RbNaCl::Random.random_bytes(32)
    @client_public_key = RbNaCl::PrivateKey.new(@client_secret_key).public_key.to_s
    
    box = RbNaCl::Box.new(
      RbNaCl::PublicKey.new(@server_public_key),
      RbNaCl::PrivateKey.new(@client_secret_key)
    )
    
    @key = box.beforenm
    @nonce = Nonce.new(keys: [@client_public_key, @server_public_key])
    @client_nonce = Nonce.new
  end

  def encrypt(type, payload)
    case type
    when 10100
      payload
    when 10101
      data = @session_key + @client_nonce.bytes + payload
      encrypted = RbNaCl::Box::Afternm.new(@key).encrypt(data, @nonce.bytes)
      @client_public_key.bytes + encrypted
    else
      @client_nonce.increment
      RbNaCl::Box::Afternm.new(@key).encrypt(payload, @client_nonce.bytes)
    end
  end

  def decrypt(type, payload)
    case type
    when 20100
      @session_key = payload[4, 24]
      payload
    when 20103, 20104
      return payload unless @session_key
      
      nonce = Nonce.new(
        nonce: @client_nonce.bytes,
        keys: [@client_public_key, @server_public_key]
      )
      
      decrypted = RbNaCl::Box::Afternm.new(@key).decrypt(payload, nonce.bytes)
      @server_nonce = Nonce.new(nonce: decrypted[0, 24])
      @key = decrypted[24, 32]
      decrypted[56..-1]
    else
      @server_nonce.increment
      RbNaCl::Box::Afternm.new(@key).decrypt(payload, @server_nonce.bytes)
    end
  end

  private

  def from_hex(hex)
    [hex].pack('H*')
  end
end
