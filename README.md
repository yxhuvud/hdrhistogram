# HDRHistogram

High Dynamic Range Histogram crystal implementation

A Histogram that supports recording and analyzing sampled data value
counts across a configurable integer value range with configurable
value precision within the range.

HdrHistogram is designed for recording histograms in latency and
performance sensitive applications. The memory footprint is constant
(depending only on precision), as is the work required to record a
value.

Implementation heavily inspired [HdrHistogram](http://hdrhistogram.org) by
Gil Tene and the different implementations that can be found on the
project site. All errors are original content and not present in the
original.

Supports:
* Recording values.
* Recording values with correction for coordinated omission.
* Get value at percentile.
* Get total count.
* Get min, max, mean and std deviation.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  hdrhistogram:
    github: yxhuvud/hdrhistogram
```

## Usage

First create a histogram:

```crystal
require "hdr_histogram"

histogram = HDRHistogram.new(1, 60, 60 * 1000, 2)

```

Then it is possible to record values like:

```crystal
histogram.record_value latency
```

It is also possible to record values with an expected known interval:

```crystal
time_between_iteration = 100
histogram.record_corrected_value latency, time_between_iteration
```

It is possible to query a histogram for properties:

```crystal
count = histogram.total_count
value = histogram.value_at_quantile(99.9)
```

It is possible to iterate over the values:

```crystal
histogram.each_value do |i|
  puts "value: #{i.value_from_index}, count: #{i.count_at_index}"
end
```

## Performance

Fixme: Add benchmarks.


## Contributing

1. Fork it ( https://github.com/yxhuvud/hdrhistogram/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [yxhuvud](https://github.com/yxhuvud) Linus Sellberg - creator, maintainer
