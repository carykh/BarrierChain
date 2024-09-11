import java.util.*;
import com.hamoid.*;

// Parameters (start)


// US state video
String FILENAME = "barrierChainVideo.mp4";
String START_DRAW_YEAR = "1790"; // which frame should it start drawing?
boolean IS_US_STATES_DATASET = true; // if this is false, it imports a dataset the more standard way - otherwise, it does US-state-specific importing
String DATA_FILEPATH = "us_state_data_caryfied.tsv";
String TITLE = ""; // not needed for the US states video, but helpful to have for other visualizations!


// Simpsons video
/*
String FILENAME = "simpsonsVideo.mp4";
String START_DRAW_YEAR = "S1E1";
boolean IS_US_STATES_DATASET = false;
String DATA_FILEPATH = "simpsons_lines.tsv";
String TITLE = "The Simpsons characters\nwith the most total lines";
*/


float TEXT_ALPHA = 1.0; // Set this to 0.6 for "less-harsh" black, if you want the barriers to stand out more. Set it to 1.0 if you like the fully black text.
double PLAY_SPEED = 1.0/90.0; // how many "years" pass per frame?
int PANEL_COUNT_W = 10;
int PANEL_COUNT_H = 6;
boolean vertical = true; // Determines whether the snaking path is composed of vertical columns or horizontal rows.
double W_W = 1920;
double W_H = 930;
double MARGIN = 15;
double CARD_MARGIN = 25;
double SWING_MULTI = 0.03; // When panels are travelling, they can "swing" to the side to made swaps look more interesting. How far should they swing?
double MAX_SWING = 60; // What's the max distance they can swing?
double PATH_CURVE = 15; // We can curve the corners, cosmetically. What should the radius of that curvature be? 0 = no curve, perfect rectangle.
double PANEL_CURVE = 10;
double SCALE_FACTOR = 1.0; // how much to scale up or down the 1920x1080 by.

int RANK_INTERP = 10; // this can be 1. If it's 2+, this tells the computer how many times to subdivide the "ranking" array temporally. Meaning, if it's 10, there will be a ranking calculated for every tenth of a year. The finer this interpolation is, the more accurate the timing of rank-swaps will appear, but the more RAM it takes up (usually negligible unless you have a huge dataset).
double TRANSITION_TIME = 0.3333; // how long, in "years", does it take for cards to swap places, visually?
double EPS = 0.15; // used for calculating derivatives. If it's bigger, then velocity calculations will be smoother
double DISPLAY_UPDATE_RATE = 1.0/15.0; // How often, in "years", should the text of stats update? This could be really fast (frame-by-frame), but I like to slow it down so the numbers are still legible, and so the video compression doesn't get distorted.

color BACKGROUND_COLOR = color(255,255,255);
color BARRIER_COLOR = color(0,0,0);
color PATH_COLOR = color(197,197,197);
color[] REGION_COLORS = {color(255,155,197),color(213,213,0),color(168,168,255),color(255,180,80),color(83,224,83),color(152,152,152)};
// Parameters (end)

String[] data;
String[] header;
Map<String, Integer> yearIndex; 
Person[] people;
double[] totals;
PImage imageGrid;
PImage mapImage;
VideoExport videoExport;

int COUNT;
double PANEL_W = W_W/PANEL_COUNT_W;
double PANEL_H = W_H/PANEL_COUNT_H;
double PANEL_MW = PANEL_W-MARGIN*2;
double PANEL_MH = PANEL_H-MARGIN*2;
double PANEL_CMW = PANEL_W-CARD_MARGIN*2;
double PANEL_CMH = PANEL_H-CARD_MARGIN*2;
PFont font;

int LEN;
int RLEN;
// only the US state dataset has the parameters for US map images.
int METADATA_COUNT = IS_US_STATES_DATASET ? 5 : 2;
double currentYear;

void setup(){
  yearIndex = new HashMap<String, Integer>();
  if(IS_US_STATES_DATASET){
    imageGrid = loadImage("stateShapes.png");
    mapImage = loadImage("us_map.png");
  }
  font = createFont("Jygquif 1.ttf", 256);
  data = loadStrings(DATA_FILEPATH);
  COUNT = data.length-1;  // subtract header row
  header = data[0].split("\t");
  LEN = header.length-METADATA_COUNT;
  for(int yr = 0; yr < LEN; yr++){
    yearIndex.put(header[yr+METADATA_COUNT], yr);
  }
  currentYear = yearIndex.get(START_DRAW_YEAR);
  RLEN = LEN*RANK_INTERP;
  people = new Person[COUNT];
  totals = new double[LEN];
  for(int p = 0; p < COUNT; p++){
    people[p] = new Person(data[p+1], LEN, p);
  }
  for(int y_r = 0; y_r < RLEN; y_r++){
    ArrayList<Person> sorted = new ArrayList<Person>(0);
    double y = ((double)y_r)/RANK_INTERP;
    for(int p = 0; p < COUNT; p++){
      int index = binSeaValueYear(sorted, y, people[p], 0, p-1);
      sorted.add(index,people[p]);
    }
    for(int p = 0; p < COUNT; p++){
      Person pe = sorted.get(p);
      pe.ranks[y_r] = p;
    }
  }
  size(1920,1080);
  videoExport = new VideoExport(this,FILENAME);
  videoExport.setFrameRate(60);
  videoExport.startMovie();
}

void draw(){
  double[] barriers = calculateBarriers();
  
  background(BACKGROUND_COLOR);
  scale((float)SCALE_FACTOR);
  drawPath(barriers);
  drawPanels();
  drawFooter();
  saveVideoFrameHamoid();
  
  currentYear += PLAY_SPEED;
}

void saveVideoFrameHamoid(){
  videoExport.saveFrame();
  if(currentYear >= LEN){ 
    videoExport.endMovie();
    exit();
  }
}

double[] calculateBarriers(){
  double[] barriers = new double[COUNT];
  
  ArrayList<Person> peopleOrderedByValue = new ArrayList<Person>(0);
  for(int p = 0; p < COUNT; p++){
    double value = people[p].calculateValue(currentYear);
    int index = binSeaValue(peopleOrderedByValue, value, 0, p-1);
    peopleOrderedByValue.add(index,people[p]);
  }
  barriers[0] = 0;
  for(int p = 1; p < COUNT; p++){
    double v_p = peopleOrderedByValue.get(p-1).valueCache;
    double v_t = peopleOrderedByValue.get(p).valueCache;
    barriers[p] = (v_p-v_t)/v_p;
  }
  return barriers;
}

boolean doesFileExist(String filePath) {
  return new File(dataPath(filePath)).exists();
}

void drawPanels(){
  ArrayList<Person> peopleOrderedByVelocity = new ArrayList<Person>(0);
  for(int p = 0; p < COUNT; p++){
    double velocity = people[p].calculateVelocity(currentYear);
    int index = binSeaVelocity(peopleOrderedByVelocity, velocity, 0, p-1);
    peopleOrderedByVelocity.add(index,people[p]);
  }
  for(int p = 0; p < COUNT; p++){
    Person pe = peopleOrderedByVelocity.get(p);
    pe.drawPanel();
  }
}
void drawPath(double[] barriers){
  noStroke();
  fill(BARRIER_COLOR);
  for(int r = 0; r < COUNT; r++){
    double a_x = rankToX(r);
    double a_y = rankToY(r);
    pushMatrix();
    dTranslate(a_x,a_y);
    fill(PATH_COLOR);
    dRect(MARGIN,MARGIN,PANEL_MW,PANEL_MH,PATH_CURVE);
    if(r >= 1){
      drawBarrier(r,1,PATH_CURVE);
      fill(BARRIER_COLOR);
      double fac = Math.min(0.93,Math.sqrt(barriers[r]));
      drawBarrier(r,fac,0);
    }
    if(r >= 1 && r < COUNT-1){
      drawInnerCurve(r);
    }
    popMatrix();
  }
}

void drawBarrier(int r, double scale, double widening){
  int thisX = zigzaggerX(r);
  int prevX = zigzaggerX(r-1);
  int thisY = zigzaggerY(r);
  int prevY = zigzaggerY(r-1);
  if(thisX > prevX){
    rectangularScale(0,PANEL_H/2,MARGIN+widening,PANEL_MH/2,scale);
  }else if(thisX < prevX){
    rectangularScale(PANEL_W,PANEL_H/2,MARGIN+widening,PANEL_MH/2,scale);
  }else if(thisY > prevY){
    rectangularScale(PANEL_W/2,0,PANEL_MW/2,MARGIN+widening,scale);
  }else{
    rectangularScale(PANEL_W/2,PANEL_H,PANEL_MW/2,MARGIN+widening,scale);
  }
}
void rectangularScale(double x, double y, double w, double h, double scale){
  dRect(x-w*scale,y-h*scale,w*2*scale,h*2*scale);
}
void rectangularLine(double x1, double y1, double x2, double y2, double thickness){
  dRect(x1-thickness, y1-thickness, (x2-x1)+thickness*2, (y2-y1)+thickness*2);
}
void drawInnerCurve(int r){
  int x_a = zigzaggerX(r-1);
  int x_b = zigzaggerX(r);
  int x_c = zigzaggerX(r+1);
  int y_a = zigzaggerY(r-1);
  int y_b = zigzaggerY(r);
  int y_c = zigzaggerY(r+1);
  int dx = 0;
  int dy = 0;
  if((x_a == x_b && x_c == x_b) || (y_a == y_b && y_c == y_b)){
    return;
  }else{
    dx = (x_a == x_b) ? x_c-x_b : x_a-x_b;
    dy = (y_a == y_b) ? y_c-y_b : y_a-y_b;
  }
  int ax = (dx == -1) ? 0 : 1;
  int ay = (dy == -1) ? 0 : 1;
  fill(PATH_COLOR);
  dRect(ax*(PANEL_MW+MARGIN),ay*(PANEL_MH+MARGIN),PATH_CURVE,PATH_CURVE);
  fill(BACKGROUND_COLOR);
  ellipseMode(RADIUS);
  dEllipse(ax*PANEL_W,ay*PANEL_H,PATH_CURVE,PATH_CURVE);
}
void dEllipse(double x, double y, double w, double h){
  ellipse((float)x, (float)y, (float)w, (float)h);
}
double safeArray(double[] arr, int i){
  int i2 = min(max(i,0),arr.length-1);
  return arr[i2];
}

double arrLookup(double[] arr, double year){
  int year_int = (int)year;
  double year_rem = year%1.0;
  double before = safeArray(arr,year_int);
  double after = safeArray(arr,year_int+1);
  return before+(after-before)*year_rem;
}

double displaySlowedArrLookup(double[] arr, double year){
  double roundedYear = Math.floor((year+PLAY_SPEED*0.5)/DISPLAY_UPDATE_RATE)*DISPLAY_UPDATE_RATE;
  return arrLookup(arr,roundedYear);
}

String arrToText(double[] arr, double year){
  double value = arrLookup(arr,year);
  int value_int = (int)Math.round(value);
  return commafy(value_int);
}
String commafy(double f) {
  String s = Math.round(f)+"";
  String result = "";
  for (int i = 0; i < s.length(); i++) {
    if ((s.length()-i)%3 == 0 && i != 0) {
      result = result+",";
    }
    result = result+s.charAt(i);
  }
  return result;
}
PGraphics dCreateGraphics(double w, double h){
  return createGraphics((int)w, (int)h);
}
void drawFooter(){
  if(IS_US_STATES_DATASET){
    fill(0);
    textAlign(LEFT);
    textFont(font,128);
    dText(yearToString(currentYear),25,W_H+110);
    textFont(font,48);
    dText("United States total:",310,W_H+53);
    dText(commafy(displaySlowedArrLookup(totals,currentYear)),310,W_H+111);
    textFont(font,26);
    String[] blurb = {"The data is from Wikipedia, which means populations are based on modern-day borders.",
    "The exceptions are West Virginia, (whose population is combined with Virginia before",
    "its separation in 1863), and Maine (whose population is combined with Massachusetts",
    "before its separation in 1820)."};
    for(int i = 0; i < 4; i++){
      dText(blurb[i],785,W_H+30+30*i);
    }
    
    double M = (1080-W_H)/mapImage.height*mapImage.width;
    dImage(mapImage,W_W-M-12,W_H-9,M,1080-W_H);
  }else{
    float cursorX = 30;
    fill(0);
    textAlign(LEFT);
    textFont(font,48);
    dText(TITLE,cursorX,W_H+50);
    cursorX += textWidth(TITLE)+70;
    
    String str = yearToString(currentYear);
    textFont(font,108);
    dText(str,cursorX,W_H+110);
    cursorX += textWidth(str)+70;
    
    textFont(font,48);
    dText("Total:",cursorX,W_H+53);
    dText(commafy(displaySlowedArrLookup(totals,currentYear)),cursorX,W_H+111);
  }
}
void dImage(PImage img, double x, double y, double h, double w){
  image(img, (float)x, (float)y, (float)h, (float)w);
}
String yearToString(double year){
  return header[(int)year+METADATA_COUNT];
}
void dFill(double v){
  fill((float)v);
}
void dImage(PImage img, double x, double y){
  image(img, (float)x, (float)y);
}
void dTranslate(double x, double y){
  translate((float)x, (float)y);
}
void dRect(double x, double y, double w, double h){
  rect((float)x, (float)y, (float)w, (float)h);
}
void dRect(double x, double y, double w, double h, double r){
  rect((float)x, (float)y, (float)w, (float)h, (float)r);
}
void dText(String str, double x, double y){
  text(str, (float)x, (float)y);
}
double rankToX(double rank){
  int rank_int = (int)rank;
  double rank_rem = rank%1.0;
  int before_x_index = zigzaggerX(rank_int);
  int after_x_index = zigzaggerX(rank_int+1);
  double x_index = before_x_index+(after_x_index-before_x_index)*rank_rem;
  return x_index*(W_W/PANEL_COUNT_W);
}

double rankToY(double rank){
  int rank_int = (int)rank;
  double rank_rem = rank%1.0;
  
  int before_y_index = zigzaggerY(rank_int);
  int after_y_index = zigzaggerY(rank_int+1);
  double y_index = before_y_index+(after_y_index-before_y_index)*rank_rem;
  return y_index*(W_H/PANEL_COUNT_H);
}

int zigzaggerX(int n){
  if(vertical){
    return n/PANEL_COUNT_H;
  }else{
    int before_y_index = n/PANEL_COUNT_W;
    int before_x_index = n%PANEL_COUNT_W;
    if(before_y_index%2 == 1){
      before_x_index = (PANEL_COUNT_W-1)-before_x_index;
    }
    return before_x_index;
  }
}

int zigzaggerY(int n){
  if(vertical){
    int before_x_index = n/PANEL_COUNT_H;
    int before_y_index = n%PANEL_COUNT_H;
    if(before_x_index%2 == 1){
      before_y_index = (PANEL_COUNT_H-1)-before_y_index;
    }
    return before_y_index;
  }else{
    return n/PANEL_COUNT_W;
  }
}

int binSeaValueYear(ArrayList<Person> list, double y, Person newbie, int start, int end){
  if(start > end){
    return start;
  }
  int mid = (start+end)/2;
  Person other = list.get(mid);
  double delta = arrLookup(other.values,y)-arrLookup(newbie.values,y);
  if(delta == 0){
    delta = newbie.yearOfFirstNonZero-other.yearOfFirstNonZero;
  }
  if(delta >= 0){
    return binSeaValueYear(list,y,newbie,mid+1,end);
  }else{
    return binSeaValueYear(list,y,newbie,start,mid-1);
  }
}

int binSeaVelocity(ArrayList<Person> list, double val, int start, int end){
  if(start > end){
    return start;
  }
  int mid = (start+end)/2;
  double toCompare = list.get(mid).velocityCache;
  if(val < toCompare){
    return binSeaVelocity(list,val,mid+1,end);
  }else{
    return binSeaVelocity(list,val,start,mid-1);
  }
}
int binSeaValue(ArrayList<Person> list, double val, int start, int end){
  if(start > end){
    return start;
  }
  int mid = (start+end)/2;
  double toCompare = list.get(mid).valueCache;
  if(val < toCompare){
    return binSeaValue(list,val,mid+1,end);
  }else{
    return binSeaValue(list,val,start,mid-1);
  }
}
double cap(double val, double limit){
  return Math.min(Math.max(val,-limit),limit);
}

double WAIndexInterp(int[] a, double index, double WINDOW_WIDTH){
  return WAIndex(a,index*RANK_INTERP,WINDOW_WIDTH*RANK_INTERP);
}
double WAIndex(double[] a, double indexFull, double WINDOW_WIDTH){
  double index = indexFull;
  int startIndex = (int)Math.max(0,Math.ceil(index-WINDOW_WIDTH));
  int endIndex = (int)Math.min(a.length-1,Math.floor(index+WINDOW_WIDTH));
  double counter = 0;
  double summer = 0;
  for(int d = startIndex; d <= endIndex; d++){
    double val = a[d];
    double weight = 0.5+0.5*Math.cos((d-index)/WINDOW_WIDTH*PI);
    counter += weight;
    summer += val*weight;
  }
  double finalResult = summer/counter;
  return finalResult;
}
double WAIndex(int[] a, double index, double WINDOW_WIDTH){
  double[] aDouble = new double[a.length];
  for(int i = 0; i < a.length; i++){
    aDouble[i] = a[i];
  }
  return WAIndex(aDouble,index,WINDOW_WIDTH);
}
