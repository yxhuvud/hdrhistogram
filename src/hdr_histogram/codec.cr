require "zlib"

module HDRHistogram
  module Codec
    BigEndian       = IO::ByteFormat::BigEndian
    INTERNAL_COOKIE = 478450451
    EXTERNAL_COOKIE = 478450452

    def self.zigzag_decode(io)
      size = 1
      v = BigEndian.decode(Int8, io)
      value = Int64.new((v & 0x7F))
      while v & 0x80 != 0 && size < 9
        offset = size * 7
        v = BigEndian.decode(Int8, io)
        val = size == 8 ? Int64.new(v) : Int64.new((v & 0x7F))
        value |= val << offset
        size += 1
      end
      {(value >> 1) ^ -(value & 1), size}
    end

    def self.zigzag_encode(n, io)
      n = n < 0 ? ((n + 1).abs.to_u32 << 1) + 1 : n.to_u32 << 1
      while true
        bits = UInt8.new(n & 0x7F)
        n >>= 7
        break if n == 0
        BigEndian.encode(bits | 0x80, io)
      end
      BigEndian.encode(bits, io)
    end

    def self.encode(histogram)
      counts = IO::Memory.new
      negative_count = 0
      histogram.counts.each do |count|
        if count == 0
          negative_count += 1
        else
          if negative_count > 0
            zigzag_encode(-negative_count, counts)
            negative_count = 0
          end
          zigzag_encode(count, counts)
        end
      end

      internal = IO::Memory.new
      BigEndian.encode(INTERNAL_COOKIE, internal)
      BigEndian.encode(counts.size, internal)

      index_offset = 0i32 # ?
      BigEndian.encode(index_offset, internal)
      BigEndian.encode(histogram.significant_figures.to_i32, internal)
      BigEndian.encode(histogram.lowest_trackable_value, internal)
      BigEndian.encode(histogram.highest_trackable_value, internal)

      conversion_ratio = 1.0f64 # conversion ratio ?
      BigEndian.encode(conversion_ratio, internal)
      internal.write counts.to_slice

      output = IO::Memory.new
      BigEndian.encode(EXTERNAL_COOKIE, output)
      BigEndian.encode(internal.size, output)
      Zlib::Writer.open(output) do |deflator|
        deflator.write internal.to_slice
      end
      Base64.strict_encode output.to_slice
    end

    def self.decode(str)
      decoded = Base64.decode str

      cookie = BigEndian.decode(Int32, decoded[0, 4])
      length = BigEndian.decode(Int32, decoded[4, 4])
      raise "Invalid cookie" unless cookie == EXTERNAL_COOKIE

      io = IO::Memory.new(decoded + 8)
      inflator = Zlib::Reader.new(io)

      internal_cookie = BigEndian.decode(Int32, inflator)
      internal_length = BigEndian.decode(Int32, inflator)
      raise "Invalid internal cookie" unless internal_cookie == INTERNAL_COOKIE

      index_offset = BigEndian.decode(Int32, inflator) # ?
      significant_figures = BigEndian.decode(Int32, inflator)
      min = BigEndian.decode(Int64, inflator)
      max = BigEndian.decode(Int64, inflator)
      conversion_ratio = BigEndian.decode(Float64, inflator)

      histogram = HDRHistogram.new min, max, significant_figures

      index = 0
      while internal_length > 0
        count, size = zigzag_decode(inflator)
        internal_length -= size
        if count < 0
          index -= count
        else
          histogram.counts[index] = count
          histogram.total_count += count
          index += 1
        end
      end
      histogram
    end
  end
end
