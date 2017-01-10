class HDRHistogram::Writer
  HISTOGRAM_LOG_FORMAT_VERSION = "1.2"

  property output_file, file, base_time, start_time

  def initialize(@output_file = "out.logV2.hlog")
    @file = File.open(output_file, "w")
    @base_time = 0f64
    @start_time = 0f64
  end

  def self.writer(fname)
    writer = new(fname)
    yield writer
    writer.close
  end

  def write_comment(str)
    write "##{str.strip}"
  end

  def write_log_format_version
    write_comment "[Histogram log format version #{HISTOGRAM_LOG_FORMAT_VERSION}]"
  end

  def write_legend
    headers = ["StartTimestamp", "Interval_Length", "Interval_Max", "Interval_Compressed_Histogram"]
    write headers.map { |hdr| "\"#{hdr}\"" }.join(", ")
  end

  def write_interval_histogram(histogram, start_time_sec = 0, end_time_sec = 0,
                               max_value_unit_ratio = 1_000_000.0)
    write "%.3f,%.3f,%.3f,%s" % {
      start_time_sec,
      end_time_sec - start_time_sec,
      histogram.max.to_f64 / max_value_unit_ratio,
      Codec.encode(histogram),
    }
  end

  def write_start_time(time)
    write_comment "[StartTime: %f]" % time
  end

  def write_base_time(time)
    write_comment "[BaseTime: %f]" % time
  end

  def close
    file.close
  end

  def finalize
    close unless @file.closed?
  end

  private def write(str)
    file.puts str
  end
end
