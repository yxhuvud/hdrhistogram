require "./spec_helper"
reader = HDRHistogram::Reader
READER_HICCUP_LOG = File.read(File.join(__DIR__, "jHiccup-2.0.7S.logV2.hlog"))

test_value_level = 4
interval = 10000

def test_histogram
  lowest = 1
  highest = 3_600_000_000
  significant = 3

  HDRHistogram.new(lowest, highest, significant)
end

def log_reader(test_content = READER_HICCUP_LOG)
  HDRHistogram::Reader.new(test_content)
end

JHICCUP_SMALL_RANGE = {
  range_start_time_sec: 5,
  range_end_time_sec:   20,
  target:               {
    histogram_count:       15,
    total_count:           11664,
    accumulated_histogram: {
      value_at_99_9th: 1536163839,
      max_value:       1544552447,
    },
  },
}

JHICCUP_BIG_RANGE = {
  range_start_time_sec: 40,
  range_end_time_sec:   60,
  target:               {
    histogram_count: 20,
    total_count:     15830,
    accumulated:     {
      value_at_99_9th: 1779433471,
      max_value:       1796210687,
    },
  },
}

describe HDRHistogram::Reader do
  it "#has start time" do
    log_reader.start_time.should eq 0.0
  end

  describe "#next_interval_histogram" do
    it "sets the start time" do
      r = log_reader
      r.next_interval_histogram
      r.start_time.should_not eq 0.0
    end
  end

  describe "v2log" do
    it "reads the correct number of histograms" do
      log_reader.size.should eq 62
    end

    it "reads the full histogram correctly" do
      accumulated_histogram = test_histogram
      log_reader = log_reader()

      log_reader.each { |h| accumulated_histogram.merge(h) }
      accumulated_histogram.total_count.should eq 48761
      accumulated_histogram.value_at_percentile(99.9).should eq 1745879039
      accumulated_histogram.max.should eq 1796210687
      log_reader.start_time.should eq 1441812279.474
    end
    # Fixme: add ranges.
  end
end
