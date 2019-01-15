require 'json'
require 'open-uri'
require './pinboard'
require 'time'
require 'fileutils'
require 'timeout'


def get_config
    filename = File.expand_path(File.join("~", ".enki", "#{File.basename(__FILE__)}.config"))

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
    filename = File.expand_path(File.join("~", ".enki", "#{File.basename(__FILE__)}.config"))
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
    filename = sanitize_filename(pin["description"])
    exec_with_timeout("/Applications/Google\\ Chrome\\ Canary.app/Contents/MacOS/Google\\ Chrome\\ Canary --headless --disable-gpu --print-to-pdf=#{path}/#{filename}.pdf #{pin["url"]}",30)
    
end

def sanitize_filename(filename)
    # Split the name when finding a period which is preceded by some
    # character, and is followed by some character other than a period,
    # if there is no following period that is followed by something
    # other than a period (yeah, confusing, I know)
    fn = filename.split /(?<=.)\.(?=[^.])(?!.*\.[^.])/m
  
    # We now have one or two parts (depending on whether we could find
    # a suitable period). For each of these parts, replace any unwanted
    # sequence of characters with an underscore
    fn.map! { |s| s.gsub /[^a-z0-9\-]+/i, '_' }
  
    # Finally, join the parts with a period and return the result
    return fn.join '.'
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




