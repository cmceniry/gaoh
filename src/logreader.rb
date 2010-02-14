

require 'yaml'

def process_message(msg)
  puts YAML.load(msg[1..-1].join()).keys.join("\n") unless msg.empty?
end

msg = []
File.open("logs/communal") do |f|
  begin
    while true
      line = f.readline
      if line =~ /^MESSAGE \d+/
        process_message(msg)
        msg = []
      end
      msg << line
    end
  rescue EOFError
  end
end
process_message(msg)
