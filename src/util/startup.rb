
STARTCOUNT=5

started = 0
Dir.entries("configs").each do |entry|
  next if entry == "."
  next if entry == ".."
  next if entry == ".gitignore"
  break if started >= STARTCOUNT
  IO.popen("./usr/bin/ruby ./src/worker.rb ./configs/#{entry} &")
  started += 1
end
