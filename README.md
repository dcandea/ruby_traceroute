###ruby_traceroute
ruby_traceroute is a poor & naive traceroute just for my Net Dev homework.

---

###Usage:
```
  ruby traceroute.rb [dest_addr|host] [options] <parameters>+
  sample: ruby traceroute.rb google.com
where [options] are:
    --max-ttl, -m <i>:   Set the max time-to-live (max number of hops) used in outgoing probe packets. default: 64 (default: 64)
  --first-ttl, -f <i>:   Set the initial time-to-live used in the first outgoing probe packet. default: 1 (default: 1)
  --pack-size, -p <i>:   Set the outgoing probe packet's size in byte. default: 0 byte, max: 512 (default: 0)
       --port, -o <i>:   Protocol specific. For UDP and TCP, sets the base port number used in probes default:33434 (default: 33434)
        --version, -v:   Print version and exit
           --help, -h:   Show this message
```
