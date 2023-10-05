#!/usr/bin/ruby
#######################################################################
#
# tellthetale.rb: the script to generate the image files to be shown
#                 by the epicdiff application proper.
#
#######################################################################
#
# epicdiff - diffs of epics, in an epic manner
# Copyright (C) 2010  Urpo Lankinen
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 
#######################################################################

require 'rexml/document'
require 'time'

require 'rubygems'
gem     'rmagick', '>=2.13'
require 'RMagick'
include Magick

# COLORS USED TO MARK ADDITIONS
#                    X11 name      values from rgb.txt
# Added text:        DeepSkyBlue     0 191 255
ADDED     = 'DeepSkyBlue'
ADDED_COL = "#%02x%02x%02x" % [0,191,255]
# Deleted text:      HotPink       255 105 180
DELETED     = 'HotPink'
DELETED_COL = "#%02x%02x%02x" % [255,105,180]
# Changed text, old: yellow        255 255   0
CHANGED_OLD     = 'yellow'
CHANGED_OLD_COL = "#%02x%02x%02x" % [255,255,0]
# Changed text, new: green           0 255   0
CHANGED_NEW     = 'green'
CHANGED_NEW_COL = "#%02x%02x%02x" % [50,205,50]
# ...the thing SAYS it can be Lime (50,205,50), but wkhtmltopdf spits
# out lots of green pixels. Presumably because it's spelt "LimeGreen" in
# rgb.txt and not "Lime". Eep.

$outputdir = ARGV.shift or '.'
$gitsplodesummary = $outputdir + '/summary.xml'
$difftemphtml = $outputdir + '/diff.html'
$difftemppdf = $outputdir + '/diff.pdf'

unless File.writable?($outputdir)
  fail "Output directory #{$outputdir} cannot be written to"
end
unless File.exists?($gitsplodesummary)
  fail "Can't find gitsplode summary file #{$gitsplodesummary}"
end
unless File.readable?($gitsplodesummary)
  fail "gitsplode summary file #{$gitsplodesummary} isn't readable"
end

# Slurp in the summary file.
$gitsplodesummary = REXML::Document.new(File.open($gitsplodesummary,"r"))


# Start up the summary document
$summarydoc = REXML::Document.new <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<revisions>
</revisions>
EOF

# I was originally going to compare the file to /dev/null, docdiff
# refuses to compare the file to a "non-file". So let's create a temporary
# empty file.
previousfile = $outputdir+'/ex_nihilo.txt'
unless File.exists?(previousfile)
  emptyfile = File.open(previousfile,'w')
  emptyfile.printf("\n") # docdiff is rather picky about line endings too.
  emptyfile.close
end

$gitsplodesummary.elements['/commitdata'].each_child do |e|
  # FIXME: Ungraceful -- dare I say disgraceful -- child handling.
  # We're only interested of <commitdata> subelements, which are <commit>s.
  next unless e.class == REXML::Element
  # Grab the commit data from XML
  commit_id = e.attributes['id']
  filename = $outputdir + '/' + e.elements['filename'].text
  date = Time.parse(e.elements['date'].text)
  date_unix = e.elements['date'].attributes['unix']
  message = e.elements['message'].text

  # Make a new XML tag, and fill up the new summary XML with that information.
  c = REXML::Document.new '<revision></revision>'

  c.elements['/revision'].attributes['id'] = commit_id
  c.elements['/revision'].attributes['date'] = date
  c.elements['/revision'].attributes['unix'] = date_unix
  c.elements['/revision'].attributes['message'] = message

  # Get the filename trunk and extension
  if filename =~ /\.([^\.]+)$/
    filenameprefix = File.basename(filename,"#{$1}")
    filenamesuffix = ".#{$1}"
  else
    filenameprefix = filename
    filenamesuffix = ""
  end

  # Produce the diff.
  system("docdiff --format=html --utf8 '#{previousfile}' '#{filename}' > '#{$difftemphtml}'")
  # Convert the resulting HTML to PDF.
  system("wkhtmltopdf -q '#{$difftemphtml}' '#{$difftemppdf}'")
  # Delete the HTML file.
  File.delete($difftemphtml)

  # Convert the PDF to image files, and produce page summary data. This
  # involves some image conversion with RMagick and some other weird stuff.

  # Figure out output filename base
  outfnbase = "#{$outputdir}/#{filenameprefix}"
  # Slurp the PDF file in!
  imgs = ImageList.new($difftemppdf)
  # Process each page...
  for i in (0..imgs.length-1) do
    # New XML tag that stores page info
    p = REXML::Document.new '<page/>'  
    ptag = p.elements['/page']

    # WORKAROUND: We save the file in PseudoColor 256c. This is easy
    # if we just say "format = 'PNG8'". *But*, and this is the big
    # but, if we save as ".png", it gets automatically converts the
    # file to truecolor again, presumably for "convenience".  To
    # ensure correct format, we need to leave file extension out or
    # save as ".png8", which other apps don't necessarily understand.
    # (Ruby GD2 went spare, for example.) So here we go with the
    # former path and save to file with no filename extension, and
    # then we rename the file.  This should make the thing work no
    # matter what.

    # Output filename is in format foo.001.png
    outfn = sprintf("%s%03d",outfnbase,i+1)
    # Convertate!
    imgs[i].format = "PNG8"
    # Grab image width and height
    ptag.attributes['width'] = imgs[i].columns
    ptag.attributes['height'] = imgs[i].rows
    # Save and rename the file.
    imgs[i].write(outfn)
    File.rename(outfn,"#{outfn}.png")
    # More metadata!
    ptag.attributes['filename'] = File.basename("#{outfn}.png")
    ptag.attributes['pageno'] = i+1
    # Now the clever part:
    # Scan the image colormap for the color values that indicate that
    # something has been done to the page in question.
    for j in (0..imgs[i].colors-1)
      col = imgs[i].colormap(j)
      case col
      when ADDED           then ptag.attributes['added'] = 'added'
      when ADDED_COL       then ptag.attributes['added'] = 'added'
      when DELETED         then ptag.attributes['deleted'] = 'deleted'
      when DELETED_COL     then ptag.attributes['deleted'] = 'deleted'
      when CHANGED_OLD     then ptag.attributes['old'] = 'old'
      when CHANGED_OLD_COL then ptag.attributes['old'] = 'old'
      when CHANGED_NEW     then ptag.attributes['new'] = 'new'
      when CHANGED_NEW_COL then ptag.attributes['new'] = 'new'
      end
    end
    # Save the page's metadata in the revision metadata.
    c.elements['/revision'] << p
  end

  # Done with the PDF, so delete it
  File.delete($difftemppdf)

  # Some more metadata:
  # How many pages were there?
  c.elements['/revision'].attributes['pagecount'] = imgs.length
  # ...errr, how many words there were? (I *could* have used my word
  # count library for this purpose, but I didn't really have
  # time. Besides, I always worked with the same definition of words
  # as the *nix* wc(1) tool.)
  words = (`wc -w '#{filename}'`.chomp.split)[0].to_i
  c.elements['/revision'].attributes['wordcount'] = words

  # Finally, put the revision's metadata to the summary document.
  $summarydoc.elements["/revisions"] << c

  # We're done with this file, so this becomes the previous file now.
  previousfile = filename
end

# Save page summary XML.
File.open("#{$outputdir}/page_summary.xml","w") do |f|
  f.puts($summarydoc)
end
# Get rid of the empty file.
File.delete($outputdir+'/ex_nihilo.txt')
