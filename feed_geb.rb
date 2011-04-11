#!/bin/env ruby

require 'optparse'
require 'rubygems'
require 'mysql'

# Set defaults
options = {}
options[:dl] = ''
options[:db_server] = ''
options[:db_port] = 3306
options[:db_user] = ''
options[:db_passwd] = ''
options[:db_name] = 'phplist'

# Parse options
OptionParser.new do |opts|

	opts.banner = "Usage: #{$0} <options>"

	opts.on("-d <distribution-list@domain>", String,
	"Distribution list to feed") do |v|
		(puts "Error: Incorrect format for the distribution list"; puts opts; exit 1) unless v.match(/[\w\.]+@[\w\.]+/)
		options[:dl] = v
	end

	opts.on("-s <db_server_hostname>", String,
	"DB server to fetch information from") do |v|
		options[:db_server] = v
	end

	opts.on("-p <db_port>", Integer,
	"Port on which the DB server is listening") do |v|
		options[:db_port] = v
	end

	opts.on("-u <db_user>", String,
	"User to access the DB with") do |v|
		options[:db_user] = v
	end

	opts.on("-P <db_password>", String,
	"Password for the DB user") do |v|
		options[:db_passwd] = v
	end

	opts.on("-n <db_name>", String,
	"Name of the DB to connect to") do |v|
		options[:db_name] = v
	end

	opts.parse! rescue (puts opts; exit1)

	# Make sure all options are set
	options.each do |key, value|
		if value == ''
			puts "Error: #{key} is not set"
			puts opts
			exit 1
		end
	end
end

# Set up the connection to the DB
my = Mysql.connect(options[:db_server], options[:db_user], options[:db_passwd], options[:db_name])

# Get the data and prepare zmprov arguments
zmprov_args = "adlm #{options[:dl]}"
my.query("select email from phplist_user_user where disabled=0").each do |email|
	zmprov_args << ' '
	zmprov_args << email.to_s
end

# Purge the mailing list of its members
IO.popen("/opt/zimbra/bin/zmprov gdl #{options[:dl]} zimbraMailForwardingAddress", "r") do |output|
	threads = []
	output.each do |line|
		next unless line.match(/zimbraMailForwardingAddress: (\S+)/)
		threads << Thread.new($1) do |email|
			IO.popen("/opt/zimbra/bin/zmprov rdlm #{options[:dl]} #{email}", "r") 
		end
	end
	threads.each { |t| t.join(0) }
end

# Give some time for the above zmprov commands to finish their job
sleep 3

# Run the zmprov command with the prepared arguments
IO.popen("/opt/zimbra/bin/zmprov #{zmprov_args}", "r")



