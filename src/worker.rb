#!/bin/env ruby

require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/muc'
require 'yaml'

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
    @worker   = Thread.new {
    }
    @communal = nil
    @tasks    = {
      :timestamp => 0,
      :task1     => 0,
      :task2     => 0,
      :task3     => 0,
    }
    @state    = :init
    @others = {}

  end

  def status_message
    Jabber::Message.new( nil, "current: " + @state.to_s )
  end

  def safe_block(message=nil, *args)
    begin
      yield *args
    rescue StandardError => e
      puts "safe_block: #{e}"
    end
  end

  def notself(name)
    name != "gw-" + @jid.resource
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
    # This is used to figure out what work to do
  end

  def enter_communal
    @communal = Jabber::MUC::MUCClient.new(@xmpp)
    @communal.add_message_callback { |m| safe_block("communal", m) do
        # Ignore it if it was sent before I got here
        if m.x.nil?
          if m.body == "dump"
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
          elsif m.body =~ /^current: (\S+)/
            if notself(m.from.resource)
              @others[m.from.resource] = $1
            end
          elsif m.body =~ /^tasks (\d+) (\d+) (\d+) (\d+)/
            if $1.to_i > @tasks[:timestamp]
              puts "Time to figure out new task organization"
              @communal.send( status_message )
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
    @communal.send( status_message )
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
