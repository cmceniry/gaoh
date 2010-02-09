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
    @tasks    = {}
    @state    = :init

  end

  def status
    @state.to_s
  end

  def safe_block(message=nil, *args)
    begin
      yield *args
    rescue StandardError => e
      puts "safe_block: #{e}"
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
    # This is used to figure out what work to do
  end

  def enter_communal
    @communal = Jabber::MUC::MUCClient.new(@xmpp)
    @communal.add_message_callback { |m| safe_block("communal", m) do
        # Ignore it if it was sent before I got here
        if m.x.nil?
          puts m.subject, m.body
          if m.body == "status"
            begin
              @communal.send( Jabber::Message.new(nil, status) )
            rescue StandardError => e
              puts e
            end
          else
            if m.subject == "task"
              case m.body
              when "task1"
              when "task2"
              when "task3"
              end
            end
          end
        end
      end }
    @communal.add_join_callback do |m|
      puts m.x
    end
    @state = :incommunal
    @communal.join(Jabber::JID.new('gaoh-communal@conference.corgalabs.com/' + @jid.node))
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
      when :incommunal
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
