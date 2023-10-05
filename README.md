# epicdiff - diffs of epics, in an epic manner

> **MAINTENANCE NOTE:** This code was split off from an earlier
> repository, so history stuff is not here. I'm going to eventually
> tidy it up a little bit so that it might run under Processing
> 4 or something.

epicdiff is a app suite for creating illustrative and entertaining
animations out of docdiff-produced diffs. It was basically written so
that I can make an animation out of my NaNoWriMo novel, but you can
probably modify it to fit your work flow.

NOTE: THIS SOFTWARE IS PROVIDED IN THE "ITWORKSFORME®" CONFIGURATION.
SOME EXPERTISE AND PROVERBIAL TOUCHING OF POTENTIALLY LIVE WIRES IS
REQUIRED. YOU MAY MISS YOUR DEADLINES IF YOU RELY ON THIS THING, AND
I'M NOT TAKING RESPONSIBILITY FOR THAT. It might blow up when you try
to use it. When the smoke clears, please try to make sense of what
went wrong. I regrettably CANNOT guarantee that I will be able to
provide personal assistance on how to use this program to achieve your
goals; you may instead want to go and learn a bit of Ruby and
Processing instead. It's more fun that way! I also cannot guarantee
this hack is *constantly* developed; I may update it in future,
however, when I actually need it, and in those cases, try not to strip
away any of the functionality that is already present and will only
add new options.

## License

The animation software itself, found in this repository, is
distiributed under the terms of the GNU General Public License,
version 3. See "COPYING".

Other components included here:

* The included ["Anonymous Pro" font, by Mark Simonson](http://www.ms-studio.com/FontSales/anonymouspro.html), is distributed
  under the Open Font License. See `data/AnonymousPro.\*.txt`.

## Dependencies

(TODO: check the links)

### Animation software

* [Java SE JRE](http://www.java.com/)
  Last tested with Sun Java 6 (1.6.0_20-b02) under Linux.
* [Processing](http://processing.org/)
  This is built in Processing 1.2.1. If you experience weird syntax
  errors, get the newest version. Apparently there has been some
  big changes recently.
* [GSVideo](http://gsvideo.sourceforge.net/)
  Please download the appropriate version and unzip it in
  "libraries" folder under your Processing sketchbook folder,
  as instructed by the Helpful Documentation. Tested with Linux
  library version 0.7 and fairly freshish GStreamer in
  Debian Unstable.

(**MAINTENANCE NOTE:** As stated, these versions are ancient.)

### Conversion tool

* Probably some sort of POSIX userland. (Needs the wc(1) tool.)
* [Ruby](http://www.ruby-lang.org/en/)
  * [RMagick](http://rmagick.rubyforge.org/) `gem install rmagick`
* [DocDiff](http://www.kt.rim.or.jp/~hisashim/docdiff/)
* [wkhtmltopdf](http://code.google.com/p/wkhtmltopdf/)

## Workflow

The workflow with the animation goes like this:

* Produce a list of files from my Git repository, using "gitsplode.rb"
  tool (found in my github repository). This will also generate some
  of the data for the animation in form of an XML file.
* IMPORTANT: Make sure the files are presentable to docdiff. To
  wit, convert the files to the same line ending format. docdiff is
  able to figure out that the files have different types of line
  endings, but for reasons best known to the goddess ever-watchful,
  is *not* able to proceed with the comparison, *even with that
  insight in hand.* So, you should make sure all of the files have
  the same kinds of file endings. This could be a problem if you've
  worked on alternating platforms like Windows and *nix, and you've
  set Git to not automatically convert the line endings. If you've
  worked on only one platform, congratulations, you *may* be good to
  go.
* Produce the data used by the animator application, using
  `tellthetale.rb` Ruby program:
  * Produce HTML-format diff visualisations using docdiff
  * Convert the HTML to PDF using wkhtmltopdf
  * analyse, resize and convert the pages using RMagick
  * Produce yet another damn XML file with more summary data. Why
  * make one XML file when you can make two =)
* Slurp the XML summary and image files from individual pages in the
  Processing program, which will *clearly* animate the resulting
  pages and hopefully produce a nice little video file.

## gitsplode

The `gitsplode.rb` script feebly attempts to exports the entire
history of a single file from a Git repository. "Feebly attempts to",
because *\*ahem\** Git's notion of single file identity *is what it
is*.

This was mostly made to assist me in researching how my writing
projects are proceeding (i.e. *"In (date) my word count was (x)"*),
and I tend to keep those projects in single files as much as possible,
so if your use case diverts too much from that, you'll luck will
probably run out.

The program will spit out each revision in a file that is named after
the commit date, and also spits out an XML summary file
(`summary.xml`) that is pretty much self-explanatory:

```xml
    <commitdata>
        <commit>
            <filename>foo.1234_56_78.12_34_56.txt</filename>
            <date unix="123456">Thursday of Human-Readable Date Whenever</date>
            <message>This is a commit message and stuff...</message>
        </commit>
      <!-- ... -->
    </commitdata>
```

### Requirements

* Ruby. Dunno what versions. Worked fine on 1.9, seems to run on 2.x
  just fine. It only uses standard library REXML at the moment, but I
  may migrate to Nokogiri at some point, so get yer gems ready.
* Git. Normal Debian junk. Not sure what extras. Requires command line
  calls so I will check out if it can be made to run at all on
  Windows, but I doubt it.
