#!/bin/env ruby

require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/muc'
require 'yaml'
require 'thread'

class GaohWorker

  def initialize( configfilename )
    if not File.exists?( configfilename )
      puts "Missing config file"
      exit -2
    end
    begin
      @config = YAML.load_file( configfilename )
    rescue StandardError => e
      puts "Error parsing config file: #{e}"
      exit -2
    end
    if not @config
      puts "Empty config"
      exit -2
    end
    missing = []
    [ :jid, :password ].each do |k|
      missing << k if not @config.key?(k)
    end
    if not missing.empty?
      puts "Invalid config file.  Missing key(s): #{missing.join(",")}"
      exit -2
    end

    @setup = false

    begin
      @jid = Jabber::JID.new(@config[:jid])
      @xmpp = Jabber::Client.new(@jid)
      @xmpp.connect('corgalabs.com')
      @xmpp.auth(@config[:password])
      @setup = true
    rescue Jabber::ClientAuthenticationFailure => e
      if attempt_to_register
        @setup = true
      end
    end

    if not @setup
      puts "Unable to setup"
      exit -4
    end

    @mainloop = Thread.current
    @worker   = Thread.new {}
    @todo      = []
    @scheduleq = Queue.new
    @scheduler = Thread.new { safe_block("scheduler") { scheduler } }
    @communal = nil
    @tasks    = {
      :timestamp => 0,
      :task1     => 0,
      :task2     => 0,
      :task3     => 0,
    }
    @mytask   = {
      :name      => nil,
      :start     => nil,
    }
    @state    = :init
    @others = {}

    @lastcheck = 0
    @lasttasks = 0

  end

  def status_message
    if @mytask[:name].nil?
      Jabber::Message.new( nil, "current: idle" )
    else
      Jabber::Message.new( nil, "current: busy: #{@mytask[:name]}: #{Time.now.to_i - @mytask[:start]}" )
    end
  end

  def tasks_message
    Jabber::Message.new( nil,
                         "tasks %d %d %d %d"%[ @tasks[:timestamp],
                                               @tasks[:task1],
                                               @tasks[:task2],
                                               @tasks[:task3] ] )
  end

  def safe_block(message=nil, *args)
    begin
      yield *args
    rescue StandardError => e
      puts "safe_block%s: %s:\n--%s"%[ message.nil? ? "" : "(#{message})",
                                       e,
                                       e.backtrace.join("\n--") ]
    end
  end

  def notself(name)
    name != "gw-" + @jid.resource
  end

  def worker
    puts "Starting a new task: #{@mytask[:name]}"
    unless @mytask[:name].nil?
      @state = :busy
      @mytask[:start] = Time.now.to_i
      @communal.send( status_message )
      case @mytask[:name]
      when :task1
        sleep(50+rand(21))
      when :task2
        sleep(75+rand(31))
      when :task3
        sleep(270+rand(61))
      else
      end
      @communal.send( Jabber::Message.new( nil, 
                                          "jobdone: %s: %d"%[@mytask[:name],
                                                             Time.now.to_i - @mytask[:start]] ) )
      @mytask[:start] = nil
      @mytask[:name]  = nil
      @state = :idle
      @communal.send( status_message )
    end
  end

  def scheduler
    while true
      #puts "Scheduler running: #{@todo.size}: #{@scheduleq.size}"
      # Empty out any new items and add them to my todo list
      while not @scheduleq.empty?
        @todo << @scheduleq.pop
      end
      @todo.sort! { |a,b| a[0] <=> b[0] }
      #puts "SCHEDULER:#{Time.now.to_i} -- " + @todo.map { |i| "#{i[0]}:#{i[1]}" }.join(",")
      # See if there's something on my todo list to do
      begin
        nextup = @todo[0] || [ 2**31, nil ]
        while nextup[0] <= Time.now.to_i
          @todo.shift
          puts "Working on #{nextup[0]}:#{nextup[1]}"
          case nextup[1]
          when :changetask
            work_decide
          when :recheck
            recheck
          end
          nextup = @todo[0] || [ 2**31, nil ] 
        end
      rescue StandardError => e
        puts "Schduler issue: #{e}\n  #{e.backtrace.join("\n  ")}"
      end
      sleep(1) 
    end
  end

  def attempt_to_register
    begin
      @xmpp.register( @config[:password] )
      sleep 5
      @xmpp.auth( @config[:password] )
    rescue Jabber::ServerError, Jabber::ClientAuthenticationFailure => e
      puts "Unable to login/register: #{e.class} : #{e}"
      exit -3
    end
  end

  def work_status
    # This is used to report what the current work status is.
    # Will be used to help decide to ditch the current work or not.
    # First Pass: Just returns the time spent on task
  end

  def work_decide
    puts "Picking a new task..."
    # This is used to figure out what work to do
    newtask = [:task1, :task2, :task3][rand(3)]
    puts "newtask: #{newtask}"

    # change task
    if newtask != @mytask[:name]
      @mytask[:name] = newtask
      Thread.kill(@worker)
      @worker = Thread.new { safe_block("work_decide:worker") { worker } }
    end
  end

  def recheck
    if Time.now.to_i - @lastcheck >= 60
      @communal.send( status_message )
      @communal.send( Jabber::Message.new( nil, "tasks?" ) )
      @lastcheck = Time.now.to_i
    end
    puts "Rechecking rescheduling"
    @scheduleq << [@lastcheck.to_i+60, :recheck]
  end

  def enter_communal
    @communal = Jabber::MUC::MUCClient.new(@xmpp)
    @communal.add_message_callback { |m| safe_block("communal", m) do
        # Ignore it if it was sent before I got here
        if m.x.nil?
          if m.body == "dump"
            puts "------ DUMP ------"
            puts Time.now.to_i
            puts "------- ME -------"
            puts "Scheduler running: #{@todo.size}: #{@scheduleq.size}"
            puts @worker.inspect
            puts @worker.status
            puts YAML.dump(@mytask)
            puts "----- OTHERS -----"
            puts YAML.dump(@others)
          elsif m.body == "status"
            begin
              @communal.send( status_message )
            rescue StandardError => e
              puts e
            end
          elsif m.body == "quit"
            @state = :exit
            @mainloop.wakeup
          elsif m.body =~ /^current: (.+)/
            if notself(m.from.resource)
              @others[m.from.resource] = $1
            end
          elsif m.body =~ /^tasks (\d+) (\d+) (\d+) (\d+)/
            if $1.to_i > @tasks[:timestamp]
              puts "Time to figure out new task organization"
              @tasks[:timestamp] = $1.to_i
              @tasks[:task1] = $2
              @tasks[:task2] = $3
              @tasks[:task3] = $4
              @communal.send( status_message )
              @scheduleq << [Time.now.to_i + rand(10), :changetask]
            end
          elsif m.body == "tasks?"
            if Time.now.to_i - @lasttasks >= 45 and notself(m.from.resource)
              @communal.send( tasks_message )
              @lasttasks = Time.now.to_i
            end
          else
            case @state
            when :idle
            when :busy
            else
            end
          end
        end
      end }
    @communal.add_join_callback { |m| safe_block("communal", m) do
      end }
    @communal.add_leave_callback { |m| safe_block("communal", m) do
        if notself(m.from.resource)
          @others.delete(m.from.resource)
        end
      end }
    @state = :idle
    @communal.join(Jabber::JID.new('gaoh-communal@conference.corgalabs.com/' + @jid.node))
    @scheduleq << [Time.now.to_i, :recheck]
  end

  def run
    if @config[:regonly]
      puts "Only registering"
      exit 0
    end
    while true
      case @state
      when :init
        enter_communal
      when :idle
      when :exit
        # cleanup
        # Lead all the rooms on a good standing
        return
      end
      Thread.stop
    end
  end

end

if ARGV.size > 0
  gw = GaohWorker.new( ARGV[0] )
  gw.run
else
  puts "No config"
  exit -1
end
