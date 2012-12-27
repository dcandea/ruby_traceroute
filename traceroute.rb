#!ruby -w
# encoding:UTF-8
#

require 'timeout'
require 'socket'
require './lib/lib_trollop.rb'
include Socket::Constants

opts = Trollop::options do
  version "ruby_tractroute 1.0.0 (c)"
  banner <<-EOS
ruby_traceroute is a poor & naive traceroute just for my Net Dev homework.

Usage:
  ruby_traceroute [dest_addr|host] [options] <parameters>+
  sample: ruby_traceroute google.com
where [options] are:
  EOS
  opt :max_ttl, "Set the max time-to-live (max number of hops) used in outgoing probe packets. default: 64", :default=>64
  opt :first_ttl, "Set the initial time-to-live used in the first outgoing probe packet. default: 1", :default=>1
  opt :pack_size, "Set the outgoing probe packet's size in byte. default: 0 byte, max: 512", :default=>0
  opt :port, "Protocol specific. For UDP and TCP, sets the base port number used in probes default:33434", :default=>33434
end

Trollop::die :pack_size, "should less than 512 bytes" if opts[:pack_size] >= 512

port = opts[:port]
max_hops = opts[:max_ttl]
ttl = opts[:first_ttl]
addr = Socket.getaddrinfo(ARGV[0], nil)[0][2]
pack_size = opts[:pack_size]
msg = Array.new(pack_size){'a'}.join()
puts "traceroute to #{ARGV[0]} (#{addr}), #{max_hops} hops max, #{pack_size} byte packets"
until ttl == max_hops
  begin
    recv_socket = Socket.open(AF_INET, SOCK_RAW, Socket::IPPROTO_ICMP)
    send_socket = Socket.open(AF_INET, SOCK_DGRAM, Socket::IPPROTO_UDP)
    send_socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, ttl)
  rescue Errno::EPERM
    $stderr.puts "Must run #{$0} as root."
    exit!
  end

  sockaddr = Socket.pack_sockaddr_in(port, '')
  recv_socket.bind(sockaddr)
  #send_socket.bind(sockaddr)
  begin
    send_socket.connect Socket.pack_sockaddr_in(port, ARGV[0])
  rescue SocketError => err_msg
    puts "Can't connect to remote host (#{err_msg})."
    exit!
  end

  send_socket.send msg, 0

  begin
    send_time = Time.now
    data, sender = recv_socket.recvfrom(1024)
    recv_time = Time.now
    time_cost = format("%0.3f", (recv_time - send_time) * 1000)
    icmp_type = data.unpack('@20C')[0]
    icmp_code = data.unpack('@21C')[0]
    addr = Socket.unpack_sockaddr_in(sender)[1].to_s
    host = Socket.getnameinfo(["AF_INET", 80, addr])[0]
    puts "#{ttl}\t#{host} (#{addr})\t#{time_cost} ms"

    if icmp_type == 3 && icmp_code == 13 then
      puts "'Communication Administratively Prohibited' from this hop."
      break
    elsif icmp_type == 3 && icmp_code == 3 then
      puts "Destination reached. Trace complete."
      break
    end
  rescue SocketError => err_msg
    puts err_msg
    send_socket.close
    recv_socket.close
    exit!
  end
  ttl += 1
end
send_socket.close
recv_socket.close
