#!/bin/env ruby

require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/muc'
require 'logger'
require 'yaml'

class MyFormatter < Logger::Formatter
  def call(severity, time, program_name, message)
    "MESSAGE #{time.to_i}\n" + YAML.dump(message)
  end
end

# Build a Logger::Formatter subclass.
class PrettyErrors < Logger::Formatter
  # Provide a call() method that returns the formatted message.
  def call(severity, time, program_name, message)
    if severity == "ERROR"
      datetime      = time.strftime("%Y-%m-%d %H:%M")
      print_message = "!!! #{String(message)} (#{datetime}) !!!"
      border        = "!" * print_message.length
      [border, print_message, border].join("\n") + "\n"
    else
      super
    end
  end
end

class GaohTranscriber

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

    @jid = Jabber::JID.new(@config[:jid])
    @xmpp = Jabber::Client.new(@jid)
    @xmpp.connect('corgalabs.com')
    @xmpp.auth(@config[:password])
    @setup = true

    if not @setup
      puts "Unable to setup"
      exit -4
    end

    @mainloop = Thread.current
    @worker   = Thread.new {
    }
    @communal = nil
    @tasks    = {}

    @loggers  = {
      :communal => Logger.new('logs/communal', 100, 1024000),
      #:communal => Logger.new(STDOUT)
    }
    @loggers[:communal].formatter = MyFormatter.new

  end

  def status_message
    Jabber::Message.new( nil, @state.to_s )
  end

  def safe_block(message=nil, *args)
    begin
      yield *args
    rescue StandardError => e
      puts "safe_block: #{e}"
      puts "  #{e.backtrace.join("\n  ")}"
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
          @loggers[:communal].info({
            :from    => m.from.resource,
            :body    => m.body,
          })
        end
      end }
    @communal.add_join_callback { |m| safe_block("communal", m) do
        if m.x.nil?
        end
      end }
    @communal.join(Jabber::JID.new('gaoh-communal@conference.corgalabs.com/' + @jid.node))
  end

  def run
    enter_communal
    Thread.stop
  end

end

if ARGV.size > 0
  gw = GaohTranscriber.new( ARGV[0] )
  gw.run
else
  puts "No config"
  exit -1
end
