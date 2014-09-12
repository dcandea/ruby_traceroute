require 'timeout'
require 'socket'
include Socket::Constants
require 'json'
require 'timeout'

class Traceroute
  def initialize(destaddr=nil, max_ttl=nil,first_ttl=nil,pack_size=nil,port=nil)
    @pkt = Hash.new
    @pkt[:destaddr] = destaddr
    @pkt[:max_ttl] = @max_ttl.nil? ? 32 : max_ttl       # "Set the max time-to-live (max number of hops) used in outgoing probe packets. default: 64"
    @pkt[:first_ttl] = @first_ttl.nil? ? 1 : first_ttl  # "Set the initial time-to-live used in the first outgoing probe packet. default: 1"
    @pkt[:pack_size] = @pack_size.nil? ? 0 : pack_size  # "Set the outgoing probe packet's size in byte. default: 0 byte"
    @pkt[:port] = @port.nil? ? 33434 : port               # "Protocol specific. For UDP and TCP, sets the base port number used in probes default:33434"
    
    @path = {}
    @verbose = false    
  end
  
  def verbose=(arg=false)
    @verbose = arg==true ? true : false
  end
  
  def setaddr=(addr)
    @pkt[:destaddr] = addr
  end
  
  def comments=(desc)
    @path[:comments] = desc
  end
  
  def dnsname=(desc)
    @path[:dnsname] = desc
  end
  
  def print(pretty=nil)
    puts pretty.nil? ? "#{@path}":JSON.pretty_generate(@path,:max_nesting => @pkt[:max_ttl].to_i + 10)
  end
  
  def getpath
    @path
  end
  
  def getfinaldest
    @pkt[:destaddr]
  end
  
  def self.getifip
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
    UDPSocket.open do |s|
      s.connect '1.1.1.1', 1
      s.addr.last
    end
  ensure
    Socket.do_not_reverse_lookup = orig
  end
  
  TRACEROUTE=`which traceroute`.chomp
    
  def traceroute
    `#{TRACEROUTE} -m #{@pkt[:max_ttl]} -n #{@pkt[:destaddr]} -q 1|grep -v 'traceroute to'`
  end
  
  def run
    raise "Destination address can not be empty!" if @pkt[:destaddr].nil?
    #addr = Socket.getaddrinfo(@pkt[:destaddr], nil)[0][2]
    max_hops = @pkt[:max_ttl]
    pack_size = @pkt[:pack_size]
    ttl = @pkt[:first_ttl]
    port = @pkt[:port]
    msg = Array.new(pack_size){'a'}.join()    
    myip = Traceroute.getifip
    p = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc)  }
    p = { myip => {} }
    keys = ["#{myip}"]
        
    Timeout::timeout(120) do
      var = traceroute.split("\n")
      puts var unless !@verbose
      var.each do |line|
          addr,ttl,rtt = "",0,0
          puts line unless !@verbose
          if line.match(/^\s?(\d{1,2})\s*(\*)$/)
            addr = $2
            ttl =$1
          else
            line.match(/^\s?(\d{1,2})\s*((?:[0-9]{1,3}\.){3}[0-9]{1,3})\s*([0-9]*\.?[0-9]*) ms$/)
            addr = $2
            ttl =$1
            rtt = $3
          end
          puts "#{ttl}\t (#{addr})\t#{rtt} ms" unless !@verbose
          keys.inject(p) {|h, k| h[k] }[addr] = {}
          keys.inject(p) {|h, k| h[k] }[:ttl] = ttl
          keys.inject(p) {|h, k| h[k] }[:rtt] = rtt
          keys.push("#{addr}")
      end
    end rescue nil
    
    #@path = { time:Time.now , comments: '', dnsname: Socket.getnameinfo(["AF_INET", 80, @pkt[:destaddr]])[0], path: p }
    @path = { time: Time.now.iso8601 , comments: '', dnsname: '', path: p }
      
  end
end
