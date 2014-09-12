require 'graphviz'
require 'ipaddr'

class Gengraph 
  def initialize(title,id,usebin="dot")
    if usebin == 'twopi'
      @g = GraphViz::new(title, :use => usebin, :ratio => 'auto')
      @g[:concentrate] = true
      @g[:splines] = true
      @g[:overlap] = "scale"
    elsif usebin == 'sfdp'
      @g = GraphViz::new(title, :use => "sfdp", :ratio => 'auto')
      @g[:concentrate] = true
      @g[:overlap] = "scale"
    else  
      @g = GraphViz::new(title, :type => :digraph, :use => usebin)
      @g[:rankdir] = "LR"
      @g[:concentrate] = true
    end       
        
    @g.node[:color]    = "#ddaa66"
    @g.node[:style]    = "filled"
    @g.node[:shape]    = "plaintext"
    @g.node[:penwidth] = "1"
    @g.node[:fontname] = "Trebuchet MS"
    @g.node[:fontsize] = "15"
    @g.node[:fillcolor]= "#ffeecc"
    @g.node[:fontcolor]= "#775500"
    @g.node[:margin]   = "0.0"
    @g.node[:shape]    = "oval"
    @g.edge[:color]    = "#999999"
    @g.edge[:weight]   = "1"
    @g.edge[:fontsize] = "6"
    @g.edge[:fontcolor]= "#444444"
    @g.edge[:fontname] = "Verdana"
    @g.edge[:dir]      = "forward"
    @g.edge[:arrowsize]= "0.5"
    @g.edge[:penwidth] = "2"
    @last = ''
    @counter = 0
  end
  
  def resetcounter
    @counter = 0
  end
  
  def incrementcounter
    @counter =+ 1
  end
  
  def write(file='./graph')
    @g.output(:svg => file)
    #@g.output(:dot => "test.dot") 
  end
  
  def addnode(node)
    @g.add_nodes(node)
  end      
  
  def addedge(nleft,nright)
    @g.add_edges(nleft,nright)
  end      
  
  def addpath(hashr, destaddr=nil,ipmask=nil,prevnode=nil)
    hashr.to_hash.each do |k,v|
      if v.is_a? Hash and !v.empty? then
                
        @last = v.keys.first.to_s        
        node = "#{k}"
        nleft = node
        nright = v.keys.first.to_s
        id = nleft + "-" + nright    
        is_edge = false
        ttl = v[:ttl]
        rtt = v[:rtt].to_f
        
        @g.each_edge.each do |enum|      
            if enum[:id].to_s == "\"#{id.to_s}\"" then 
                is_edge=true
                #rtt1 = enum[:label].to_s[/RTT: (.*)/,1]
                #rtt =+ rtt1.to_f
                #puts "#{id}: RTT: #{rtt}"
            end    
        end
        
        prevnode = k
        if "#{k}" != "*" and v.keys.first.to_s == "*"
          nright = "*_#{@counter}"          
        elsif "#{k}" != "*" and "#{prevnode}" == "*" then
          nleft = "*_#{@counter}"    
        elsif "#{k}" == "*" and v.keys.first.to_s != "*"
          node = "*_#{@counter}"
          nleft = node
          self.incrementcounter                  
        end
        
        addpath(v,destaddr,ipmask,prevnode)
        
        if !("#{k}" == "*" and v.keys.first.to_s == "*")
          subnetnode = false
          if ("#{v.keys.first.to_s}" == "#{destaddr}") and !ipmask.nil?
            ipaddr = IPAddr.new("#{destaddr}/#{ipmask}")
            nright = "#{ipaddr.to_range.first.to_s}/#{ipmask}"
            subnetnode = true      
          end
          id = nleft + "-" + nright
          gn = @g.add_nodes(node, :id => id)            
          gn.label = "*" unless "#{k}" != "*"
          if rtt == 0.0 or rtt.nil? or "#{prevnode}" == "*"  
            @g.add_edges(nleft,nright, :id => id)
            prevnode = nil    
          else
            @g.add_edges(nleft,nright, :id => id) unless !subnetnode
            @g.add_edges(nleft,nright, :id => id, :label => "TTL: #{ttl}\nRTT: #{rtt}") unless is_edge or subnetnode
          end  
        end
      end
=begin
        if "#{k}" == "*" and v.keys.first.to_s == "*"
          node = "*_#{v[:ttl].to_i - 1}_#{destaddr}"
          nleft = node
          nright = "*_#{v[:ttl]}_#{destaddr}"
        elsif v.keys.first.to_s == "*" then
          node = "*_#{v[:ttl]}_#{destaddr}"
          nright = "*_#{v[:ttl]}_#{destaddr}"
        elsif "#{k}" == "*"
          node = "*_#{v[:ttl].to_i - 1}_#{destaddr}"
          nleft = node
        end  
        id = nleft + "-" + nright
        
        gn = @g.add_nodes(node, :id => id)
        gn.label = "*" unless "#{k}" != "*"
        @g.add_edges(nleft,nright, :id => id, :label => "TTL: #{v[:ttl]}\nRTT: #{v[:rtt]}") unless is_edge 
        end
=end
    end
  end
end
