require 'yaml'

LETTERS="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

50.times do |x|
  noise = (1.upto(rand(100).to_i).map { |val| LETTERS[rand(52).to_i] }).join("")
  node = %x{echo #{noise} | md5sum | awk '{print \$1}'}.strip
  jid = "gw-#{node}@corgalabs.com/#{node}"
  puts "Doing \"#{node}\""
  File.open("configs/#{node}", "w") do |f|
    f.write(YAML.dump({:regonly => true, :password => "gaoh", :jid => jid}))
  end
  puts " --" + %x{./usr/bin/ruby ./src/worker.rb ./configs/#{node}}.gsub(/\n/, "\n --")
  File.open("configs/#{node}", "w") do |f|
    f.write(YAML.dump({:password => "gaoh", :jid => jid}))
  end
  puts "done"
  sleep 601
end
