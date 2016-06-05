struct HdrHistogram::RecordedValuesIterator < HdrHistogram::AbstractIterator
  property count_added_this_step : Int64

  def initialize(histogram)
    super
    @count_added_this_step = 0i64
  end

  def step!
    while super
      if count_at_index != 0
        @count_added_this_step = count_at_index
        return true
      end
    end
    false
  end
end
