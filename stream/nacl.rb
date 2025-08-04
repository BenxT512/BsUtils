module NaCl
  module LowLevel
    extend self

    SIGMA = [101, 120, 112, 97, 110, 100, 32, 51, 50, 45, 98, 121, 116, 101, 32, 107].pack('C*').freeze
    IV = [
      0x6a,0x09,0xe6,0x67,0xf3,0xbc,0xc9,0x08,0xbb,0x67,0xae,0x85,0x84,0xca,0xa7,0x3b,
      0x3c,0x6e,0xf3,0x72,0xfe,0x94,0xf8,0x2b,0xa5,0x4f,0xf5,0x3a,0x5f,0x1d,0x36,0xf1,
      0x51,0x0e,0x52,0x7f,0xad,0xe6,0x82,0xd1,0x9b,0x05,0x68,0x8c,0x2b,0x3e,0x6c,0x1f,
      0x1f,0x83,0xd9,0xab,0xfb,0x41,0xbd,0x6b,0x5b,0xe0,0xcd,0x19,0x13,0x7e,0x21,0x79
    ].pack('C*').freeze

    SECRETBOX_KEYBYTES = 32
    SECRETBOX_NONCEBYTES = 24
    SECRETBOX_ZEROBYTES = 32
    SECRETBOX_BOXZEROBYTES = 16
    SCALARMULT_BYTES = 32
    SCALARMULT_SCALARBYTES = 32
    BOX_PUBLICKEYBYTES = 32
    BOX_SECRETKEYBYTES = 32
    BOX_BEFORENMBYTES = 32
    BOX_NONCEBYTES = SECRETBOX_NONCEBYTES
    BOX_ZEROBYTES = SECRETBOX_ZEROBYTES
    BOX_BOXZEROBYTES = SECRETBOX_BOXZEROBYTES
    SIGN_BYTES = 64
    SIGN_PUBLICKEYBYTES = 32
    SIGN_SECRETKEYBYTES = 64
    SIGN_SEEDBYTES = 32
    HASH_BYTES = 64

    GF_LEN = 16
    D = [
      0x78a3, 0x1359, 0x4dca, 0x75eb, 0xd8ab, 0x4141, 0x0a4d, 0x0070,
      0xe898, 0x7779, 0x4079, 0x8cc7, 0xfe73, 0x2b6f, 0x6cee, 0x5203
    ]
    D2 = [
      0xf159, 0x26b2, 0x9b94, 0xebd6, 0xb156, 0x8283, 0x149a, 0x00e0,
      0xd130, 0xeef3, 0x80f2, 0x198e, 0xfce7, 0x56df, 0xd9dc, 0x2406
    ]
    XI = [
      0xd51a, 0x8f25, 0x2d60, 0xc956, 0xa7b2, 0x9525, 0xc760, 0x692c,
      0xdc5c, 0xfdd6, 0xe231, 0xc0a4, 0x53fe, 0xcd6e, 0x36d3, 0x2169
    ]
    MINUSP = [5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,252]
    L = [0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10]

    def gf(init = nil)
      Array.new(GF_LEN, 0).tap do |r|
        init.each_with_index { |v, i| r[i] = v } if init
      end
    end

    def rotate32(x, c)
      ((x << c) | (x >> (32 - c))) & 0xFFFFFFFF
    end

    def ld32(bytes, offset)
      bytes = bytes.bytes if bytes.is_a?(String)
      bytes[offset] | (bytes[offset+1] << 8) | (bytes[offset+2] << 16) | (bytes[offset+3] << 24)
    end

    def st32(bytes, offset, value)
      bytes[offset] = value & 0xFF
      bytes[offset+1] = (value >> 8) & 0xFF
      bytes[offset+2] = (value >> 16) & 0xFF
      bytes[offset+3] = (value >> 24) & 0xFF
    end

    def dl64(bytes, offset)
      hi = bytes[offset] | (bytes[offset+1] << 8) | (bytes[offset+2] << 16) | (bytes[offset+3] << 24)
      lo = bytes[offset+4] | (bytes[offset+5] << 8) | (bytes[offset+6] << 16) | (bytes[offset+7] << 24)
      [hi, lo]
    end

    def ts64(bytes, offset, hi, lo)
      bytes[offset] = hi & 0xFF
      bytes[offset+1] = (hi >> 8) & 0xFF
      bytes[offset+2] = (hi >> 16) & 0xFF
      bytes[offset+3] = (hi >> 24) & 0xFF
      bytes[offset+4] = lo & 0xFF
      bytes[offset+5] = (lo >> 8) & 0xFF
      bytes[offset+6] = (lo >> 16) & 0xFF
      bytes[offset+7] = (lo >> 24) & 0xFF
    end

    def vn(a, a_offset, b, b_offset, n)
      d = 0
      n.times { |i| d |= a[a_offset+i] ^ b[b_offset+i] }
      (1 & ((d - 1) >> 8)) - 1
    end

    def crypto_verify_16(x, x_offset, y, y_offset)
      vn(x, x_offset, y, y_offset, 16)
    end

    def crypto_verify_32(x, x_offset, y, y_offset)
      vn(x, x_offset, y, y_offset, 32)
    end

    def core_salsa20(o, inp, k, c)
      w = Array.new(16, 0)
      x = Array.new(16, 0)
      4.times do |i|
        x[4*i] = ld32(c, 4*i)
        x[1+i] = ld32(k, 4*i)
        x[6+i] = ld32(inp, 4*i)
        x[11+i] = ld32(k, 16+4*i)
      end
      y = x.dup
      20.times do |i|
        4.times do |j|
          4.times { |m| w[4*j + ((j+m) % 4)] = rotate32((x[(4*j+4*m) % 16] + x[(4*j+4*m+1) % 16]) & 0xFFFFFFFF, [7,9,13,18][m])
        end
        x = w.dup
      end
      16.times { |i| st32(o, 4*i, (x[i] + y[i]) & 0xFFFFFFFF) }
    end

    def core_hsalsa20(o, inp, k, c)
      w = Array.new(16, 0)
      x = Array.new(16, 0)
      4.times do |i|
        x[5*i] = ld32(c, 4*i)
        x[1+i] = ld32(k, 4*i)
        x[6+i] = ld32(inp, 4*i)
        x[11+i] = ld32(k, 16+4*i)
      end
      y = x.dup
      20.times do |i|
        4.times do |j|
          4.times { |m| w[4*j + ((j+m) % 4)] = rotate32((x[(4*j+4*m) % 16] + x[(4*j+4*m+1) % 16]) & 0xFFFFFFFF, [7,9,13,18][m])
        end
        x = w.dup
      end
      [x[0], x[5], x[10], x[15], x[6], x[7], x[8], x[9]].each_with_index do |v, i|
        st32(o, 4*i, v)
      end
    end

    def crypto_stream_salsa20_xor(c, cpos, m, mpos, b, n, k)
      z = Array.new(16, 0)
      8.times { |i| z[i] = n[i] }
      while b >= 64
        x = Array.new(64, 0)
        core_salsa20(x, z, k, SIGMA.bytes)
        if m
          64.times { |i| c[cpos+i] = m[mpos+i] ^ x[i] }
          mpos += 64
        else
          64.times { |i| c[cpos+i] = x[i] }
        end
        u = 1
        8.upto(15) do |i|
          u += z[i]
          z[i] = u & 0xFF
          u >>= 8
        end
        b -= 64
        cpos += 64
      end
      if b > 0
        x = Array.new(64, 0)
        core_salsa20(x, z, k, SIGMA.bytes)
        b.times do |i|
          if m
            c[cpos+i] = m[mpos+i] ^ x[i]
          else
            c[cpos+i] = x[i]
          end
        end
      end
      0
    end

    def crypto_stream_salsa20(c, cpos, d, n, k)
      crypto_stream_salsa20_xor(c, cpos, nil, 0, d, n, k)
    end

    def crypto_stream_xor(c, cpos, m, mpos, d, n, k)
      s = Array.new(32, 0)
      core_hsalsa20(s, n, k, SIGMA.bytes)
      crypto_stream_salsa20_xor(c, cpos, m, mpos, d, n[16..-1], s)
    end

    def crypto_stream(c, cpos, d, n, k)
      crypto_stream_xor(c, cpos, nil, 0, d, n, k)
    end

    def add1305(h, c)
      u = 0
      GF_LEN.times do |j|
        u += h[j] + c[j]
        h[j] = u & 0xFF
        u >>= 8
      end
    end

    def crypto_onetimeauth(out, outpos, m, mpos, n, k)
      r = Array.new(GF_LEN, 0)
      h = Array.new(GF_LEN, 0)
      c = Array.new(GF_LEN, 0)
      GF_LEN.times { |j| r[j] = k[j] }
      r[3] &= 15
      r[4] &= 252
      r[7] &= 15
      r[8] &= 252
      r[11] &= 15
      r[12] &= 252
      r[15] &= 15
      while n > 0
        GF_LEN.times { |j| c[j] = 0 }
        len = [GF_LEN, n].min
        len.times { |j| c[j] = m[mpos+j] }
        c[len] = 1
        mpos += len
        n -= len
        add1305(h, c)
        t = Array.new(17, 0)
        17.times do |j|
          t[j] = 0
          GF_LEN.times do |i|
            if j <= i
              t[j] += h[i] * r[i - j]
            else
              t[j] += h[i] * (320 * r[i + 17 - j])
            end
          end
        end
        GF_LEN.times { |i| h[i] = t[i] }
        u = 0
        (GF_LEN - 1).times do |j|
          u += h[j]
          h[j] = u & 0xFF
          u >>= 8
        end
        u += h[GF_LEN - 1]
        h[GF_LEN - 1] = u & 3
        u = (u >> 2) * 5
        (GF_LEN - 1).times do |j|
          u += h[j]
          h[j] = u & 0xFF
          u >>= 8
        end
        u += h[GF_LEN - 1]
        h[GF_LEN - 1] = u
      end
      g = h.dup
      add1305(h, MINUSP)
      s = (-(h[GF_LEN] >> 7)) & 0xFF
      GF_LEN.times { |i| h[i] ^= s & (g[i] ^ h[i]) }
      GF_LEN.times { |i| c[i] = k[GF_LEN + i] }
      c[GF_LEN] = 0
      add1305(h, c)
      GF_LEN.times { |i| out[outpos+i] = h[i] }
      0
    end

    def crypto_onetimeauth_verify(h, hpos, m, mpos, n, k)
      x = Array.new(GF_LEN, 0)
      crypto_onetimeauth(x, 0, m, mpos, n, k)
      crypto_verify_16(h, hpos, x, 0)
    end

    def crypto_secretbox(c, m, d, n, k)
      return -1 if d < 32
      crypto_stream_xor(c, 0, m, 0, d, n, k)
      crypto_onetimeauth(c, 16, c, 32, d - 32, c)
      16.times { |i| c[i] = 0 }
      0
    end

    def crypto_secretbox_open(m, c, d, n, k)
      return -1 if d < 32
      x = Array.new(32, 0)
      crypto_stream(x, 0, 32, n, k)
      return -1 if crypto_onetimeauth_verify(c, 16, c, 32, d - 32, x) != 0
      crypto_stream_xor(m, 0, c, 0, d, n, k)
      32.times { |i| m[i] = 0 }
      0
    end

    def set25519(r, a)
      GF_LEN.times { |i| r[i] = a[i] }
    end

    def car25519(o)
      c = 0
      GF_LEN.times do |i|
        o[i] += 65536
        c = o[i] >> 16
        o[(i+1)*(i < GF_LEN-1 ? 1 : 0)] += c - 1 + 37 * (c - 1) * (i == GF_LEN-1 ? 1 : 0)
        o[i] -= c << 16
      end
    end

    def sel25519(p, q, b)
      c = ~(b - 1)
      GF_LEN.times do |i|
        t = c & (p[i] ^ q[i])
        p[i] ^= t
        q[i] ^= t
      end
    end

    def pack25519(o, n)
      m = gf
      t = gf
      GF_LEN.times { |i| t[i] = n[i] }
      car25519(t)
      car25519(t)
      car25519(t)
      2.times do
        m[0] = t[0] - 0xffed
        (GF_LEN-1).times do |i|
          m[i+1] = t[i+1] - 0xffff - ((m[i] >> 16) & 1)
          m[i] &= 0xffff
        end
        m[GF_LEN-1] = t[GF_LEN-1] - 0x7fff - ((m[GF_LEN-2] >> 16) & 1)
        m[GF_LEN-2] &= 0xffff
        b = (m[GF_LEN-1] >> 16) & 1
        sel25519(t, m, 1 - b)
      end
      GF_LEN.times do |i|
        o[2*i] = t[i] & 0xff
        o[2*i+1] = t[i] >> 8
      end
    end

    def neq25519(a, b)
      c = Array.new(32, 0)
      d = Array.new(32, 0)
      pack25519(c, a)
      pack25519(d, b)
      crypto_verify_32(c, 0, d, 0)
    end

    def par25519(a)
      d = Array.new(32, 0)
      pack25519(d, a)
      d[0] & 1
    end

    def unpack25519(o, n)
      GF_LEN.times { |i| o[i] = n[2*i] + (n[2*i+1] << 8) }
      o[GF_LEN-1] &= 0x7fff
    end

    def A(o, a, b)
      GF_LEN.times { |i| o[i] = a[i] + b[i] }
    end

    def Z(o, a, b)
      GF_LEN.times { |i| o[i] = a[i] - b[i] }
    end

    def M(o, a, b)
      t = Array.new(31, 0)
      GF_LEN.times do |i|
        GF_LEN.times do |j|
          t[i+j] += a[i] * b[j]
        end
      end
      (GF_LEN-1).times do |i|
        t[i] += 38 * t[i+GF_LEN]
      end
      GF_LEN.times { |i| o[i] = t[i] }
      car25519(o)
      car25519(o)
    end

    def S(o, a)
      M(o, a, a)
    end

    def inv25519(o, i)
      c = gf
      GF_LEN.times { |a| c[a] = i[a] }
      (253).downto(0) do |a|
        S(c, c)
        M(c, c, i) if a != 2 && a != 4
      end
      GF_LEN.times { |a| o[a] = c[a] }
    end

    def pow2523(o, i)
      c = gf
      GF_LEN.times { |a| c[a] = i[a] }
      (250).downto(0) do |a|
        S(c, c)
        M(c, c, i) if a != 1
      end
      GF_LEN.times { |a| o[a] = c[a] }
    end

    def crypto_scalarmult(q, n, p)
      z = Array.new(32, 0)
      x = Array.new(80, 0)
      GF_LEN.times { |i| z[i] = n[i] }
      z[31] = (n[31] & 127) | 64
      z[0] &= 248
      unpack25519(x, p)
      a = gf
      b = gf([1])
      c = gf
      d = gf
      GF_LEN.times { |i| d[i] = a[i] = c[i] = 0 }
      a[0] = d[0] = 1
      254.downto(0) do |i|
        r = (z[i>>3] >> (i & 7)) & 1
        sel25519(a, b, r)
        sel25519(c, d, r)
        e = gf
        A(e, a, c)
        Z(a, a, c)
        c = gf
        A(c, b, d)
        Z(b, b, d)
        s = gf
        S(s, e)
        t = gf
        S(t, a)
        a = gf
        M(a, c, a)
        c = gf
        M(c, b, e)
        e = gf
        A(e, a, c)
        Z(a, a, c)
        s2 = gf
        S(s2, a)
        c = gf
        Z(c, d, t)
        a = gf
        M(a, c, _121665)
        A(a, a, d)
        c = gf
        M(c, c, a)
        a = gf
        M(a, d, t)
        d = gf
        M(d, b, x)
        s3 = gf
        S(s3, e)
        sel25519(a, b, r)
        sel25519(c, d, r)
      end
      inv25519(c, c)
      M(a, a, c)
      pack25519(q, a)
      0
    end

    def crypto_scalarmult_base(q, n)
      crypto_scalarmult(q, n, [
        9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      ])
    end

    def crypto_box_keypair(y, x)
      randombytes(x, 32)
      crypto_scalarmult_base(y, x)
    end

    def crypto_box_beforenm(k, y, x)
      s = Array.new(32, 0)
      crypto_scalarmult(s, x, y)
      core_hsalsa20(k, [0]*16, s, SIGMA.bytes)
    end

    def crypto_box_afternm(c, m, d, n, k)
      crypto_secretbox(c, m, d, n, k)
    end

    def crypto_box_open_afternm(m, c, d, n, k)
      crypto_secretbox_open(m, c, d, n, k)
    end

    def crypto_box(c, m, d, n, y, x)
      k = Array.new(32, 0)
      crypto_box_beforenm(k, y, x)
      crypto_box_afternm(c, m, d, n, k)
    end

    def crypto_box_open(m, c, d, n, y, x)
      k = Array.new(32, 0)
      crypto_box_beforenm(k, y, x)
      crypto_box_open_afternm(m, c, d, n, k)
    end

    def add64(a, b)
      m16 = 65535
      al = a & m16
      ah = a >> 16
      bl = b & m16
      bh = b >> 16
      l = al + bl
      h = ah + bh + (l >> 16)
      [h & m16, l & m16]
    end

    def shr64(x, c)
      if c < 32
        h = (x >> c) & 0xFFFFFFFF
        l = (x << (32 - c)) & 0xFFFFFFFF
      else
        h = 0
        l = (x >> (c - 32)) & 0xFFFFFFFF
      end
      [h, l]
    end

    def xor64(a, b)
      [a[0] ^ b[0], a[1] ^ b[1]]
    end

    def R(x, c)
      if c < 32
        h = (x[0] >> c) | (x[1] << (32 - c))
        l = (x[1] >> c) | (x[0] << (32 - c))
      else
        h = (x[1] >> (c - 32)) | (x[0] << (64 - c))
        l = (x[0] >> (c - 32)) | (x[1] << (64 - c))
      end
      [h & 0xFFFFFFFF, l & 0xFFFFFFFF]
    end

    def Ch(x, y, z)
      h = (x[0] & y[0]) ^ (~x[0] & z[0])
      l = (x[1] & y[1]) ^ (~x[1] & z[1])
      [h & 0xFFFFFFFF, l & 0xFFFFFFFF]
    end

    def Maj(x, y, z)
      h = (x[0] & y[0]) ^ (x[0] & z[0]) ^ (y[0] & z[0])
      l = (x[1] & y[1]) ^ (x[1] & z[1]) ^ (y[1] & z[1])
      [h & 0xFFFFFFFF, l & 0xFFFFFFFF]
    end

    def Sigma0(x)
      xor64(R(x, 28), R(x, 34), R(x, 39))
    end

    def Sigma1(x)
      xor64(R(x, 14), R(x, 18), R(x, 41))
    end

    def sigma0(x)
      xor64(R(x, 1), R(x, 8), shr64(x, 7))
    end

    def sigma1(x)
      xor64(R(x, 19), R(x, 61), shr64(x, 6))
    end

    K = [
      [0x428a2f98, 0xd728ae22], [0x71374491, 0x23ef65cd], [0xb5c0fbcf, 0xec4d3b2f], [0xe9b5dba5, 0x8189dbbc],
      [0x3956c25b, 0xf348b538], [0x59f111f1, 0xb605d019], [0x923f82a4, 0xaf194f9b], [0xab1c5ed5, 0xda6d8118],
      [0xd807aa98, 0xa3030242], [0x12835b01, 0x45706fbe], [0x243185be, 0x4ee4b28c], [0x550c7dc3, 0xd5ffb4e2],
      [0x72be5d74, 0xf27b896f], [0x80deb1fe, 0x3b1696b1], [0x9bdc06a7, 0x25c71235], [0xc19bf174, 0xcf692694],
      [0xe49b69c1, 0x9ef14ad2], [0xefbe4786, 0x384f25e3], [0x0fc19dc6, 0x8b8cd5b5], [0x240ca1cc, 0x77ac9c65],
      [0x2de92c6f, 0x592b0275], [0x4a7484aa, 0x6ea6e483], [0x5cb0a9dc, 0xbd41fbd4], [0x76f988da, 0x831153b5],
      [0x983e5152, 0xee66dfab], [0xa831c66d, 0x2db43210], [0xb00327c8, 0x98fb213f], [0xbf597fc7, 0xbeef0ee4],
      [0xc6e00bf3, 0x3da88fc2], [0xd5a79147, 0x930aa725], [0x06ca6351, 0xe003826f], [0x14292967, 0x0a0e6e70],
      [0x27b70a85, 0x46d22ffc], [0x2e1b2138, 0x5c26c926], [0x4d2c6dfc, 0x5ac42aed], [0x53380d13, 0x9d95b3df],
      [0x650a7354, 0x8baf63de], [0x766a0abb, 0x3c77b2a8], [0x81c2c92e, 0x47edaee6], [0x92722c85, 0x1482353b],
      [0xa2bfe8a1, 0x4cf10364], [0xa81a664b, 0xbc423001], [0xc24b8b70, 0xd0f89791], [0xc76c51a3, 0x0654be30],
      [0xd192e819, 0xd6ef5218], [0xd6990624, 0x5565a910], [0xf40e3585, 0x5771202a], [0x106aa070, 0x32bbd1b8],
      [0x19a4c116, 0xb8d2d0c8], [0x1e376c08, 0x5141ab53], [0x2748774c, 0xdf8eeb99], [0x34b0bcb5, 0xe19b48a8],
      [0x391c0cb3, 0xc5c95a63], [0x4ed8aa4a, 0xe3418acb], [0x5b9cca4f, 0x7763e373], [0x682e6ff3, 0xd6b2b8a3],
      [0x748f82ee, 0x5defb2fc], [0x78a5636f, 0x43172f60], [0x84c87814, 0xa1f0ab72], [0x8cc70208, 0x1a6439ec],
      [0x90befffa, 0x23631e28], [0xa4506ceb, 0xde82bde9], [0xbef9a3f7, 0xb2c67915], [0xc67178f2, 0xe372532b]
    ]

    def crypto_hashblocks(x, m, n)
      z = Array.new(8) { |i| dl64(x, 8*i) }
      b = Array.new(8) { [0, 0] }
      a = z.dup
      w = Array.new(16) { |i| dl64(m, 8*i) }
      pos = 0
      while n >= 128
        16.times { |i| w[i] = dl64(m, pos + 8*i) }
        80.times do |i|
          8.times { |j| b[j] = a[j] }
          t = add64(a[7][0], a[7][1], Sigma1(a[4])[0], Sigma1(a[4])[1], Ch(a[4], a[5], a[6])[0], Ch(a[4], a[5], a[6])[1], K[i][0], K[i][1], w[i % 16][0], w[i % 16][1])
          b[7] = add64(t[0], t[1], Sigma0(a[0])[0], Sigma0(a[0])[1], Maj(a[0], a[1], a[2])[0], Maj(a[0], a[1], a[2])[1])
          b[3] = add64(b[3][0], b[3][1], t[0], t[1])
          8.times { |j| a[(j+1) % 8] = b[j] }
          if i % 16 == 15
            16.times do |j|
              w[j] = add64(w[j][0], w[j][1], w[(j+9) % 16][0], w[(j+9) % 16][1], sigma0(w[(j+1) % 16])[0], sigma0(w[(j+1) % 16])[1], sigma1(w[(j+14) % 16])[0], sigma1(w[(j+14) % 16])[1])
            end
          end
        end
        8.times { |i| a[i] = add64(a[i][0], a[i][1], z[i][0], z[i][1]); z[i] = a[i] }
        pos += 128
        n -= 128
      end
      8.times { |i| ts64(x, 8*i, z[i][0], z[i][1]) }
      n
    end

    def crypto_hash(out, m, n)
      h = IV.bytes.dup
      x = Array.new(256, 0)
      b = n
      crypto_hashblocks(h, m, n)
      n %= 128
      m = m[b - n..-1] if b - n > 0
      n.times { |i| x[i] = m[i] }
      x[n] = 128
      n = 256 - 128 * (n < 112 ? 1 : 0)
      x[n - 9] = 0
      ts64(x, n - 8, (b >> 29) & 0xFFFFFFFF, (b << 3) & 0xFFFFFFFF)
      crypto_hashblocks(h, x, n)
      64.times { |i| out[i] = h[i] }
      0
    end

    def add(p, q)
      a = gf; b = gf; c = gf; d = gf; e = gf; f = gf; g = gf; h = gf; t = gf
      Z(a, p[1], p[0])
      Z(t, q[1], q[0])
      M(a, a, t)
      A(b, p[0], p[1])
      A(t, q[0], q[1])
      M(b, b, t)
      M(c, p[3], q[3])
      M(c, c, D2)
      M(d, p[2], q[2])
      A(d, d, d)
      Z(e, b, a)
      Z(f, d, c)
      A(g, d, c)
      A(h, b, a)
      M(p[0], e, f)
      M(p[1], h, g)
      M(p[2], g, f)
      M(p[3], e, h)
    end

    def cswap(p, q, b)
      4.times { |i| sel25519(p[i], q[i], b) }
    end

    def pack(r, p)
      tx = gf; ty = gf; zi = gf
      inv25519(zi, p[2])
      M(tx, p[0], zi)
      M(ty, p[1], zi)
      pack25519(r, ty)
      r[31] ^= par25519(tx) << 7
    end

    def scalarmult(p, q, s)
      set25519(p[0], gf0)
      set25519(p[1], gf1)
      set25519(p[2], gf1)
      set25519(p[3], gf0)
      255.downto(0) do |i|
        b = (s[i>>3] >> (i & 7)) & 1
        cswap(p, q, b)
        add(q, p)
        add(p, p)
        cswap(p, q, b)
      end
    end

    def scalarbase(p, s)
      q = [gf, gf, gf, gf]
      set25519(q[0], XI)
      set25519(q[1], gf1)
      M(q[3], XI, q[1])
      scalarmult(p, q, s)
    end

    def crypto_sign_keypair(pk, sk, seeded = false)
      d = Array.new(64, 0)
      p = [gf, gf, gf, gf]
      randombytes(sk, 32) unless seeded
      crypto_hash(d, sk, 32)
      d[0] &= 248
      d[31] &= 127
      d[31] |= 64
      scalarbase(p, d)
      pack(pk, p)
      32.times { |i| sk[32+i] = pk[i] }
      0
    end

    def modL(r, x)
      carry = 0
      (63).downto(32) do |i|
        carry = 0
        (i-32).upto(i-12-1) do |j|
          x[j] += carry - 16 * x[i] * L[j - (i - 32)]
          carry = (x[j] + 128) >> 8
          x[j] -= carry << 8
        end
        x[j] += carry
        x[i] = 0
      end
      carry = 0
      32.times do |j|
        x[j] += carry - (x[31] >> 4) * L[j]
        carry = x[j] >> 8
        x[j] &= 255
      end
      32.times { |j| x[j] -= carry * L[j] }
      32.times do |i|
        x[i+1] += x[i] >> 8
        r[i] = x[i] & 255
      end
    end

    def crypto_sign(sm, m, n, sk)
      d = Array.new(64, 0)
      h = Array.new(64, 0)
      r = Array.new(64, 0)
      x = Array.new(64, 0)
      p = [gf, gf, gf, gf]
      crypto_hash(d, sk, 32)
      d[0] &= 248
      d[31] &= 127
      d[31] |= 64
      smlen = n + 64
      n.times { |i| sm[64+i] = m[i] }
      32.times { |i| sm[32+i] = d[32+i] }
      crypto_hash(r, sm[32..-1], n+32)
      reduce(r)
      scalarbase(p, r)
      pack(sm, p)
      32.times { |i| sm[i+32] = sk[i+32] }
      crypto_hash(h, sm, n+64)
      reduce(h)
      64.times { |i| x[i] = 0 }
      32.times { |i| x[i] = r[i] }
      32.times do |i|
        32.times do |j|
          x[i+j] += h[i] * d[j]
        end
      end
      modL(sm[32..-1], x)
      smlen
    end

    def unpackneg(r, p)
      t = gf; chk = gf; num = gf; den = gf; den2 = gf; den4 = gf; den6 = gf
      set25519(r[2], gf1)
      unpack25519(r[1], p)
      S(num, r[1])
      M(den, num, D)
      Z(num, num, r[2])
      A(den, r[2], den)
      S(den2, den)
      S(den4, den2)
      M(den6, den4, den2)
      M(t, den6, num)
      M(t, t, den)
      pow2523(t, t)
      M(t, t, num)
      M(t, t, den)
      M(t, t, den)
      M(r[0], t, den)
      S(chk, r[0])
      M(chk, chk, den)
      return -1 if neq25519(chk, num) != 0
      S(chk, r[0])
      M(chk, chk, den)
      return -1 if neq25519(chk, num) != 0
      Z(r[0], gf0, r[0]) if par25519(r[0]) == (p[31] >> 7)
      M(r[3], r[0], r[1])
      0
    end

    def crypto_sign_open(m, sm, n, pk)
      return -1 if n < 64
      t = Array.new(32, 0)
      h = Array.new(64, 0)
      p = [gf, gf, gf, gf]
      q = [gf, gf, gf, gf]
      n.times { |i| m[i] = sm[i] }
      32.times { |i| m[i+32] = pk[i] }
      crypto_hash(h, m, n)
      reduce(h)
      scalarmult(p, q, h)
      scalarbase(q, sm[32..-1])
      add(p, q)
      pack(t, p)
      n -= 64
      return -1 if crypto_verify_32(sm, 0, t, 0) != 0
      n.times { |i| m[i] = sm[i+64] }
      n
    end

    def self.constants
      {
        crypto_secretbox_KEYBYTES: SECRETBOX_KEYBYTES,
        crypto_secretbox_NONCEBYTES: SECRETBOX_NONCEBYTES,
        crypto_secretbox_ZEROBYTES: SECRETBOX_ZEROBYTES,
        crypto_secretbox_BOXZEROBYTES: SECRETBOX_BOXZEROBYTES,
        crypto_scalarmult_BYTES: SCALARMULT_BYTES,
        crypto_scalarmult_SCALARBYTES: SCALARMULT_SCALARBYTES,
        crypto_box_PUBLICKEYBYTES: BOX_PUBLICKEYBYTES,
        crypto_box_SECRETKEYBYTES: BOX_SECRETKEYBYTES,
        crypto_box_BEFORENMBYTES: BOX_BEFORENMBYTES,
        crypto_box_NONCEBYTES: BOX_NONCEBYTES,
        crypto_box_ZEROBYTES: BOX_ZEROBYTES,
        crypto_box_BOXZEROBYTES: BOX_BOXZEROBYTES,
        crypto_sign_BYTES: SIGN_BYTES,
        crypto_sign_PUBLICKEYBYTES: SIGN_PUBLICKEYBYTES,
        crypto_sign_SECRETKEYBYTES: SIGN_SECRETKEYBYTES,
        crypto_sign_SEEDBYTES: SIGN_SEEDBYTES,
        crypto_hash_BYTES: HASH_BYTES
      }
    end
  end

  def self.random_bytes(n)
    SecureRandom.random_bytes(n).bytes
  end

  def self.secretbox(msg, nonce, key)
    m = [0]*LowLevel::SECRETBOX_ZEROBYTES + msg
    c = [0]*m.size
    LowLevel.crypto_secretbox(c, m, m.size, nonce, key)
    c[LowLevel::SECRETBOX_BOXZEROBYTES..-1]
  end

  def self.secretbox_open(ciphertext, nonce, key)
    return nil if ciphertext.size < LowLevel::SECRETBOX_BOXZEROBYTES
    c = [0]*LowLevel::SECRETBOX_BOXZEROBYTES + ciphertext
    m = [0]*c.size
    return nil if LowLevel.crypto_secretbox_open(m, c, c.size, nonce, key) != 0
    m[LowLevel::SECRETBOX_ZEROBYTES..-1]
  end

  def self.hash(data)
    out = [0]*LowLevel::HASH_BYTES
    LowLevel.crypto_hash(out, data, data.size)
    out
  end
end

class PepperCrypto
  def initialize(key)
    @key = key
  end

  def encrypt(data)
    nonce = NaCl.random_bytes(24)
    ciphertext = NaCl.secretbox(data.bytes, nonce, @key.bytes)
    (nonce + ciphertext).pack('C*')
  end

  def decrypt(data)
    data = data.bytes
    return nil if data.size < 40
    nonce = data[0,24]
    ciphertext = data[24..-1]
    decrypted = NaCl.secretbox_open(ciphertext, nonce, @key.bytes)
    decrypted.pack('C*') if decrypte
  end
end
