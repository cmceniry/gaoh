#!/usr/bin/env ruby

require 'rubygems'
require 'xmpp4r/client'
require 'yaml'

class GaohCentral
  include Jabber

  def initialize
    @config = YAML.load_file("config")
    @jid = @config["username"]
    @password = @config["password"]
    @cl = Client.new(@jid)
    @cl.connect("corgalabs.com")
    @cl.auth(@password)
    @cl.send(Presence.new())
    sleep 5
    @cl.close!
  end

end

GaohCentral.new

