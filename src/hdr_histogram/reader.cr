# coding: utf-8
require "string_scanner"
require "base64"

class HDRHistogram::Reader
  include Enumerable(Histogram)

  HISTOGRAM_LOG_FORMAT_VERSION = "1.2"

  property start_time
  property scanner

  def initialize(input)
    @start_time = 0.0f64
    @observed_start_time = false
    @observed_base_time = false
    @scanner = StringScanner.new(input)
  end

  def reset
    @scanner.reset
  end

  def each(*args)
    decoded_histogram = next_interval_histogram(*args)
    while decoded_histogram != nil
      yield decoded_histogram.as(Histogram)
      decoded_histogram = next_interval_histogram(*args)
    end
    reset
  end

  # Private for now until ranges are actually checked.
  private def next_interval_histogram(start_time, end_time)
    next_interval_histogram(start_time, end_time, false)
  end

  private def next_absolute_interval_histogram(start_time, end_time)
    next_interval_histogram(start_time, end_time, true)
  end

  def next_interval_histogram
    next_interval_histogram(0.0f64, Int64::MAX.to_f, true)
  end

  def next_interval_histogram(range_start_time, range_end_time, absolute)
    until scanner.eos?
      case
      when (comment = scanner.scan(/#.*\n/))
        extract_header_start_time comment
        extact_header_base_time comment
      when (_headers = scanner.scan(/"StartTimestamp".*\n/))
        # skip
      else
        log_start_time, interval_length, payload = read_content_line
        # FIXME: Try again if outside range.
        extract_start_time(log_start_time)
        extract_base_time(log_start_time)
        # Not handling tags yet.
        return parse_payload(payload)
      end

      # See https://github.com/HdrHistogram/HdrHistogram/blob/master/src/main/java/org/HdrHistogram/HistogramLogReader.java#L197
    end
  end

  def extract_header_start_time(str)
    if str =~ /^#\[StartTime: (\d+.\d+)/
      @start_time = Float64.new($1)
      @observed_start_time = true
    end
  end

  def extact_header_base_time(str)
    if str =~ /^#\[BaseTime: (\d+.\d+)/
      @base_time = Float64.new($1)
      @observed_base_time = true
    end
  end

  def extract_start_time(log_start_time)
    unless @observed_start_time
      @start_time = log_start_time
      @observed_start_time = true
    end
  end

  def extract_base_time(log_start_time)
    unless @observed_base_time
      if (log_start_time < start_time - (365 * 24 * 3600.0))
        # Criteria Note: if log timestamp is more than a year
        # in the past (compared to start_time), we assume that
        # timestamps in the log are not absolute
        @base_time = start_time
      else
        # Timestamps are absolute
        @base_time = 0.0f64
      end
      @observed_base_time = true
    end
  end

  def read_content_line
    regexp = /(?<start_time>[^,]+),(?<interval_length>[^,]+),(?<max_time>[^,]+),(?<payload>[^,]+)\n/
    scanner.scan(regexp)
    # Note: max time can be inferred from the histogram, so don't bother returning it.
    {Float64.new(scanner["start_time"]),
     Float64.new(scanner["interval_length"]),
     scanner["payload"]}
  end

  def parse_payload(str)
    Codec.decode(str)
  end
end
