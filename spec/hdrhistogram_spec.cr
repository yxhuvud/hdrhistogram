require "./spec_helper"

HIGHEST         = 3_600_000_000
HIGH            =   100_000_000
SIGS            =             3
INTERVAL        =         10000
SCALE           =           512
SCALED_INTERVAL = INTERVAL * SCALE

def raw_histogram
  h = HdrHistogram::Histogram.new(1, HIGHEST, SIGS)
  10000.times { h.record_value 1000 }
  h.record_value HIGH
  h
end

# def cor_histogram
#   h = HdrHistogram::Histogram.new(1, HIGHEST, SIGS)
#   10000.times { h.record_corrected_value 1000 }
#   h.record_corrected_value HIGH, INTERVAL
#   h
# end

def scaled_raw_histogram
  h = HdrHistogram::Histogram.new(1000, HIGHEST*512, SIGS)
  10000.times { h.record_value 1000*SCALE }
  h.record_value HIGH*SCALE
  h
end

# def scaled_cor_histogram
#   h = HdrHistogram::Histogram.new(1000, HIGHEST*512, SIGS)
#   10000.times { h.record_corrected_value 1000 }
#   h.record_corrected_value HIGH*SCALE, SCALED_INTERVAL
#   h
# end

describe Hdrhistogram do
  it "#initialize" do
    hist = HdrHistogram::Histogram.new(1, 3600000000i64, 3)
    hist.counts.size.should eq 23552
  end

  it "create with large values (sub_bucket_mask overflow)" do
    h = HdrHistogram::Histogram.new(20000000, 100000000, 5)
    h.record_value 100000000
    h.record_value 20000000
    h.record_value 30000000
    h.total_count.should eq 3
    h.equal_values?(h.value_at_quantile(50), 20000000).should be_true
    h.equal_values?(h.value_at_quantile(83.33), 30000000).should be_true
    h.equal_values?(h.value_at_quantile(83.34), 100000000).should be_true
    h.equal_values?(h.value_at_quantile(99.0), 100000000).should be_true
  end

  it "has the correct amount of significant figures" do
    x = [459876, 669187, 711612, 816326, 931423, 1033197, 1131895, 2477317,
      3964974, 12718782]
    hist = HdrHistogram::Histogram.new(459876, 12718782, 5)
    x.each { |i| hist.record_value i }
    hist.value_at_quantile(50).should eq 1048575
  end

  it "#value_at_quantile" do
    hist = HdrHistogram::Histogram.new(1, 10000000, 3)
    0.upto(1_000_000) do |i|
      hist.record_value(i)
    end
    data = {
         50 => 500223,
         75 => 750079,
         90 => 900095,
         95 => 950271,
         99 => 990207,
       99.9 => 999423,
      99.99 => 999935,
    }
    data.each { |q, v|
      [q, hist.value_at_quantile(q)].should eq [q, v]
    }
  end

  describe "raw_histogram" do
    h = raw_histogram

    it "#total_count" do
      h.total_count.should eq 10001
    end

    it "#max" do
      h.equal_values?(h.max, 100000000)
    end

    it "#min" do
      h.equal_values?(h.min, 1000)
    end

    it "#quantiles" do
      h.value_at_quantile(30).should eq 1000.0
      h.value_at_quantile(99).should eq 1000.0
      h.value_at_quantile(99.99).should eq 1000.0
      h.value_at_quantile(99.999).should eq 100000000.0
      h.value_at_quantile(100).should eq 100000000.0
    end

    it "iterates" do
      index = 0
      h.each_value do |i|
        count_from_bucket = i.count_added_this_step
        if index == 0
          count_from_bucket.should eq 10000
        else
          count_from_bucket.should eq 1
        end
        index += 1
      end
      index.should eq 2
    end
  end

  it "#reset" do
    h = raw_histogram
    h.total_count.should_not eq 0
    h.value_at_quantile(99.0).should_not eq 0
    h.reset
    h.value_at_quantile(99.0).should eq 0
    h.total_count.should eq 0
  end

  it "checks for out of range values" do
    h = HdrHistogram::Histogram.new(1, 1000, 4)
    h.record_value(32767).should be_true
    h.record_value(32768).should be_false
  end

  it "linear iter" do
    h = HdrHistogram::Histogram.new(1, 255, 2)
    [193, 255, 0, 1, 64, 128].each do |i|
      h.record_value i
    end

    steps = 0
    total_count = 0

    h.each do |i|
      total_count += i.count_at_index
      steps += 1
    end
    steps.should eq 4
    total_count.should eq total_count
  end

  it "#mean" do
    h = HdrHistogram::Histogram.new(1, 10000000, 3)
    1000000.times do |i|
      unless h.record_value i
        true.should be_false
      end
    end
    h.mean.should eq 500000.013312
  end

  it "#std_dev" do
    h = HdrHistogram::Histogram.new(1, 10000000, 3)
    1000000.times do |i|
      h.record_value(i).should be_true
    end
    h.std_dev.should eq 288675.1403682715
  end

  it "#merge" do
    h = HdrHistogram::Histogram.new(1, 1000, 3)
    h2 = HdrHistogram::Histogram.new(1, 1000, 3)
    100.times do |i|
      h.record_value(i)
      h2.record_value(i + 1)
    end
    h.merge(h2)
    h.value_at_quantile(50).should eq 99i64
  end

  it "#byte_size" do
    h = HdrHistogram::Histogram.new(1, 100000, 3)
    h.bytesize.should eq 65616
  end

  it "doesn't overflow unit magnitude" do
    h = HdrHistogram::Histogram.new(0, 200, 4)
    h.record_value(11).should be_true
  end
end
