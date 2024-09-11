class Person{
  String name;
  String unionYear;
  double[] values;
  int yearOfFirstNonZero = -1;
  int[] ranks;
  int id;
  double valueCache;
  double velocityCache;
  int col;
  int[] map_coor = new int[2];
  PImage thumbnail = null;
  
  public Person(String dataLine, int LEN, int t_id){
    String[] parts = dataLine.split("\t");
    name = parts[0];
    if(IS_US_STATES_DATASET){
      name = name.replace("Northern", "N.");
      name = name.replace("District of Columbia", "Washington, D.C.");
      unionYear = parts[4];
      for(int i = 0; i < 2; i++){
        map_coor[i] = Integer.parseInt(parts[1+i]);
      }
    }
    col = Integer.parseInt(parts[IS_US_STATES_DATASET ? 3 : 1]);
    values = new double[LEN];
    ranks = new int[LEN*RANK_INTERP];
    for(int y = 0; y < LEN; y++){
      values[y] = Double.parseDouble(parts[METADATA_COUNT+y]);
      totals[y] += values[y];
      if(yearOfFirstNonZero == -1 && values[y] > 0){
        yearOfFirstNonZero = y;
      }
    }
    for(int y_r = 0; y_r < RLEN; y_r++){
      ranks[y_r] = 0;
    }
    id = t_id;
    if(IS_US_STATES_DATASET){
      thumbnail = getStateImage();
    }else{
      String filename = name+".png";
      if(doesFileExist(filename)){
        thumbnail = loadImage(filename);
      }
    }
  }
  
  double calculateValue(double y){
    valueCache = arrLookup(values,currentYear);
    return valueCache;
  }
  double calculateVelocity(double y){
    double a_rank_pre = WAIndexInterp(ranks, y-EPS, TRANSITION_TIME);
    double a_rank_post = WAIndexInterp(ranks, y+EPS, TRANSITION_TIME);
    velocityCache = (a_rank_post-a_rank_pre)/(EPS*2);
    return velocityCache;
  }
  
  PImage getStateImage(){
    int x = map_coor[0];
    int y = map_coor[1];
    if(name.equals("Virginia") && currentYear < yearIndex.get("1863")){
      x = 0;
      y = 8;
    }
    if(name.equals("Massachusetts") && currentYear < yearIndex.get("1820")){
      x = 1;
      y = 8;
    }
    return imageGrid.get(64*x,64*y,63,63);
  }
  
  color getTinge(){
    if(IS_US_STATES_DATASET){
      int col_now = col;
      Integer unionIndex = yearIndex.get(unionYear);
      if(unionIndex != null && currentYear < unionIndex){
        col_now = 5;
      }
      color c = REGION_COLORS[col_now];
      float r = (255-red(c));
      float g = (255-green(c));
      float b = (255-blue(c));
      return color(r,g,b);
    }else{
      return REGION_COLORS[col];
    }
  }
  
  void drawPanel(){
    double a_rank = WAIndexInterp(ranks, currentYear, TRANSITION_TIME);
    double ax = rankToX(a_rank);
    double ay = rankToY(a_rank);
    
    double a_rank_prev = WAIndexInterp(ranks, currentYear-EPS, TRANSITION_TIME);
    double ax_prev = rankToX(a_rank_prev);
    double ay_prev = rankToY(a_rank_prev);
    double a_rank_next = WAIndexInterp(ranks, currentYear+EPS, TRANSITION_TIME);
    double ax_next = rankToX(a_rank_next);
    double ay_next = rankToY(a_rank_next);
    
    //Add swing
    double dx = cap((ax_next-ax_prev)/2/EPS*SWING_MULTI,MAX_SWING);
    double dy = cap((ay_next-ay_prev)/2/EPS*SWING_MULTI,MAX_SWING);
    ay += dx;
    ax -= dy;
    
    pushMatrix();
    dTranslate(ax,ay);
    PGraphics panel = dCreateGraphics(PANEL_CMW*SCALE_FACTOR,PANEL_CMH*SCALE_FACTOR);
    panel.beginDraw();
    panel.noStroke();
    panel.scale((float)SCALE_FACTOR);
    panel.fill(getTinge());
    panel.rect(0,0,(float)PANEL_CMW,(float)PANEL_CMH, (float)PANEL_CURVE);
    if(thumbnail != null){
      if(IS_US_STATES_DATASET){
        panel.tint(getTinge());
        MAR_image(panel, thumbnail, (float)((PANEL_CMW-PANEL_CMH)/2),0,(float)PANEL_CMH,(float)PANEL_CMH, 1.0);
        panel.noTint();
        panel.filter(INVERT);
      }else{
        MAR_image(panel, thumbnail, 0,0,(float)PANEL_CMW,(float)PANEL_CMH, 0.4);
      }
    }

    
    panel.fill(0,0,0,255*TEXT_ALPHA);
    panel.textAlign(CENTER);
    float size1 = 32;
    panel.textFont(font,size1);
    
    double val = displaySlowedArrLookup(values,currentYear);
    String val_s = commafy((int)Math.round(val));
    panel.text(val_s,(float)(PANEL_CMW/2),(float)CARD_MARGIN+57);
    float size2 = min(size1,(float)(0.95*size1*PANEL_CMW/panel.textWidth(name)));
    panel.textFont(font,size2);
    panel.text(name,(float)(PANEL_CMW/2),(float)CARD_MARGIN+17);
    
    panel.endDraw();
    dImage(panel,CARD_MARGIN,CARD_MARGIN,PANEL_CMW,PANEL_CMH);
    popMatrix();
  }
  void MAR_image(PGraphics p, PImage img, float x, float y, float w, float h, float alpha){
    float p_ar = w/h;
    float i_ar = ((float)img.width)/img.height;
    if(alpha < 1){
      p.tint(255,255,255,255*alpha);
    }
    if(p_ar > i_ar){
      float new_w = h*i_ar;
      p.image(img,x+w/2-new_w/2,y,new_w,h);
    }else{
      float new_h = w/i_ar;
      p.image(img,x,y+h/2-new_h/2,w,new_h);
    }
    if(alpha < 1){
      p.noTint();
    }
  }
}
