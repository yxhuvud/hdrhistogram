HIGHEST         = 3_600_000_000
HIGH            =   100_000_000
SIGS            =             3
INTERVAL        =         10000
SCALE           =           512
SCALED_INTERVAL = INTERVAL * SCALE

def empty_histogram
  HDRHistogram.new 1, 3_600_000_000, 3
end

def raw_histogram
  h = HDRHistogram.new(1, HIGHEST, SIGS)
  10000.times { h.record_value 1000 }
  h.record_value HIGH
  h
end

def cor_histogram
  h = HDRHistogram.new(1, HIGHEST, SIGS)
  h.record_corrected_value 1000, INTERVAL, 10_000
  h.record_corrected_value HIGH, INTERVAL
  h
end

def scaled_raw_histogram
  h = HDRHistogram.new(1000, HIGHEST*512, SIGS)
  10000.times { h.record_value 1000*SCALE }
  h.record_value HIGH*SCALE
  h
end

def scaled_cor_histogram
  h = HDRHistogram.new(1000, HIGHEST*512, SIGS)
  h.record_corrected_value 1000*SCALE, INTERVAL, 10000
  h.record_corrected_value HIGH*SCALE, SCALED_INTERVAL
  h
end
