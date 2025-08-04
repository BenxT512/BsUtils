module Blake2b
  module_function

  BLAKE2B_IV32 = [
    0xF3BCC908, 0x6A09E667, 0x84CAA73B, 0xBB67AE85,
    0xFE94F82B, 0x3C6EF372, 0x5F1D36F1, 0xA54FF53A,
    0xADE682D1, 0x510E527F, 0x2B3E6C1F, 0x9B05688C,
    0xFB41BD6B, 0x1F83D9AB, 0x137E2179, 0x5BE0CD19
  ].freeze

  SIGMA8 = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3,
    11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4,
    7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8,
    9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13,
    2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9,
    12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11,
    13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10,
    6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5,
    10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0
  ].freeze

  SIGMA82 = SIGMA8.map { |x| x * 2 }.freeze

  def add64aa(v, a, b)
    lo = v[a] + v[b]
    hi = v[a + 1] + v[b + 1]
    hi += 1 if lo >= 0x100000000
    v[a] = lo & 0xFFFFFFFF
    v[a + 1] = hi & 0xFFFFFFFF
  end

  def add64ac(v, a, b0, b1)
    lo = v[a] + b0
    lo += 0x100000000 if b0.negative?
    hi = v[a + 1] + b1
    hi += 1 if lo >= 0x100000000
    v[a] = lo & 0xFFFFFFFF
    v[a + 1] = hi & 0xFFFFFFFF
  end

  def b2b_get32(arr, i)
    arr[i] | (arr[i + 1] << 8) | (arr[i + 2] << 16) | (arr[i + 3] << 24)
  end

  def g(v, m, a, b, c, d, ix, iy)
    x0 = m[ix]
    x1 = m[ix + 1]
    y0 = m[iy]
    y1 = m[iy + 1]

    add64aa(v, a, b)
    add64ac(v, a, x0, x1)
    
    xor0 = v[d] ^ v[a]
    xor1 = v[d + 1] ^ v[a + 1]
    v[d] = xor1
    v[d + 1] = xor0

    add64aa(v, c, d)

    xor0 = v[b] ^ v[c]
    xor1 = v[b + 1] ^ v[c + 1]
    v[b] = ((xor0 >> 24) | (xor1 << 8)) & 0xFFFFFFFF
    v[b + 1] = ((xor1 >> 24) | (xor0 << 8)) & 0xFFFFFFFF

    add64aa(v, a, b)
    add64ac(v, a, y0, y1)

    xor0 = v[d] ^ v[a]
    xor1 = v[d + 1] ^ v[a + 1]
    v[d] = ((xor0 >> 16) | (xor1 << 16)) & 0xFFFFFFFF
    v[d + 1] = ((xor1 >> 16) | (xor0 << 16)) & 0xFFFFFFFF

    add64aa(v, c, d)

    xor0 = v[b] ^ v[c]
    xor1 = v[b + 1] ^ v[c + 1]
    v[b] = ((xor1 >> 31) | (xor0 << 1)) & 0xFFFFFFFF
    v[b + 1] = ((xor0 >> 31) | (xor1 << 1)) & 0xFFFFFFFF
  end
  def compress(ctx, last)
    v = Array.new(32, 0)
    m = Array.new(32, 0)

    16.times do |i|
      v[i] = ctx[:h][i]
      v[i + 16] = BLAKE2B_IV32[i]
    end

    v[24] ^= ctx[:t] & 0xFFFFFFFF
    v[25] ^= (ctx[:t] >> 32) & 0xFFFFFFFF

    if last
      v[28] = ~v[28] & 0xFFFFFFFF
      v[29] = ~v[29] & 0xFFFFFFFF
    end

    32.times do |i|
      m[i] = b2b_get32(ctx[:b], i * 4)
    end

    12.times do |i|
      sigma_offset = i * 16
      g(v, m, 0, 8, 16, 24, SIGMA82[sigma_offset], SIGMA82[sigma_offset + 1])
      g(v, m, 2, 10, 18, 26, SIGMA82[sigma_offset + 2], SIGMA82[sigma_offset + 3])
      g(v, m, 4, 12, 20, 28, SIGMA82[sigma_offset + 4], SIGMA82[sigma_offset + 5])
      g(v, m, 6, 14, 22, 30, SIGMA82[sigma_offset + 6], SIGMA82[sigma_offset + 7])
      g(v, m, 0, 10, 20, 30, SIGMA82[sigma_offset + 8], SIGMA82[sigma_offset + 9])
      g(v, m, 2, 12, 22, 24, SIGMA82[sigma_offset + 10], SIGMA82[sigma_offset + 11])
      g(v, m, 4, 14, 16, 26, SIGMA82[sigma_offset + 12], SIGMA82[sigma_offset + 13])
      g(v, m, 6, 8, 18, 28, SIGMA82[sigma_offset + 14], SIGMA82[sigma_offset + 15])
    end

    16.times do |i|
      ctx[:h][i] ^= v[i] ^ v[i + 16]
    end
  end

  def init(outlen, key = nil, salt = nil, personal = nil)
    raise "Invalid output length" if outlen.zero? || outlen > 64
    raise "Key too long" if key && key.size > 64
    raise "Salt must be 16 bytes" if salt && salt.size != 16
    raise "Personal must be 16 bytes" if personal && personal.size != 16

    param_block = [0] * 64
    param_block[0] = outlen
    param_block[1] = key ? key.size : 0
    param_block[2] = 1  # fanout
    param_block[3] = 1  # depth

    salt.each_with_index { |b, i| param_block[32 + i] = b } if salt
    personal.each_with_index { |b, i| param_block[48 + i] = b } if personal

    h = Array.new(16, 0)
    16.times do |i|
      word = param_block[i*4] | (param_block[i*4+1] << 8) | 
             (param_block[i*4+2] << 16) | (param_block[i*4+3] << 24)
      h[i] = BLAKE2B_IV32[i] ^ word
    end

    {
      b: [0] * 128,
      h: h,
      t: 0,
      c: 0,
      outlen: outlen
    }
  end

  def update(ctx, input)
    input.each do |byte|
      if ctx[:c] == 128
        ctx[:t] += 128
        compress(ctx, false)
        ctx[:c] = 0
      end
      ctx[:b][ctx[:c]] = byte
      ctx[:c] += 1
    end
  end

  def final(ctx)
    ctx[:t] += ctx[:c]
    while ctx[:c] < 128
      ctx[:b][ctx[:c]] = 0
      ctx[:c] += 1
    end
    compress(ctx, true)

    out = []
    ctx[:outlen].times do |i|
      out << (ctx[:h][i >> 2] >> (8 * (i & 3))) & 0xFF
    end
    out
  end

  def digest(input, outlen: 64, key: nil, salt: nil, personal: nil)
    input = normalize_input(input)
    key = normalize_input(key) if key
    salt = normalize_input(salt) if salt
    personal = normalize_input(personal) if personal

    ctx = init(outlen, key, salt, personal)
    update(ctx, input)
    final(ctx)
  end

  def hexdigest(input, **kwargs)
    digest(input, **kwargs).map { |b| b.to_s(16).rjust(2, '0') }.join
  end

  private

  def normalize_input(data)
    case data
    when String
      data.bytes
    when Array
      data
    else
      raise "Unsupported input type"
    end
  end
end
