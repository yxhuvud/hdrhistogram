require "./spec_helper"
require "./help_histograms"

writer = HDRHistogram::Writer
TEST_FILE_NAME = "hdr.log"

describe HDRHistogram::Writer do
  it "#initialize" do
    w = writer.new
    w.output_file.should eq "out.logV2.hlog"
    w.start_time.should eq 0
    File.delete("out.logV2.hlog")
  end

  it "scenario" do
    w = writer.new(TEST_FILE_NAME)
    w.write_comment("Logged with Logged with header_histogram.cr")
    w.write_log_format_version
    w.write_legend
    w.write_interval_histogram(empty_histogram)
    w.write_interval_histogram(raw_histogram)
    w.write_interval_histogram(cor_histogram)
    w.close
    reader = HDRHistogram::Reader.new(File.read TEST_FILE_NAME)

    empty_histogram = reader.next_interval_histogram
    empty_histogram.not_nil!.empty?.should eq true

    histogram = reader.next_interval_histogram
    histogram.not_nil!.total_count.should eq 10001
    histogram.not_nil!.counts == raw_histogram.counts

    corrected = reader.next_interval_histogram
    corrected.not_nil!.total_count.should eq 20000
    corrected.not_nil!.counts == cor_histogram.counts

    last = reader.next_interval_histogram
    last.should eq nil

    File.delete(TEST_FILE_NAME)
  end
end
