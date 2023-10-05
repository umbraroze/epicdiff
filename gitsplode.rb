#!/usr/bin/ruby
######################################################################
#
# Gitsplode exports the history of a single file from a Git repository
# to a directory.
#
######################################################################
#
# Copyright (c) 2010,2014 Urpo Lankinen
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
######################################################################

require 'optparse'
require 'rexml/document'

$outputdir = Dir.pwd + "/out"
$usage = ""
$before = nil
$after = nil
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] file"
  opts.on("-o", "--output-directory DIRNAME", "Directory to store the files to",
          "  [default: #{$outputdir}]") do |x|
    $outputdir = x
  end
  opts.on("-B", "--before DATE", "Include commits before the specified date.") do |x|
    $before = x
  end
  opts.on("-A", "--after DATE", "Include commits after the specified date.") do |x|
    $after = x
  end
  $usage = opts.to_s
end.parse!
if ARGV.length == 0
  puts $usage
  exit
else
  $filename = ARGV.shift
end

# Date options sanity check
if ((not $before.nil?) and (not $after.nil?))
  puts "ERROR: You can specify either --before or --after but not both."
  puts $usage
  exit(1)
end
$get_all = true
if (not $before.nil?) or (not $after.nil?)
  $get_all = false
end

# OK, does the file exist?
fail "File #{$filename} doesn't exist" unless File.exists?($filename)
fail "File #{$filename} isn't readable" unless File.readable?($filename)

# The extension.
if $filename =~ /\.([^\.]+)$/
  $outprefix = File.basename($filename,"#{$1}")
  $outsuffix = ".#{$1}"
else
  $outprefix = $filename
  $outsuffix = ""
end

# Go to that file's directory. Relevant due to external git tool use.
Dir.chdir(File.dirname($filename))

# What kind of a repository is this?
barerepo = `git config --get 'core.bare'`.chomp
fail "File #{$filename} doesn't seem to reside in a git repository." if barerepo == ""
fail "File #{$filename} doesn't seem to be in a working copy." if barerepo == "true"
# Where the hell is the repository root directory? (Of course, we
# can't do "git show rev:file", we have to do "git show
# rev:full/path/to/file", so we need to know the actual repository
# location. Goddamn it.)
# FIXME: THIS IS A RETARDED METHOD BECAUSE GIT DOESN'T DO STUFF LIKE
# "svn info", WHICH IS FUNNY.
if $filename =~ /^\//
  $fullfilename = $filename
else
  $fullfilename = Dir.pwd + '/' + $filename
end
$repodir = nil
prevdir = Dir.pwd
while Dir.pwd != '/' do
  if File.exists?('.git')
    $repodir = Dir.pwd
    break
  else
    Dir.chdir('..')
  end
end
Dir.chdir(prevdir)
fail "Couldn't find git repository top directory" if $repodir.nil?
$filerelname = $fullfilename
$filerelname.gsub!(/^#{$repodir}\//,'')
fail "OK, my logic in figuring out the relative path name failed." if $filerelname =~ /^\//

dateswitch = ''
unless $get_all
  if not $before.nil?
    dateswitch = "--before=#{$before}"
  elsif not $after.nil?
    dateswitch = "--after=#{$date}"
  else
    fail "Whuh? Before after what? I thought I sorted this out. "+
      "You shouldn't see this."
  end
end
# Get the version history for that file.
$historydata = []
hdata = []
open("| git log -n10000 --pretty=format:'LOG|%H|%ct|%s' #{dateswitch} --name-only --follow --no-merges -- '#{$filename}'") do |file|
  begin
    while f = file.readline.chomp do
      if f =~ /^LOG\|/  # Log entry line
      then
        e = f.split(/\|/,4) # Split at | characters
        hash = e[1]
        mtime = e[2].to_i
        mtimeparsed = Time.at(mtime)
        desc = e[3]
        hdata = [hash,        # hash
                 mtimeparsed, # mtime as Time object
                 mtime,       # mtime as seconds since epoch
                 desc,        # description
                 nil]         # filename
      elsif f !~ /^$/  # Filename (non-empty line)
      then
        hdata[4] = f
      else
        $historydata << hdata
        hdata = []
      end
    end
  rescue EOFError
    # End of file, final entry
    # if the last one isn't in the history data, put it in
    if $historydata.last[0] != hdata[0]
      $historydata << hdata
    end
  end
end

fail "No history entries; is #{$filename} versioned?" if $historydata.length == 0

# Sort the history by date.
$historydata.sort! { |a,b| a[1] <=> b[1] }

# Make the output directory if it doesn't exist already.
if File.exists?($outputdir) and not File.directory?($outputdir) then
  fail "#{$outputdir} exists, and is not a directory."
end
unless File.exists?($outputdir) then
  Dir.mkdir($outputdir) or fail "Couldn't create output directory #{$outputdir}"
end
fail "#{$outputdir} isn't writable." unless File.writable?($outputdir)


# Start up the summary document
$summarydoc = REXML::Document.new <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<commitdata>
</commitdata>
EOF

# Process each history entry
$historydata.each do |e|

  # Figure out a fancy file name
  realoutfile = $outprefix + e[1].strftime("%Y_%m_%d.%H_%M_%S") + $outsuffix

  # Fill up the summary XML
  c = REXML::Document.new <<EOF
  <commit>
    <filename/>
    <date/>
    <message/>
  </commit>
EOF
  c.elements["/commit"].attributes['id'] = e[0]
  c.elements["/commit/filename"].text = realoutfile
  c.elements["/commit/date"].text = e[1]
  c.elements["/commit/date"].attributes['unix'] = e[2]
  c.elements["/commit/message"].text = e[3]
  $summarydoc.elements["/commitdata"] << c

  # Extract the file
  system("git show '#{e[0]}:#{e[4]}' > #{$outputdir}/#{realoutfile}")
  puts "Extracted commit #{e[0]} - #{e[1]} - #{e[3]}"
end

# Save summary data
File.open("#{$outputdir}/summary.xml","w") do |f|
  f.puts($summarydoc)
end

exit
