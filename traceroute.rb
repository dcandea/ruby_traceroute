#!/usr/bin/env ruby

msfbase='./metasploit-framework'
$:.unshift(File.expand_path(File.join(File.expand_path(msfbase), 'lib')))
$:.unshift(File.join(File.dirname(__FILE__), 'lib' ) )

require 'rex'
require 'elasticsearch'
require 'MsfRunMod'
require 'Traceroute'
require 'hashie'
require 'Gengraph'
require 'ipaddr'
require 'pp'
require 'oj'
require 'tire'
require 'yaml'

conf=File.join((File.expand_path File.dirname(__FILE__)), 'config.yml')
raise "File not found! Create config.yml" unless File.exists?(conf)
CONFIG = YAML.load_file(conf) unless defined? CONFIG

index_name = 'netscan'
Tire.index index_name do
    #delete
    create :mappings => {
      :vmware => {
        :properties      => {
          :id            => { :type => 'string', :index => 'not_analyzed', :include_in_all => false },
          :cluster       => { :type => 'multi_field' , :fields => {
                             :cluster => {:type => 'string', :index => 'analyzed' },
                             :raw => {:type => 'string', :index => 'not_analyzed' }}},
          :host          => { :type => "nested", :properties => { 
                             :name        => { :type => 'multi_field' , :fields => { 
                                              :name => {:type => 'string', :index => 'analyzed' },
                                              :raw => {:type => 'string', :index => 'not_analyzed' }}}},
                             :gateway     => {:type => 'string' }},
                             :portgroups  => { :type => "nested", :properties => { :name => { :type => 'string', :index => 'not_analyzed' }}},
          :datastores    => { :type => 'string', :index => 'not_analyzed' },
          :guestInet     => { :type => "nested", :properties => {
                              :macAddress => { :type => 'string', :index => 'not_analyzed' },
                              :IPs => { :type => "nested", :properties => {
                                  :ipAddress => {:type => 'string' }}}}},
          :guestHostname => { :type => 'multi_field' , :fields => { 
                             :guestHostname => {:type => 'string', :index => 'analyzed' },
                             :raw => {:type => 'string', :index => 'not_analyzed' }}},
          #:time          => { :type => 'date', :format => "yyyy-MM-dd HH:mm:ss Z" }
          :time     => { :type => 'date', :format => "dateOptionalTime" },
       }},
      :traceroute => {
         :properties => {
          :id       => { :type => 'string', :index => 'not_analyzed' },
          :time     => { :type => 'date', :format => "dateOptionalTime" },
          :path     => { :type => 'nested', :include_in_parent => true ,:properties => {
                          :ttl => { :type => 'string', :index => 'not_analyzed'},
                          :rtt => { :type => 'string' }
                }
             }
         }
      }   
    }
  end

#args = { module_name: "auxiliary/scanner/portscan/tcp", params: [ "PORTS=443" , "RHOSTS=8.8.8.8"] }
#msfmod = MsfRunMod.new(args)
#msfmod.run!
#puts msfmod.results

ESHOST = 'localhost'
ESPORT = '9200'
es = Elasticsearch::Client.new hosts: [ESHOST+':'+ESPORT], reload_connections: true

trace = Traceroute.new()
hosts = Tire.search 'items',:type => 'host' do 
          size 10000 
          query {all}
        end  

hosts.results.each do |host|  
  if host.type == 'vmware'
    host.guestInet.each do |net|
      net[:IPs].each do |ip|
        ipaddr = IPAddr.new ip[:ipAddress]
        if ipaddr.family == 2
          trace.setaddr=ip[:ipAddress]
          trace.run
          trace.verbose=true
          #trace.print('pretty')
          trace.dnsname=host.guestHostname
          trace.comments="EsxHost: " + host.host.name          
          es.index index: 'netscan', type: 'traceroute', id: ip[:ipAddress], body: trace.getpath
        end
      end unless net[:IPs].nil?
    end unless host.guestInet.nil?
  end
  if not host.scantype.traceroute.nil? and not host.privateIP.nil?
    trace.setaddr=host.privateIP
    trace.run
    #trace.verbose=true
    #trace.print('pretty')
    pp "Traceroute for #{host.privateIP}"
    es.index index: 'netscan', type: 'traceroute', id: trace.getfinaldest, body: trace.getpath
  end
end

hosts = Tire.search 'netscan',:type => 'traceroute' do 
          size 10000 
          query {all}
        end           
g = Gengraph.new("Network topology",'netscan_traceroute','twopi')
hosts.results.each do |element|
      ipmask = nil
      host = Tire.search 'netscan' do query { string element.id } end
      host.results.each do |h|
        h.guestInet.each do |net|
          net.IPs.each do |ip|
            if ip.ipAddress == element.id 
              ipmask = ip.prefixLength
            end  
          end
        end
      end
      g.resetcounter
      g.addpath(element.path,element.id,ipmask)      
end  
g.write(Regexp::escape(CONFIG['SVGPATH']+'netscan_traceroute.svg'))
  
