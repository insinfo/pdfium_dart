import 'dart:typed_data';

import '../fxcrt/pause_indicator.dart';

abstract class ScanlineDecoder {
  int origWidth;
  int origHeight;
  int outputWidth;
  int outputHeight;
  int comps;
  int bpc;
  int pitch;
  
  int _nextLine = -1;
  Uint8List? _lastScanline;

  ScanlineDecoder({
    this.origWidth = 0,
    this.origHeight = 0,
    this.outputWidth = 0,
    this.outputHeight = 0,
    this.comps = 0,
    this.bpc = 0,
    this.pitch = 0,
  });

  Uint8List? getScanline(int line) {
    if (_nextLine == line + 1) {
      return _lastScanline;
    }

    if (_nextLine < 0 || _nextLine > line) {
      if (!rewind()) {
        return null; // Empty span equivalent
      }
      _nextLine = 0;
    }
    
    while (_nextLine < line) {
      if (getNextLine() == null) {
         // Should we error or stop? C++ just calls GetNextLine() which might return something empty.
         // If getNextLine fails, we might be stuck.
         // Assuming getNextLine handles errors or returns null.
         // But logic continues until line.
      }
      _nextLine++;
    }
    _lastScanline = getNextLine();
    _nextLine++;
    return _lastScanline;
  }

  bool skipToScanline(int line, PauseIndicator? pause) {
    if (_nextLine == line || _nextLine == line + 1) {
      return false;
    }

    if (_nextLine < 0 || _nextLine > line) {
      if (!rewind()) {
        return false;
      }
      _nextLine = 0;
    }
    
    _lastScanline = null;
    while (_nextLine < line) {
      _lastScanline = getNextLine();
      _nextLine++;
      if (pause != null && pause.needToPauseNow()) {
        return true;
      }
    }
    return false;
  }

  // Abstract methods
  int getSrcOffset();
  bool rewind();
  Uint8List? getNextLine();

  int get width => outputWidth;
  int get height => outputHeight;
  int countComps() => comps;
  int getBPC() => bpc;
}
