enum RenderType { normal, gray, alpha, forcedColor }

class RenderOptions {
  RenderType colorMode = RenderType.normal;
  
  bool clearType = false;
  bool noNativeText = false;
  bool forceHalftone = false;
  bool rectAA = false;
  bool breakForMasks = false;
  bool noTextSmooth = false;
  bool noPathSmooth = false;
  bool noImageSmooth = false;
  bool limitedImageCache = false;
  bool convertFillToStroke = false;
  
  // ColorScheme (ARGB)
  int pathFillColor = 0;
  int pathStrokeColor = 0;
  int textFillColor = 0;
  int textStrokeColor = 0;
  
  RenderOptions();
}
