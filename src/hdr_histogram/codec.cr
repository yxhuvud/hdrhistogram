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

    def self.decode(str)
      decoded = Base64.decode str

      cookie = BigEndian.decode(Int32, decoded[0, 4])
      length = BigEndian.decode(Int32, decoded[4, 4])
      raise "Invalid cookie" unless cookie == EXTERNAL_COOKIE

      io = IO::Memory.new(decoded + 8)
      inflator = Zlib::Inflate.new(io)

      internal_cookie = BigEndian.decode(Int32, inflator)
      internal_length = BigEndian.decode(Int32, inflator)
      raise "Invalid internal cookie" unless internal_cookie == INTERNAL_COOKIE

      index_offset = BigEndian.decode(Int32, inflator) # ?
      significant_figures = BigEndian.decode(Int32, inflator)
      min = BigEndian.decode(Int64, inflator)
      max = BigEndian.decode(Int64, inflator)
      conversion_ratio = BigEndian.decode(Float64, inflator)

      histogram = HDRHistogram.new min, max, significant_figures

      consumed = 0
      index = 0
      while consumed < internal_length
        value, size = zigzag_decode(inflator)
        consumed += size
        if value < 0
          index -= value
        else
          histogram.counts[index] = value
          histogram.total_count += value
          index += 1
        end
      end
      histogram
    end
  end
end
