require 'rubygems'
require 'optparse'
require 'win32/eventlog'
require 'ruport'
require 'net/smtp'
require 'mailfactory'
require 'socket'

# Set defaults
options ={}
options[:days] = 1
options[:types] = ['error','warning']
options[:logs] = ['Application', 'Security', 'System']
options[:mail_to] = ''
options[:mail_from] = "noreply@#{Socket.gethostname}"
options[:mail_subject] = "#{Socket.gethostname}: Log extract"
options[:mail_server] = ''
options[:mail_port] = 25

# Parse options
OptionParser.new do |opts|
	
	opts.banner = "Usage: #{$0} [-dtfsp] -T <someone@somewhere> -S <smtp_server>"
	
	opts.on("-T <someone@somewhere>", String,
	"Mail address to send the report to (Mandatory)") do |v| 
		(puts "Incorrect email address format"; puts opts; exit 1) unless v.match(/[\w\.]+@[\w\.]+/)
		options[:mail_to] = v
	end
	
	opts.on("-S <smtp_server>", String,
	"Smtp server to send the mail through (Mandatory)") do |v|
		options[:mail_server] = v
	end
	
	opts.on("-d <days>",	Integer,
	"How many days in the past should we look at (defaults to #{options[:days]})") do |v|
		options[:days] = v.abs
	end
	
	opts.on("-l <log>[,<log>]", Array,
	"Which event-log files should we look at (defaults to #{options[:logs].join(',') })") do |v|
		options[:logs] = v
	end
	
	opts.on("-t <type>[,type]", Array,
	"What type of events should we look at (defaults to #{options[:types].join(',')})") do |v|
		options[:types] = v
	end
	
	opts.on("-f <someone@somewhere>", String,
	"Mail address to send the report from (defaults to #{options[:mail_from]})") do |v| 
		(puts "Incorrect email address format"; puts opts; exit 1) unless v.match(/[\w\.]+@[\w\.]+/)
		options[:mail_to] = v
	end
	
	opts.on("-s <subject>", String,
	"Subject of the report email to send (defauls to \"#{options[:mail_subject]}\")") do
		|v| options[:mail_subject] = v
	end
	
	opts.on("-p <port>",	Integer,
	"Port of the smtp server to send the mail through (defaults to #{options[:mail_port]})") do |v|
		options[:mail_port] = v.abs
	end
	
	opts.parse! rescue (puts opts; exit 1)
	
	# Make sure the mandatory options have been set
	if options[:mail_to] == '' or options[:mail_server] == ''
		puts opts
		exit 1
	end
	
end	


# Create a ruport table
table = Table(['Log File',
'Record Number',
'Time',
'Event ID',
'Event Type',
'Source',
'User',
'Description'])

# Define needed variables from options
base_date = Time.now - options[:days]*24*60*60
type_regexp = /#{options[:types].join('|')}/

# Parse the event logs and fill in the table
options[:logs].each do |logfile|
	Win32::EventLog.new(logfile) do |log|
		log.read() do |event|
			next unless
				event.event_type.match(type_regexp) and
				(event.time_generated <=> base_date) == 1
			table << { 'Log File' => logfile,
			'Record Number' => event.record_number,
			'Time' => event.time_generated.strftime('%Y-%m-%d %H:%M'),
			'Event ID' => event.event_id,
			'Event Type' => event.event_type.capitalize,
			'Source' => event.source,
			'User' => event.user,
			'Description' => event.description }	
		end
	end
end


# Group by type (warning, error)
grouping = Ruport::Data::Grouping.new(table, :by => 'Event Type')

# Prepare an email
mail = MailFactory.new()
mail.date = Time.now
mail.to, mail.from, mail.subject = options.values_at(:mail_to, :mail_from, :mail_subject)

# Redefine the table header of ruport's HTML formatter to add borders to the table
# WARNING: This is probably not the proper way to do it
class Ruport::Formatter::HTML < Ruport::Formatter    
	def build_table_header
		output << "\t<table border='1'>\n"
		unless data.column_names.empty? || !options.show_table_headers
			output << "\t\t<tr>\n\t\t\t<th>" + 
			data.column_names.join("</th>\n\t\t\t<th>") + 
			"</th>\n\t\t</tr>\n"
		end
	end
end
    
# Include the report as html
mail.html = grouping.to_html

# Send the email
Net::SMTP.start(options[:mail_server], options[:mail_port],  Socket.gethostname) do |smtp|
	smtp.send_message(mail.to_s, options[:mail_from], options[:mail_to])
end




