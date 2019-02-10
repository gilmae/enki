require "json"

module Enki
  BASE_CONFIG = {:next_point => 0}

  def self.get_config(name, &block)
    filename = File.expand_path(File.join("~", ".enki", name))
    return (block || Proc.new { BASE_CONFIG }).call unless File.exists?(filename)

    config = File.open(filename, "r") { |f|
      JSON.parse(f.readlines.join("\n"))
    }

    return (block || Proc.new { BASE_CONFIG }).call unless config.class == {}.class

    config = config.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }

    config
  end

  def self.store_config(config, name)
    filename = File.expand_path(File.join("~", ".enki", name))
    File.open(filename, "w") { |f|
      f << config.to_json
    }
  end

  def self.save_to_tempfile(url)
    uri = URI.parse(url)
    name = uri.path.split("/").last
    filepath = "/tmp/#{name}"
    Net::HTTP.start(uri.host, uri.port) do |http|
      resp = http.get(uri.path)
      File.open(filepath, "wb") { |file|
        file.write(resp.body)
      }
    end

    filepath
  end
end
