#!/usr/bin/env ruby

require 'rubygems'
require 'nmap/parser'
require 'net/ssh/multi'
require 'optparse'

class App

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin

    # Set defaults
    @options = {}
    @options[:targets] = [
		"10.2.11.51-189",
		"10.3.13.51-189",
		"10.4.15.51-189",
		"10.2.17.51-189",
		"10.2.19.51-189",
		"10.2.21.51-189",
		"10.3.23.51-189",
		"10.2.25.51-189",
		"10.2.27.51-189",
		"10.3.29.51-189",
		"10.1.31.51-189",
		"10.3.33.51-189",
		"10.3.35.51-189",
		"10.2.37.51-189",
		"10.3.39.51-189",
		"10.1.41.51-189",
		"10.1.43.51-189",
		"10.1.45.51-189",
		"10.1.47.51-189",
		"10.4.49.51-189",
		"10.4.51.51-189",
		"10.4.53.51-189",
		"10.4.55.51-189",
		"10.2.57.51-189",
		"10.1.59.51-189",
		"10.2.61.51-189",
		"10.2.63.51-189",
		"10.2.65.51-189",
		"10.2.67.51-189",
		"10.2.69.51-189",
		"10.2.71.51-189",
		"10.1.73.51-189",
		"10.1.75.51-189",
		"10.1.77.51-189",
		"10.1.79.51-189"
		]
    @options[:command] = 'hostname'
    @options[:loop_nb] = 1
    @options[:delay] = 1
    @options[:fresh] = false
    @options[:quiet] = false
    @options[:max] = 0
    @options[:ssh_version] = /Debian/
  end


  def parse_options!
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.summary_width = 20 
      opts.on("-t STRING[,STRING]", Array, "Network target(s) (nmap syntax) to scan for usable hosts (implies -f)") do |v|
        @options[:targets] = v 
        @options[:fresh] = true
      end
      opts.on("-c STRING", "Specifiy the command to be run on remote hosts") { |v| @options[:command] = v }
      opts.on("-l INT", Integer, "Number of loops") { |v| @options[:loop_nb] = v }
      opts.on("-d FLOAT", Float, "Delay between each loop in seconds") { |v| @options[:delay] = v }
      opts.on("-f", "Perform a fresh scan instead of relying on previous log file") { @options[:fresh] = true }
      opts.on("-q", "Do not relay stdout from the hosts") { @options[:quiet] = true }
      opts.on("-m INT", Integer, "Maximum number of hosts to use") { |v| @options[:max] = v }
      opts.on("-s STRING", Regexp, "SSH version for the host to match to be considered usable (regexp)") { |v| @options[:ssh_version] = v }
      opts.define_tail("\nDefaults to => #{$0}" + \
	" -c '#{@options[:command]}'" + \
	" -l #{@options[:loop_nb]}" + \
	" -d #{@options[:delay]}" + \
	" -s '#{@options[:ssh_version].source}'")
      opts.parse! rescue (puts opts; exit 1)
    end
  end


  def run

    parse_options!

    # Check if we should do a fresh scan or use an existing xml log file
    if not @options[:fresh] and File::exist?("log.xml")
      puts "Using existing log.xml - Remove it manually or use -f if you want to start with a fresh scan"
      parser = Nmap::Parser.parsefile("log.xml")
    else
      puts "Scanning for usable hosts and saving the result to log.xml"
      parser = Nmap::Parser.parsescan("sudo nmap", "-sV -sT -p 22 -T aggressive", @options[:targets])
      File::open("log.xml","w") do |file|
        file << parser.rawxml
      end
    end

    # Build an array of hosts matching the ssh version regexp
    usable_hosts = parser.hosts("up").select do |host|
      host.getport(:tcp, 22).service.version =~ @options[:ssh_version] if host.getport(:tcp, 22)
    end

    if usable_hosts.size == 0
      puts "No usable host could be found, sorry"
      exit
    end

    # Crop the array if needed
    if @options[:max] > 0
      usable_hosts = usable_hosts.shuffle.take(@options[:max])
      # Re-sort the array for reading convenience
      usable_hosts.sort! { |a, b| a.ip4_addr <=> b.ip4_addr }
    end

    puts "A total of #{usable_hosts.size} hosts will be used"
    puts ""
    puts "The command is ready to be executed as specified:"
    puts "Command: #{@options[:command]}"
    puts "Number of loops: #{@options[:loop_nb]}"
    puts "Delay: #{@options[:delay]}"
    print "Press Enter to proceed (or Ctrl-C to abort):" 
    begin
      gets 
    rescue Interrupt
      puts "\nExecution Aborted"
      exit 1
    end

    # Go ahead with the loop, creating a thread per connection
    threads = []
    @options[:loop_nb].times do |i|
      puts "Starting loop \##{i+1}"
      usable_hosts.each do |host|
        threads << Thread.new(host) do |this_host|
          Net::SSH.start(this_host.ip4_addr, 'root', :timeout => 2) do |ssh|
            ssh.exec!(@options[:command]) do |ch, stream, data|
              puts "[#{this_host.ip4_addr}] #{data}" if stream == :stderr or not @options[:quiet]
            end
          end
        end
      end 
      sleep @options[:delay]  
    end

    # Wait for all the threads to close up 
    threads.each {|t| t.join}

  end

end

app = App.new(ARGV, STDIN)
app.run

