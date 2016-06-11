abstract struct HDRHistogram::AbstractIterator
  property histogram : Histogram
  property bucket_index : Int32
  property sub_bucket_index : Int32
  property count_at_index : Int64
  property count_to_index : Int64
  property value_from_index : Int64
  property highest_equivalent_value : Int64

  forward_missing_to histogram

  def initialize(@histogram)
    @bucket_index = 0
    @sub_bucket_index = -1
    @count_at_index = 0i64
    @count_to_index = 0i64
    @value_from_index = 0i64
    @highest_equivalent_value = 0i64
  end

  def each
    while step!
      yield self
    end
  end

  def step!
    return false if count_to_index >= total_count

    @sub_bucket_index += 1
    if sub_bucket_index >= sub_bucket_count
      @sub_bucket_index = sub_bucket_half_count
      @bucket_index += 1
    end

    return false if bucket_index >= bucket_count

    @count_at_index = count_at_index(bucket_index, sub_bucket_index)
    @count_to_index += count_at_index
    @value_from_index = value_from_index(bucket_index, sub_bucket_index)
    @highest_equivalent_value = highest_equivalent_value(value_from_index)
    true
  end
end
