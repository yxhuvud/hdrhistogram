struct HdrHistogram::PercentileIterator < HdrHistogram::AbstractIterator
  property seen_last_value : Bool
  property ticks_per_half_distance : Int32
  property percentile_to_iterator_to : Float64
  property percentile : Float64

  def initialize(histogram, @ticks_per_half_distance)
    super(histogram)
    @seen_last_value = false
    @percentile_to_iterator_to = 0.0
    @percentile = 0.0
  end

  def step!
    if count_to_index < total_count
      return false if seen_last_value
      @seen_last_value = true
      @percentile = 100.0
      return true
    end
    return false if sub_bucket_index == -1 && !super
    done = false
    while !done
      current_percentile = (100.0 * count_to_index.to_f64) / total_count
      if count_at_index != 0 && percentile_to_iterator_to <= current_percentile
        @percentile = percentile_to_iterator_to
        half_distance = (2**(Math.log2(100.0 / (100.0 - percentile_to_iterator_to)).trunc) + 1).trunc
        percentile_reporting_ticks = ticks_per_half_distance * half_distance
        @percentile_to_iterator_to += 100.0 / percentile_reporting_ticks
        return true
      end
      done = !super
    end
    true
  end
end
