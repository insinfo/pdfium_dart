import 'dart:typed_data';

class CFxDIBAttribute {
  static const int kResUnitNone = 0;
  static const int kResUnitInch = 1;
  static const int kResUnitCentimeter = 2;
  static const int kResUnitMeter = 3;

  int xDpi = -1;
  int yDpi = -1;
  int dpiUnit = kResUnitNone;
}

void reverseRGB(Uint8List destBuf, Uint8List srcBuf, int pixels) {
  if (destBuf.isEmpty || srcBuf.isEmpty || pixels <= 0) return;
  // Assumes 3 bytes per pixel
  for (int i = 0; i < pixels; i++) {
    final offset = i * 3;
    if (offset + 2 >= srcBuf.length || offset + 2 >= destBuf.length) break;
    destBuf[offset] = srcBuf[offset + 2];
    destBuf[offset + 1] = srcBuf[offset + 1];
    destBuf[offset + 2] = srcBuf[offset];
  }
}
