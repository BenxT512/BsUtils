module Util
  module_function

  def normalize_input(input)
    case input
    when String then input.bytes
    when Array then input
    else raise "Unsupported input type"
    end
  end

  def to_hex(bytes)
    bytes.map { |b| b.to_s(16).rjust(2, '0') }.join
  end

  def debug_print(label, arr, size)
    # Для отладки (при необходимости)
  end

  def test_speed(hash_fn, n, m)
    # Для тестирования производительности
  end
end
