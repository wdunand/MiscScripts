#!/bin/env ruby 

require 'optparse'
require 'zlib'

class App

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    @dirs = []
    @result = {}

    # Set defaults
    @options = {}
    @options[:month_format] = '%y%m'
    @options[:month] = (Time.now - 864000).strftime(@options[:month_format])
    @options[:base] = ''
    @options[:subdirs] = []
    @options[:prefix_regexp] = /ex/
    @options[:suffix_regexp] = /(\d{2})\.log\.gz/
    @options[:pages] = []
  end


  def parse_options!
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.summary_width = 30
      opts.on("-M MONTH-FORMAT", String, "Month format used in the filename (defaults to #{@options[:month_format]})") do |v| 
        @options[:month_format] = v 
        @options[:month] = (Time.now - 864000).strftime(@options[:month_format])
      end
      opts.on("-m MONTH", String, "Month for which to parse logs - format must match MONTH-FORMAT (defaults to the month 10 days ago)") do |v| 
        @options[:month] = v
      end 
      opts.on("-b BASEFOLDER", String, "Base folder containing the logs") { |v| @options[:base] = v }
      opts.on("-s SUBFOLDER[,SUBFOLDER]", Array, "List of subdirectories containing the logs") do |v|
        @options[:subdirs] = v
      end
      opts.on("-p PAGE[,PAGE]", Array, "List of pages to counts hits for") do |v|
        @options[:pages] = v 
      end
      opts.on("-P REGEXP", Regexp, "Regular expression for filenames prefix (defaults to #{@options[:prefix_regexp]})") do |v|
        @options[:prefix_regexp] = v
      end
      opts.on("-S REGEXP", Regexp, "Regular expression for filenames suffix (defaults to #{@options[:suffix_regexp]})") do |v|
        @options[:suffix_regexp] = v
      end
      opts.parse! rescue (puts opts; exit 1)
      options_correct? or (puts opts; exit 1)
    end    
  end


  def options_correct?

    # We only check that no option is empty
    @options.each_value do |v|
      return false if v.to_s == ''
    end

  end


  def run
    
    parse_options!

    # Check the directories are valid
    (@options[:subdirs].collect { |subdir| @options[:base] + '/' + subdir }).each do |subdir|
      unless File.directory?(subdir)
        puts "'#{subdir}' does not seem to be a valid directory, exiting"
        exit 1
      end
      @dirs << Dir.new(subdir)
    end

    # Parse each file matching the month and construct the result hash
    filename_regexp = Regexp.new(@options[:prefix_regexp].source + @options[:month] + @options[:suffix_regexp].source) 
    @dirs.each do |dir|
      dir.each do |filename|
        next unless filename.match(filename_regexp)
        day = $1
        if not @result[day]
          @result[day] = {}
          @options[:pages].each do |page|
            @result[day][page] = 0
          end 
        end
        #Zlib::GzipReader.open(dir.path + '/' + filename) do |file|
        IO.popen("zcat #{dir.path}/#{filename}", 'r') do |file|
          file.each do |line|
            @options[:pages].each do |page|
              begin
                if line.match(/GET #{page}/)
                  @result[day][page] += 1 
                end
              rescue ArgumentError
              end  
            end 
          end  
        end
      end
    end

    # Print the header
    printf("%-15s", "Date")
    width =15 
    @options[:pages].each do |page|
      printf("%1$*2$s", page, page.size + 5)
      width += page.size + 5
    end
    printf("\n#{'-' * width}\n")

    # Parse the result hash and print the lines
    #@result.each_pair do |key, value|
    @result.sort.each do |element|
      printf("%-15s", @options[:month] + '-' + element[0])
      element[1].each_pair do |key, value|
        printf("%1$*2$s", value, key.size + 5)
      end
      printf("\n")
    end
    printf("\n#{'-' * width}\n")

  end

end

app = App.new(ARGV, STDIN)
app.run
