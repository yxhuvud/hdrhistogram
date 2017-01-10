require "zlib"

module HDRHistogram
  module Codec
    def self.convert(type, slice_or_io)
      IO::ByteFormat::BigEndian.decode(type, slice_or_io)
    end

    def self.zigzag_decode(io, length)
      v = convert(Int8, io)
      value = Int64.new(v & 0x7f)
      if v & 0x80 != 0
        v = convert(Int8, io)
        value |= Int64.new((v & 0x7F)) << 7
        if ((v & 0x80) != 0)
          v = convert(Int8, io)
          value |= Int64.new((v & 0x7F)) << 14
          if ((v & 0x80) != 0)
            v = convert(Int8, io)
            value |= Int64.new((v & 0x7F)) << 21
            if ((v & 0x80) != 0)
              v = convert(Int8, io)
              value |= Int64.new((v & 0x7F)) << 28
              if ((v & 0x80) != 0)
                v = convert(Int8, io)
                value |= Int64.new((v & 0x7F)) << 35
                if ((v & 0x80) != 0)
                  v = convert(Int8, io)
                  value |= Int64.new((v & 0x7F)) << 42
                  if ((v & 0x80) != 0)
                    v = convert(Int8, io)
                    value |= Int64.new((v & 0x7F)) << 49
                    if ((v & 0x80) != 0)
                      v = convert(Int8, io)
                      value |= Int64.new(v) << 56
                    end
                  end
                end
              end
            end
          end
        end
      end
      (value >> 1) ^ -(value & 1)
    end

    def self.decode(str)
      decoded = Base64.decode str

      cookie = convert(Int32, decoded[0, 4])
      length = convert(Int32, decoded[4, 4])
      raise "Invalid cookie" unless cookie == 478450452

      io = IO::Memory.new(decoded + 8)
      inflator = Zlib::Inflate.new(io)

      internal_cookie = convert(Int32, inflator)
      internal_length = convert(Int32, inflator)
      raise "Invalid internal cookie" unless internal_cookie == 478450451

      index_offset = convert(Int32, inflator) # ?
      significant_figures = convert(Int32, inflator)
      min = convert(Int64, inflator)
      max = convert(Int64, inflator)
      conversion_ratio = convert(Float64, inflator)

      histogram = HDRHistogram.new min, max, significant_figures

      values = Array(Int64).new
      # Fixme: manually read internal_length slices on crystal 0.20+
      # No good way to check that it is done in 0.19 :(
      begin
        while true
          values << zigzag_decode(inflator, length)
        end
      rescue IO::EOFError
      end
      values.reduce(0) do |index, value|
        if value < 0
          index = index - value
          next index
        end
        histogram.counts[index] = value
        histogram.total_count += value
        index + 1
      end
      histogram
    end
  end
end
