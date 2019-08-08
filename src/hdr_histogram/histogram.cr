require "math"

struct HDRHistogram::Histogram
  property lowest_trackable_value : Int64
  property highest_trackable_value : Int64
  property unit_magnitude : Int64
  property significant_figures : Int64
  property sub_bucket_half_count_magnitude : Int32
  property sub_bucket_half_count : Int32
  property sub_bucket_mask : Int64
  property sub_bucket_count : Int32
  property bucket_count : Int32
  property counts_size : Int32
  property total_count : Int64
  property counts

  def initialize(min : Int64, max : Int64, significant_figures : Int32)
    unless (1..5).includes?(significant_figures)
      raise "sigfigs must be in 1..5, #{significant_figures} is not."
    end
    unless min * 2 <= max
      raise "min (%s) must be less than half of the max (%s) value" % {min, max}
    end
    @lowest_trackable_value = min
    @highest_trackable_value = max
    @significant_figures = significant_figures.to_i64

    @sub_bucket_half_count_magnitude = half_count_magnitude
    @unit_magnitude = unit_magnitude(min)
    @sub_bucket_count = 2 ** (sub_bucket_half_count_magnitude + 1)
    @sub_bucket_half_count = sub_bucket_count / 2
    @sub_bucket_mask = (sub_bucket_count.to_i64 - 1) << unit_magnitude

    @bucket_count = buckets_needed(max)
    @counts_size = (bucket_count + 1) * (sub_bucket_count / 2)
    @total_count = 0i64
    @counts = Array(Int64).new(counts_size) { 0i64 }
  end

  def initialize(min : Int, max : Int, sigfigs)
    initialize(min.to_i64, max.to_i64, sigfigs)
  end

  def empty?
    @total_count == 0
  end

  def bytesize
    sizeof(self) + sizeof(Int64) * counts_size
  end

  def merge(other : Histogram)
    dropped = 0i64
    other.each_bucket do |i|
      value, count = i.value_from_index, i.count_at_index
      unless record_values(value, count)
        dropped &+= count
      end
    end
    dropped
  end

  # approximate
  def max
    max = 0i64
    each_bucket do |i|
      if i.count_at_index != 0
        max = i.highest_equivalent_value
      end
    end
    highest_equivalent_value(max)
  end

  # approximate
  def min
    min = 0i64
    each_bucket do |i|
      if i.count_at_index != 0 && min == 0
        min = i.highest_equivalent_value
      end
    end
    lowest_equivalent_value(min)
  end

  # approximate
  def mean
    return 0 if total_count == 0
    total = 0i64
    each_bucket do |i|
      if i.count_at_index != 0
        total += i.count_at_index * median_equivalent_value(i.value_from_index)
      end
    end
    total.to_f64 / total_count
  end

  # approximate
  def std_dev
    return 0 if total_count == 0
    mean = mean()
    geometric_dev_total = 0.0
    each_bucket do |i|
      if i.count_at_index != 0
        dev = median_equivalent_value(i.value_from_index) - mean
        geometric_dev_total += (dev * dev) * i.count_at_index
      end
    end
    Math.sqrt(geometric_dev_total / total_count)
  end

  def reset
    @total_count = 0i64
    @counts.each_index do |i|
      @counts[i] = 0i64
    end
  end

  def record_value(value)
    record_values(value, 1)
  end

  #  record_corrected_value records the given value, correcting for
  #  coordinated omission (ie stalls in the recording process). This
  #  only works for processes which are recording values at an
  #  expected interval (e.g., doing jitter analysis). Processes which
  #  are recording ad-hoc values (e.g., latency for incoming requests)
  #  can't take advantage of this.
  def record_corrected_value(value, expected_interval, count = 1i64)
    return false unless record_values(value, count)
    return true if expected_interval <= 0 || value <= expected_interval

    missing_value = value &- expected_interval
    while missing_value >= expected_interval
      return false unless record_values(missing_value, count)
      missing_value &-= expected_interval
    end
    true
  end

  def record_values(value : Int, count : Int)
    record_values(value.to_i64, count.to_i64)
  end

  def record_values(value : Int64, count : Int64)
    return false if value < 0
    index = counts_index_for(value)
    if index < 0 || counts_size <= index
      puts "Value #{value} is too large to be recorded"
      return false
    end
    @counts[index] &+= count
    @total_count &+= count
    true
  end

  def value_at_percentile(q)
    q = 100 if q > 100
    total = 0i64
    count_at_percentile = ((q.to_f64 / 100) * total_count.to_f64 + 0.5).to_i64
    each_bucket do |i|
      total &+= i.count_at_index
      if total >= count_at_percentile
        return highest_equivalent_value(i.value_from_index)
      end
    end
    0i64
  end

  def each_bucket
    Iterator.new(self).each do |i|
      yield i
    end
  end

  def each_value
    RecordedValuesIterator.new(self).each do |i|
      yield i
    end
  end

  def each_percentile(ticks_per_half_distance)
    PercentileIterator.new(self, ticks_per_half_distance).each do |i|
      yield i
    end
  end

  def equal_values?(a, b)
    lowest_equivalent_value(a.to_i64) == lowest_equivalent_value(b.to_i64)
  end

  # ############## Private or de facto private (with access only for iterators)

  private def buckets_needed(max)
    # determine exponent range needed to support the trackable value
    # with no overflow
    smallest_untrackable_value = sub_bucket_count.to_i64 << unit_magnitude
    needed = 1
    while smallest_untrackable_value <= max
      smallest_untrackable_value <<= 1
      needed += 1
    end
    needed
  end

  private def half_count_magnitude
    largest_value_with_single_unit_resolution = 2 &* 10&**@significant_figures
    whole_count_magnitude =
      Math.log2(largest_value_with_single_unit_resolution).ceil
    whole_count_magnitude > 1 ? (whole_count_magnitude - 1).to_i32 : 0
  end

  private def unit_magnitude(min)
    magnitude = Math.log2(min).floor
    magnitude < 0 ? 0i64 : magnitude.to_i64
  end

  def count_at_index(index, sub_index)
    counts[counts_index(index, sub_index)]
  end

  def value_from_index(index, sub_index)
    sub_index.to_i64.unsafe_shl(index.to_i64 &+ unit_magnitude)
  end

  private def size_of_equivalent_value_range(value)
    bucket_index, sub_bucket_index = bucket_indices(value)
    adjusted_bucket = bucket_index
    if sub_bucket_index >= sub_bucket_count
      adjusted_bucket &+= 1
    end
    1i64.unsafe_shl(unit_magnitude &+ adjusted_bucket)
  end

  def highest_equivalent_value(value)
    next_non_equivalent(value) &- 1
  end

  private def next_non_equivalent(value)
    lowest_equivalent_value(value) &+ size_of_equivalent_value_range(value)
  end

  def lowest_equivalent_value(value)
    bucket_index, sub_bucket_index = bucket_indices(value)
    value_from_index(bucket_index, sub_bucket_index)
  end

  def median_equivalent_value(value)
    lowest_equivalent_value(value) &+
      size_of_equivalent_value_range(value).unsafe_shr(1)
  end

  private def counts_index(bucket_index, sub_bucket_index)
    base_index = (bucket_index &+ 1).unsafe_shl(sub_bucket_half_count_magnitude)
    offset_in_bucket = sub_bucket_index &- sub_bucket_half_count
    base_index &+ offset_in_bucket
  end

  private def counts_index_for(value)
    bucket_index, sub_bucket_index = bucket_indices(value)
    counts_index(bucket_index, sub_bucket_index)
  end

  private def bucket_indices(value)
    bucket_index = bucket_index(value)
    sub_bucket_index = sub_bucket_index(value, bucket_index)
    {bucket_index, sub_bucket_index}
  end

  private def bucket_index(value)
    pow_to_ceiling = 64 &- (value | sub_bucket_mask).leading_zeros_count
    (pow_to_ceiling &- unit_magnitude -
      (sub_bucket_half_count_magnitude &+ 1).to_i64).to_i32
  end

  private def sub_bucket_index(value, index)
    value.unsafe_shr(index &+ unit_magnitude).to_i32
  end
end
