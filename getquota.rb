#!/bin/env ruby

require 'optparse'


class Array

  def get_max_size
    return self.inject(0) {|memo, v | memo > v.to_s.length ? memo : v.to_s.length}
  end

end


class App

  def initialize(arguments)

    @arguments = arguments

    # Set default options
	@options = {}
	@options[:user] = 'all'
	@options[:details] = false
	@options[:top] = 0
	@options[:server] = 'zimbra'

  end


  def parse_options!

    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
	  opts.on("-u <username>/all", String, "Username for which to print quota (defaults to all)") {|v| @options[:user] = v}
	  opts.on("-d", "Query and show additional information for each account checked (defaults to disabled)") {@options[:details] = true} 
	  opts.on("-t <n>", Integer, "Restrict the query to the top <n> users (defaults to 0, or no limit)") {|v| @options[:top] = v}
          opts.on("-s <server>", String, "Server to query (defaults to 'zimbra')") {|v| @options[:server] = v}
	  opts.parse! rescue (puts opts; exit 1)
	end

  end


  def get_status(account)

    value = ""
    IO.popen("zmprov ga #{account} zimbraAccountStatus") do |output|
      output.each do |line|
	    next unless line.match(/zimbraAccountStatus: (\w+)/)
		value = $1
      end
	end
	return value

  end


  def fill_hash!

	# Fill hash @quotas 
	@quotas = {}
    IO.popen("zmprov gqu #{@options[:server]}", "r") do |output|
	   output.each do |line|
	     next unless line.match(/(\S+) (\d+) (\d+)/) and $2.to_i != 0
		 next unless $1 == @options[:user] or @options[:user] == 'all'
		 @quotas[$1] = []
	     @quotas[$1][0] = $3.to_i*100/$2.to_i
		 @quotas[$1][1] = ($3.to_i/(1024**2)).to_s + '/' + ($2.to_i/(1024**2)).to_s
	   end
	end

	# Keep only the top users if needed
	if @options[:top] != 0
	  # Sort the hash and get the top names
      kept_names = (@quotas.sort {|x,y| y[1][0] <=> x[1][0]}).first(@options[:top]).collect {|v| v[0]}
	  # Delete every entry in the hash which is not in kept_names
	  @quotas.delete_if {|key, value| not kept_names.include?(key)}
	end

	# Get details if needed
	if @options[:details]
      @quotas.each_key {|key| @quotas[key][2] = get_status(key)}
	end

  end


  def print_quota!

   space = 4
   width = []
   width[0] = @quotas.keys.get_max_size + space
   for i in 1..3 do
     width[i] = (@quotas.values.collect {|v| v[i-1]}).get_max_size + space
   end

   (@quotas.sort {|x,y| y[1][0] <=> x[1][0]}).each do |value|
     printf("%-1$*2$s %3$*4$s\%", value[0], width[0], value[1][0], width[1])
     printf("%1$*2$sMB", value[1][1], width[2])
     printf("%1$*2$s", value[1][2], width[3]) if @options[:details]
	 print("\n")
   end

  end


  def run
    parse_options!
	fill_hash!
    print_quota!
  end

end

app = App.new(ARGV)
app.run
