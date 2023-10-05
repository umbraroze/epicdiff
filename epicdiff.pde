/* ====================================================================

   epicdiff.pde: The actual epicdiff animation application proper.

   ====================================================================

   epicdiff - diffs of epics, in an epic manner
   Copyright (C) 2010,2011  Urpo Lankinen
   
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
   
   ==================================================================== */

// IMPORTS ////////////////////////////////////////////////////////////

import codeanticode.gsvideo.*;

// USER SETTINGS //////////////////////////////////////////////////////

/** Preferred animation width. */
final int animationWidth = 640;
/** Preferred animation height. */
final int animationHeight = 480;
/** Preferred animation framerate. */
final int animationFps = 25;

/** Horizontal object distances from edges and each other. */
final int gutterX = 5;
/** Vertical object distances from edges and each other. */
final int gutterY = 5;

/** Status text font's name. */
final String statusTextFontName = "AnonymousProB.ttf";
/** Status text font's size. */
final int statusTextFontSize = 18;

/** Enable video output? */
final boolean videoEnabled = false;
/** File where the video will ve saved. */
final String videoFile = "/tmp/epicdiff_output.mkv";
/** Video codec. */
final int videoCodec = GSMovieMaker.MJPEG;
/** Video quality. */
final int videoQuality = GSMovieMaker.BEST;

/** How long should the pages be shown in rest state? */
final int restLength = 3*25; // in frames

// PAGE CLASS /////////////////////////////////////////////////////////

class Page {
  // Current location.
  int x = 0;
  int y = 0;
  // Current scaled width and height.
  int width = 0;
  int height = 0;
  // Current scale ratio.
  float scaleRatio = 1.0;
  // Image data itself.
  PImage img = null;
  // Are we moving or not?
  boolean inMotion = false;
  // Frames are left in current animation
  int stepsLeft = 0;
  // Total length of the current motion animation, in frames
  int maxStepsLeft = 0;
  // Degrees of tilt the animated page currently has
  float tilt = 0.0;
  // The maximum degree of tilt in current animation
  float maxTilt = 0.0;
  // The frame of animation where the object gains maximum degree of tilt,
  // and the tilt will start falling back to 0.0
  int tiltPeakStep = 0;
  // The target coordinates of the animation.
  int targetX = 0;
  int targetY = 0;
  // Stuff that's pertinent to the current sketch
  int currentSketchWidth;
  int currentSketchHeight;
  // Allotted location.
  int allottedX = 0;
  int allottedY = 0;
  /**
   * Load the page graphic from file and imitialise the data.
   *
   * @param sketch current sketch; usually "this".
   * @param fileName the image file to load the page graphic from.
   */
  public Page(PApplet sketch, String fileName) {
    img = loadImage(fileName);
    x = 0; y = 0; scaleRatio = 1.0;
    width = img.width;
    height = img.height;
    currentSketchHeight = sketch.height;
    currentSketchWidth = sketch.width;
  }
  /**
   * Scale the page to the specified pixel height.
   */
  public void scaleToHeight(int h) {
    scaleRatio = (float)h/(float)(img.height);
    width = (int)((float)(img.width) * scaleRatio);
    height = (int)((float)(img.height) * scaleRatio);
  }
  /**
   * Sets the allotted top left of the page in the screen, i.e.
   * where the page should be placed when the animation comes
   * to rest.
   */
  public void setAllottedLocationA(int newX, int newY) {
    setAllottedLocation(newX+(width/2),newY+(height/2));
  }
  /**
   * Sets the allotted center of the page in the screen, i.e.
   * where the page should be placed when the animation comes
   * to rest.
   */
  public void setAllottedLocation(int newX, int newY) {
    allottedX = newX;
    allottedY = newY;
  }
  /**
   * Start moving to "allotted" location, i.e. where the page should
   * be placed when the animation comes to rest.
   */
  public void startMovingToAllotted() {
    startMovingTo(allottedX,allottedY);
  }
  /**
   * Start moving so that top left corner of the page
   * is in (newX,newY).
   */
  public void startMovingToA(int newX, int newY) {
    startMovingTo(newX+(width/2),newY+(height/2));
  }
  /**
   * Start moving so that the center of the page is in
   * (newX,newY).
   */
  public void startMovingTo(int newX, int newY) {
    inMotion = true;
    float distance = (float)sqrt(pow(abs(newX-x),2)+pow(abs(newY-y),2));
    stepsLeft = (int)(frameRate * 1.5 *
      (distance / (float)currentSketchWidth));
    maxStepsLeft = stepsLeft;
    if(newX > x)
      maxTilt = -15.0;
    else
      maxTilt = 15.0;
    // Smaller moves need smaller tilts.
    maxTilt *= (float)abs(x-newX) / (float)currentSketchWidth; 
    tilt = 0.0;
    tiltPeakStep = (int)(0.90*(float)maxStepsLeft);
    targetX = newX-(width/2); targetY = newY-(height/2);
  }
  /**
   * Automagically moves the page center to the specified
   * location.
   */
  public void teleportTo(int newX, int newY) {
    startMovingTo(newX,newY);
    stopMoving();
  }
  /**
   * Automagically moves the page top left corner to the specified
   * location.
   */
  public void teleportToA(int newX, int newY) {
    startMovingToA(newX,newY);
    stopMoving();
  }
  
  /**
   * Stop the current animation. Will ensure the page animation data
   * reflects the "stopped" state, i.e., will ensure the object
   * is in the final position and isn't in motion. If called mid-animation,
   * this will essentially "teleport" the page to the final location.
   */
  public void stopMoving() {
    inMotion = false;
    stepsLeft = 0;
    tilt = 0.0;
    x = targetX;
    y = targetY;
  }
  /**
   * Update animation state. This will essentially move the page toward
   * the desired final position, and update the tilt of the object.
   * When the animation starts, stepsLeft is set to same value as
   * maxStepsLeft, and stepsLeft is decremented in each frame.
   * The "tilt" value will rise until it reaches maxTilt, which will
   * happen when stepsLeft == tiltPeakStep. After that, tilt will 
   * keep falling toward 0.0.
   */
  private void creep() {
    if(stepsLeft > 0) {
      // Creep the movement toward the targetX/targetY.
      if(x < targetX)
        x += (targetX-x)/stepsLeft;
      else
        x -= (x-targetX)/stepsLeft;
      if(y < targetY)
        y += (targetY-y)/stepsLeft;
      else
        y -= (y-targetY)/stepsLeft;
      // Handle the tilting.
      if(stepsLeft > tiltPeakStep) {
        // tilt rising
        int peakTotal = maxStepsLeft - tiltPeakStep;
        int peakLeft = stepsLeft - tiltPeakStep;
        float percentagePeakLeft = (float)peakLeft / (float) peakTotal;
        tilt = maxTilt * (1.0-percentagePeakLeft);
      } else {
        // tilt falling
        tilt = maxTilt * ((float)stepsLeft / (float)tiltPeakStep);
      }
      stepsLeft--;
    } else {
      stopMoving();
    }
  }
  /**
   * Draw the page in the current animation frame. Will also call
   * creep() to update the animation state.
   */
  public void draw() {
    if(inMotion)
      creep();
    pushMatrix();
    translate(x,y);
    scale(scaleRatio);
    shearX(radians(tilt*0.75));
    shearY(radians(tilt*0.25));
    rotate(radians(tilt));
    image(img,0,0);
    popMatrix();
  }
  /**
   * Explicitly dereference the image. Hopefully enough to tell the
   * Java VM that the image object should be garbage-collected.
   */
  public void jettisonImage() {
    img = null;
  }
}

// GLOBAL VARIABLES ///////////////////////////////////////////////////

// Status text font.
PFont statusTextFont = null;

// Current list of pages.
List<Page> pageList = null;

// Current commit message, shown on top of the screen.
String commitMessage;
// Current statistics data, shown on bottom of the screen.
String statisticsText;

// Revision data XML.
XMLElement revisionData;

// Index of current revision to be shown.
int currentRevision;

// Total number of revisions loaded.
int maxRevisions;

// Animation state.
// FIXME: Should probably use enums, but Processing threw a fit.
final int ANI_STATE_IN   = 0;
final int ANI_STATE_REST = 1;
final int ANI_STATE_OUT  = 2;
int animationState = ANI_STATE_REST;
int restFrameCounter = 0;
int textFade = 255;

// Static indicator images
PImage addedIndicator = null;
PImage deletedIndicator = null;
PImage changesIndicator = null;

// Movie maker.
GSMovieMaker mm;

// ANIMATION HANDLING FUNCTIONS ///////////////////////////////////////

/**
 * Place all pages on the list to the screen.
 *
 * FIXME: This assumes all pages have the same aspect ratio.
 * FIXME: Calls scaleToHeight on *all* items repeatedly. Could
 *        optimise a little by just working on a representative page.
 *        Not much of a speed bump, though...
 * FIXME: Blindly assumes page list has at least 1 item.
 */
void placePagesOnScreen() {
  // Now, the algorithm that took some thinking: How many rows do we need?
  // We start by assuming we only need 1.
  int neededRows = 1;
  int maxPagesPerRow;
  int horizontalRowStart;
  Page representativePage;
  while(true) { // And we loop until we find the doggone height.
    // How many pages can we fit on one row?
    maxPagesPerRow = ceil((float)pageList.size() / (float)neededRows);
    // Then we scale the pages to fit.
    int visibleHorizontalArea = (width-gutterX*2);
    int visibleVerticalArea = (height-gutterY*2);
    int desiredHeight = (int)((float)visibleVerticalArea / 
      (float)neededRows)-gutterY;
    for(Page p : pageList) {
      p.scaleToHeight(desiredHeight);
    }
    // Get the first page list item as a representative page.
    representativePage = pageList.get(0);
    // How much vertical space would that take?
    int neededVerticalSpace = (representativePage.width+gutterX) *
      maxPagesPerRow;
    // Center the material on screen while our precious variables are
    // still in scope...
    horizontalRowStart = (int)((float)visibleHorizontalArea/2.0)-
      (int)((float)neededVerticalSpace/2.0) + gutterX;
    // OK, does it fit?
    if(neededVerticalSpace > visibleHorizontalArea)
      neededRows++; // Nope, keep looping!
    else
      break; // Yep, we could fit it here, time to end this charade!
  }

  int placedPagesCtr = 0;
  
  int pageHeight = representativePage.height;
  int pageWidth = representativePage.width;
  for(int placeRow = 1; placeRow <= neededRows; placeRow++) {
    int placeY = gutterY + (placeRow-1)*(pageHeight+gutterY);
    for(int placeColumn = 1; placeColumn <= maxPagesPerRow;
      placeColumn++) {
      int placeX = horizontalRowStart +
        (placeColumn-1)*(pageWidth+gutterX);
      if(placedPagesCtr < pageList.size()) {
        Page p = pageList.get(placedPagesCtr++);
        p.setAllottedLocationA(placeX,placeY);
        //p.startMovingToA(placeX,placeY);
        //p.stopMoving();
        //p.draw();  
      }
    }
  }
}

/**
 * Draws specified text on the top and bottom of the screen,
 * on top of translucent bands.
 */
void drawStatusText(String topText, String bottomText) {
  // Draw boxes on top of which texts are drawn.
  stroke(0);
  fill(0,90);
  rect(0,0,width,22);
  rect(0,height-22,width,22);
  // Update text fade.
  switch(animationState) {
    case ANI_STATE_IN:
      textFade = constrain(textFade + 15, 0, 255);
      break;
    case ANI_STATE_OUT:
      textFade = constrain(textFade - 10, 0, 255);
      break;
    case ANI_STATE_REST:
    default:
      textFade = 255;
      break;
  }
  // Draw texts.
  stroke(255,textFade);
  fill(255,textFade);
  textFont(statusTextFont);
  text(topText,5,15);
  text(bottomText,5,height-5);
}

/**
 * Loads the page summary data from the XML file.
 */
void loadPageSummary() {
  revisionData = new XMLElement(this, "input/page_summary.xml");
  currentRevision = 0;
  maxRevisions = revisionData.getChildCount()-1;
}

/**
 * Convert seconds to [h,m,s]. There's probably Java library
 * methods for this, but I'm under time constraints, so I'm sort
 * of copying some code I wrote earlier in Ruby (as hms_conv in
 * my "randomscripts" repo). This is probably bog-ordinary code,
 * similar to which is found everyfriggingwhere. Time math is hard
 * and I don't really want to vounch that this is correct, even when
 * it *looks* that way.
 */
private long[] toHMS(long seconds) {
  long[] r = new long[3];
  long cs, s, m, h;
  cs = seconds;
  s = cs % 60;
  cs -= s;
  m = (cs / 60) % 60;
  cs -= m * 60;
  h = cs / (60*60);
  r[0] = h;
  r[1] = m;
  r[2] = s;
  return r;
}

/**
 * Loads up the data from the current version.
 * This will replace the current pageList with the new data
 * and update the status messages.
 */
void loadPagesFromCurrentRevision() {
  loadPagesFromRevision(currentRevision);
}
/**
 * Loads up the data from the specified revision number.
 * This will replace the current pageList with the new data
 * and update the status messages.
 */
void loadPagesFromRevision(int revisionNumber) {
  // Stop animation until we've loaded stuff
  noLoop();
  // Jettison image data explicitly. Hopefully, this will tell the
  // garbage collector that we have lots of muck out there.
  if(pageList != null) {
    for(Page p : pageList) {
      p.jettisonImage();
    }
  }
  // Get us a new list, throwing the old one to the void if one exists.
  pageList = new ArrayList<Page>();
  // Ask the system nicely to please get rid of the old image objects,
  // because now would be a good time to do that. (Service not
  // guaranteed, but it's better to ask it now than not ask it at all.)
  System.runFinalization();
  System.gc();
  
  XMLElement revision = revisionData.getChild(revisionNumber);
  for(int i = 0; i < revision.getChildCount(); i++) {
    // FIXME: This assumes that the "filename" attribute of the page tag
    //        relative to the data/input/ directory. I appear to have an
    //        XML file produced by an earlier version, which spat out
    //        filename="data/input/...". The new version of tellthetale.rb
    //        appears to have fixed this quirk, but I have no recollection
    //        of actually trying this in practice. So it may work, or it
    //        may not.
    XMLElement pageData = revision.getChild(i);
    String fileName = "input/"+pageData.getStringAttribute("filename");
    Page loadedPage = new Page(this,fileName);
    pageList.add(loadedPage);
  }
  // Set the animation's commit message to the string found here.
  // Replace all newlines, tabs and repeating spaces with single spaces.
  commitMessage = revision.getStringAttribute("message").
    replaceAll("[\n\t ]+"," ").trim();
  // If it's too long, truncate it and add dots.
  if(commitMessage.length() > 90) {
    commitMessage = commitMessage.substring(0,86) + "...";
  }

  // Build the statistics text in the bottom of the display.
  long dateStamp = revision.getIntAttribute("unix");
  Date date = new Date(dateStamp*1000);
  // Time delta.
  // FIXME: We're sort of assuming the revs are in chronological order.
  //        This is *usually* the case, except when you're using
  //        Git merging. We should probably sort the revisions in
  //        tellthetale.rb.
  long timeDelta = 0;
  if(revisionNumber > 0) { // At rev. 0, the delta will be 0 anyway
    long prevRevDateStamp = 
      (long)revisionData.getChild(revisionNumber-1).
      getIntAttribute("unix");
    timeDelta = dateStamp - prevRevDateStamp;
  }
  long[] timeDeltaHMS = toHMS(timeDelta);
  // Wordcount.
  int wordcount = revision.getIntAttribute("wordcount");
  // Wordcount delta.
  int wordcountDelta = 0;
  if(revisionNumber > 0) { // At rev. 0, the delta will be 0 anyway
    int prevRevWordcount =
      revisionData.getChild(revisionNumber-1).
      getIntAttribute("wordcount");
    wordcountDelta = wordcount - prevRevWordcount;
  }
  // OK, now we have the info, let's format it.
  DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:MM:SS");
  StringBuilder st = new StringBuilder();
  Formatter stf = new Formatter(st);
  stf.format("%s (+%dh%dm) %d words (%+d) ",
    dateFormat.format(date),
    timeDeltaHMS[0],timeDeltaHMS[1],
    wordcount,wordcountDelta);
  statisticsText = st.toString();
    
  // All done, continue animation...
  loop();
}

/**
 * Are the pages currently animated? Will return true if it can find
 * even one animated page.
 */
boolean isAnimationRunning() {
  for(Page p : pageList) {
    if(p.inMotion)
      return true;
  }
  return false;
}

/**
 * Scatter the pages to the left side of the screen and make
 * them creep toward their targets.
 */
void inScatter() {
  noLoop(); // Pause during recalc (probably unnecessary)
  // Recalculate the proper locations of the pages.
  placePagesOnScreen();
  // Give each page a random new location on the left side of the
  // screen, beyond the borders.
  int sw = abs(width);
  int sh = abs(height);
  for(Page p : pageList) {
    int pw = abs(p.width);
    int ph = abs(p.height);
    // Place the page to a random location. Safe area is about
    // 2*sketch width or height to page width/height.
    int randomX = round(random(2*(-sw-pw),-pw));
    int randomY = round(random(2*(-sh-ph),2*(sh+ph)));
    p.teleportTo(randomX,randomY);
    // Make it move.
    p.startMovingToAllotted();
  }
  animationState = ANI_STATE_IN;
  restFrameCounter = 0;
  textFade = 0;
  loop(); // Continue animation
}
/**
 * Give the pages currently on screen random creep targets toward
 * the right side of the screen.
 */
void outScatter() {
  noLoop(); // Pause during recalc (probably unnecessary)
  // Give each page a random new location on the right side of the
  // screen, beyond the borders.
  int sw = abs(width);
  int sh = abs(height);
  for(Page p : pageList) {
    int pw = abs(p.width);
    int ph = abs(p.height);
    // Place the page to a random location. Safe area is about
    // 2*sketch width or height to page width/height.
    int randomX = round(random(2*(sw+pw),pw));
    int randomY = round(random(-2*(sh+ph),2*(sh+ph)));
    p.startMovingTo(randomX, randomY);
  }
  animationState = ANI_STATE_OUT;
  restFrameCounter = 0;
  textFade = 255;
  loop(); // Continue animation
}

/**
 * Draw each page to the screen.
 */
void drawPages() {
  for(Page p : pageList) {
    p.draw();
  }
}

/**
 * Final operations.
 */
void done() {
  if(videoEnabled) {
    mm.finish();
  }
  exit();
}

// PROCESSING CALLBACKS ///////////////////////////////////////////////

/**
 * Processing callback for animation setup.
 */
void setup() {
  size(animationWidth,animationHeight,P3D);
  background(0,0,0);
  frameRate(animationFps);

  statusTextFont = createFont(statusTextFontName,statusTextFontSize,true);
  if(videoEnabled) {
    mm = new GSMovieMaker(this,width,height,
      videoFile,videoCodec,videoQuality,animationFps);
    mm.start();
  }

  loadPageSummary();  
  loadPagesFromCurrentRevision();
  inScatter();
}

/**
 * Processing callback to draw an animation frame and drive the
 * animation.
 */
void draw() {
  background(0,0,0);
  color(255,255,255);

  drawPages();
  drawStatusText(commitMessage, statisticsText);
  if(!isAnimationRunning()) { // Did we just stop animating the pages?
    switch(animationState) {
      case ANI_STATE_IN:
        // We just came to the rest from creeping in..
        animationState = ANI_STATE_REST;
        restFrameCounter = 0;
        break;
      case ANI_STATE_OUT:
        // Next page.
        if(++currentRevision > maxRevisions)
          done(); // Or, if it was the last page, proceed to quitting.
        else {
          loadPagesFromCurrentRevision();
          inScatter();
        }
        break;
      case ANI_STATE_REST:
        // Update rest frame counter; if we exceed rest length,
        // proceed to scatter!
        textFade = 255;
        if(restFrameCounter++ > restLength)
          outScatter();
        break;
      default:
        println("Found a rather weird state. What is going on?");
        done();
        break;
    }
  }
  if(videoEnabled) {
    loadPixels();
    mm.addFrame(pixels);
  }
}

/**
 * Processing callback for keyboard presses.
 */
void keyPressed() {
  switch(key) {
    case 'q':
    case 'Q':
      exit();
      break;
    default:
      break;
  }
}
