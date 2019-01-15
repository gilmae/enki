require 'json'
require 'open-uri'
require './pinboard'
require 'time'
require 'fileutils'
require 'timeout'


def get_config
    filename = "#{File.basename(__FILE__)}.config"
    return {:next_point=>0} unless File.exists?(filename)
    
    config = File.open(filename, "r") { |f| 
        JSON.parse(f.readlines.join("\n"))
    }
    
    return {:next_point=>0} unless config.class == {}.class

    config = config.each_with_object({}){|(k,v), h| h[k.to_sym] = v}
    config[:next_point] = 0 unless config[:next_point]
    config
end

def store_config config
    filename = "#{File.basename(__FILE__)}.config"
    File.open(filename, "w") { |f| 
        f << config.to_json
    }
end

def exec_with_timeout(cmd, timeout)
    pid = Process.spawn(cmd, {[:err,:out] => :close, :pgroup => true})
    begin
      Timeout.timeout(timeout) do
        Process.waitpid(pid, 0)
        $?.exitstatus == 0
      end
    rescue Timeout::Error
      Process.kill(15, -Process.getpgid(pid))
      false
    end
  end

def get_next_batch stream_position, batch_size
    uri = "http://avocadia.net/stream/get_records/#{stream_position}/#{batch_size}"

    open(uri) { |f|
        JSON.parse(f.readlines.join("\n"))
    }.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
end

def process_pin pin
    date_pinned = Time.parse(pin["dt"])
    path = "backups/#{date_pinned.year}/#{date_pinned.month}/#{date_pinned.day}/#{date_pinned.strftime("%H%M%S")}"
    FileUtils.mkdir_p path
    exec_with_timeout("/Applications/Google\\ Chrome\\ Canary.app/Contents/MacOS/Google\\ Chrome\\ Canary --headless --disable-gpu --print-to-pdf=#{path}/#{pin["description"].gsub(/\s/,"_") }.pdf #{pin["url"]}",30)
    
end

config = get_config

data = get_next_batch config[:next_point], 1
working_on = config[:next_point]

begin
    while (!data[:records].empty?)
        data[:records].each{ |r| 
            
            working_on = r["sequence_number"] 
            next unless r["data"]["bookmark-of"]

            entry = r["data"].each_with_object({}){|(k,v), h| h[k.downcase] = v}
            created_at = DateTime.parse(r["created_at"])
            bookmark = {
                "url"=>entry["bookmark-of"],
                "description"=>entry["name"],
                "dt"=>created_at.new_offset(0).strftime("%FT%TZ")
            }
            puts "Backing up #{bookmark}"
            process_pin  bookmark
            config[:next_point] = working_on
        }
        config[:next_point] = working_on + 1
        data = get_next_batch config[:next_point], 1
    end
ensure
    store_config config
end




