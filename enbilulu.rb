require "json"
require "open-uri"

module Enbilulu
  def self.get_points(last)
    uri = "http://avocadia.net/stream/get_records/#{last}/10"

    open(uri) { |f|
      JSON.parse(f.readlines.join("\n"))
    }.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }
  end

  def self.get_starting_point(type, from = 0)
    uri = "http://avocadia.net/stream/get_stream_position/#{type}/#{from}"

    open(uri) { |f|
      JSON.parse(f.readlines.join("\n"))
    }["point"]
  end
end
