// Copyright 2016 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Fax decoding module
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../scanlinedecoder.dart';
import '../../fxcrt/fx_types.dart'; 
import 'fax_tables.dart';

// ============================================================================
// Fax Module
// ============================================================================

class FaxModule {
  static ScanlineDecoder? createDecoder({
    required Uint8List srcSpan,
    required int width,
    required int height,
    required int K,
    required bool endOfLine,
    required bool encodedByteAlign,
    required bool blackIs1,
    required int columns,
    required int rows,
  }) {
    int actualWidth = columns != 0 ? columns : width;
    int actualHeight = rows != 0 ? rows : height;

    // Reject invalid values.
    if (actualWidth <= 0 || actualHeight <= 0) {
      return null;
    }

    // Reject unreasonable large input.
    if (actualWidth > 65535 || actualHeight > 65535) {
      return null;
    }

    return _FaxDecoder(
      srcSpan,
      width,
      height,
      K,
      endOfLine,
      encodedByteAlign,
      blackIs1,
      actualWidth,
      actualHeight,
    );
  }
}

// ============================================================================
// Internal Fax Decoder
// ============================================================================

class _FaxDecoder extends ScanlineDecoder {
  final int encoding;
  final bool endOfLine;
  final bool byteAlign;
  final bool black;
  final Uint8List srcSpan;
  
  // Mutable state
  int bitpos = 0;
  
  // Buffers
  late Uint8List scanlineBuf;
  late Uint8List refBuf;

  _FaxDecoder(
    this.srcSpan,
    int width,
    int height,
    int K,
    this.endOfLine,
    this.byteAlign,
    this.black,
    int actualWidth,
    int actualHeight,
  ) : encoding = K,
      super(
        origWidth: actualWidth,
        origHeight: actualHeight,
        outputWidth: actualWidth,
        outputHeight: actualHeight,
        comps: 1,
        bpc: 1,
        pitch: (actualWidth + 7) ~/ 8, // 1bpp pitch
      ) {
    scanlineBuf = Uint8List(pitch);
    refBuf = Uint8List(pitch);
  }

  @override
  bool rewind() {
    refBuf.fillRange(0, refBuf.length, 0x00);
    bitpos = 0;
    return true;
  }

  @override
  Uint8List? getNextLine() {
    final bitSize = srcSpan.length * 8;
    
    // Helper object to pass bitpos by reference
    final cursor = _Cursor(bitpos);
    
    _faxSkipEOL(srcSpan, cursor);
    if (cursor.pos >= bitSize) {
      bitpos = cursor.pos;
      return null;
    }

    scanlineBuf.fillRange(0, scanlineBuf.length, 0xff);

    if (encoding < 0) {
      _faxG4GetRow(srcSpan, cursor, scanlineBuf, refBuf, outputWidth);
      refBuf.setAll(0, scanlineBuf);
    } else if (encoding == 0) {
       _faxGet1DLine(srcSpan, cursor, scanlineBuf, outputWidth);
    } else {
      if (_nextBit(srcSpan, cursor)) {
        _faxGet1DLine(srcSpan, cursor, scanlineBuf, outputWidth);
      } else {
        _faxG4GetRow(srcSpan, cursor, scanlineBuf, refBuf, outputWidth);
      }
      refBuf.setAll(0, scanlineBuf);
    }

    if (endOfLine) {
      _faxSkipEOL(srcSpan, cursor);
    }

    if (byteAlign && cursor.pos < bitSize) {
      int bitpos0 = cursor.pos;
      int bitpos1 = (cursor.pos + 7) & ~7; 
      
      bool canAlign = true;
      while (canAlign && bitpos0 < bitpos1) {
        int bit = srcSpan[bitpos0 ~/ 8] & (1 << (7 - bitpos0 % 8));
        if (bit != 0) {
          canAlign = false;
        } else {
          bitpos0++;
        }
      }
      if (canAlign) {
        cursor.pos = bitpos1;
      }
    }

    bitpos = cursor.pos;

    if (black) {
      _invertBuffer(scanlineBuf);
    }

    return scanlineBuf;
  }

  void _invertBuffer(Uint8List buf) {
    for (int i = 0; i < buf.length; i++) {
      buf[i] = ~buf[i];
    }
  }

  @override
  int getSrcOffset() {
    return math.min((bitpos + 7) ~/ 8, srcSpan.length);
  }
}

// ============================================================================
// Internal Helpers
// ============================================================================

class _Cursor {
  int pos;
  _Cursor(this.pos);
}

bool _nextBit(Uint8List srcBuf, _Cursor cursor) {
  int pos = cursor.pos++;
  if (pos ~/ 8 >= srcBuf.length) return false;
  return (srcBuf[pos ~/ 8] & (1 << (7 - pos % 8))) != 0;
}

int _findBit(Uint8List dataBuf, int maxPos, int startPos, bool bit) {
  if (startPos >= maxPos) {
    return maxPos;
  }

  final int bitXor = bit ? 0x00 : 0xff;
  int bitOffset = startPos % 8;
  int bytePos = startPos ~/ 8;

  if (bitOffset != 0) {
    if (bytePos >= dataBuf.length) return maxPos;
    int data = (dataBuf[bytePos] ^ bitXor) & (0xff >> bitOffset);
    if (data != 0) {
      return bytePos * 8 + kOneLeadPos[data];
    }
    startPos += (8 - bitOffset);
    bytePos++;
  }

  int maxByte = (maxPos + 7) ~/ 8;
  maxByte = math.min(maxByte, dataBuf.length);

  while (bytePos < maxByte) {
    int data = dataBuf[bytePos] ^ bitXor;
    if (data != 0) {
      return math.min(bytePos * 8 + kOneLeadPos[data], maxPos);
    }
    bytePos++;
  }
  return maxPos;
}

void _faxG4FindB1B2(Uint8List refBuf, int columns, int a0, bool a0color, List<int> b1b2) {
  bool firstBit = true; 
  if (a0 >= 0) {
    if (a0 ~/ 8 < refBuf.length) {
       firstBit = (refBuf[a0 ~/ 8] & (1 << (7 - a0 % 8))) != 0;
    } else {
       firstBit = false; 
    }
  }

  int b1 = _findBit(refBuf, columns, a0 + 1, !firstBit);
  
  if (b1 >= columns) {
    b1b2[0] = columns;
    b1b2[1] = columns;
    return;
  }
  
  if (firstBit == !a0color) {
     b1 = _findBit(refBuf, columns, b1 + 1, firstBit);
     firstBit = !firstBit;
  }
  
  if (b1 >= columns) {
    b1b2[0] = columns;
    b1b2[1] = columns;
    return;
  }
  
  b1b2[0] = b1;
  b1b2[1] = _findBit(refBuf, columns, b1 + 1, !firstBit); 
}


void _faxFillBits(Uint8List destBuf, int columns, int startPos, int endPos) {
  startPos = math.max(startPos, 0);
  endPos = endPos.clamp(0, columns);
  if (startPos >= endPos) {
    return;
  }

  final int firstByte = startPos ~/ 8;
  final int lastByte = (endPos - 1) ~/ 8;
  
  if (firstByte == lastByte) {
    for (int i = startPos % 8; i <= (endPos - 1) % 8; i++) {
      destBuf[firstByte] &= ~(1 << (7 - i));
    }
    return;
  }

  for (int i = startPos % 8; i < 8; i++) {
    destBuf[firstByte] &= ~(1 << (7 - i));
  }
  
  for (int i = 0; i <= (endPos - 1) % 8; i++) {
    destBuf[lastByte] &= ~(1 << (7 - i));
  }

  if (lastByte > firstByte + 1) {
    destBuf.fillRange(firstByte + 1, lastByte, 0);
  }
}

int _faxGetRun(List<int> insArray, Uint8List srcBuf, _Cursor cursor) {
  final int bitSize = srcBuf.length * 8;
  int code = 0;
  int insOff = 0;
  
  while (true) {
    int ins = insArray[insOff];
    if (ins == 0xff) { 
       return -1;
    }
    
    insOff++; 
    
    if (cursor.pos >= bitSize) {
      return -1;
    }
    
    code <<= 1;
    if ((srcBuf[cursor.pos ~/ 8] & (1 << (7 - cursor.pos % 8))) != 0) {
      code++;
    }
    cursor.pos++;
    
    int nextOff = insOff + ins * 3;
    if (nextOff > insArray.length) return -1; 
    
    for (; insOff < nextOff; insOff += 3) {
      if (insArray[insOff] == code) {
        return insArray[insOff + 1] + insArray[insOff + 2] * 256;
      }
    }
  }
}

void _faxSkipEOL(Uint8List srcBuf, _Cursor cursor) {
  final int bitSize = srcBuf.length * 8;
  int startBit = cursor.pos;
  
  while (cursor.pos < bitSize) {
    if (!_nextBit(srcBuf, cursor)) {
      continue;
    }
    if (cursor.pos - startBit <= 11) {
      cursor.pos = startBit;
    }
    return;
  }
}

void _faxGet1DLine(Uint8List srcBuf, _Cursor cursor, Uint8List destBuf, int columns) {
  final int bitSize = srcBuf.length * 8;
  bool color = true; // White starts (run 0)
  int startPos = 0;
  
  while (true) {
    if (cursor.pos >= bitSize) {
      return;
    }
    
    int runLen = 0;
    while (true) {
      int run = _faxGetRun(color ? kFaxWhiteRunIns : kFaxBlackRunIns, srcBuf, cursor);
      if (run < 0) {
        while (cursor.pos < bitSize) {
          if (_nextBit(srcBuf, cursor)) {
            return;
          }
        }
        return;
      }
      runLen += run;
      if (run < 64) {
        break;
      }
    }
    
    if (!color) { // Black
      _faxFillBits(destBuf, columns, startPos, startPos + runLen);
    }
    
    startPos += runLen;
    if (startPos >= columns) {
      break;
    }
    
    color = !color;
  }
}

void _faxG4GetRow(Uint8List srcBuf, _Cursor cursor, Uint8List destBuf, Uint8List refBuf, int columns) {
  int a0 = -1;
  bool a0color = true; // White
  final int bitSize = srcBuf.length * 8;
  
  List<int> b1b2 = [0, 0];
  
  while (true) {
    if (cursor.pos >= bitSize) {
      return;
    }
    
    _faxG4FindB1B2(refBuf, columns, a0, a0color, b1b2);
    int b1 = b1b2[0];
    int b2 = b1b2[1];
    
    int vDelta = 0;
    if (!_nextBit(srcBuf, cursor)) { // 0
      if (cursor.pos >= bitSize) return;
      
      bool bit1 = _nextBit(srcBuf, cursor);
      if (cursor.pos >= bitSize) return;
      bool bit2 = _nextBit(srcBuf, cursor);
      
      if (bit1) { // 01
        // VR(1) or VL(1)
        vDelta = bit2 ? 1 : -1;
      } else if (bit2) { // 001
        // Horizontal Mode
        int runLen1 = 0;
        while (true) {
          int run = _faxGetRun(
              a0color ? kFaxWhiteRunIns : kFaxBlackRunIns,
              srcBuf, cursor);
          if (run < 0) return; // Error
          runLen1 += run;
          if (run < 64) break;
        }
        
        if (a0 < 0) runLen1++; 

        int a1 = a0 + runLen1;
        if (!a0color) {
          _faxFillBits(destBuf, columns, a0, a1);
        }
        
        int runLen2 = 0;
        while (true) {
           int run = _faxGetRun(
              a0color ? kFaxBlackRunIns : kFaxWhiteRunIns,
              srcBuf, cursor);
           if (run < 0) return;
           runLen2 += run;
           if (run < 64) break;
        }
        
        int a2 = a1 + runLen2;
        if (a0color) {
          _faxFillBits(destBuf, columns, a1, a2);
        }
        a0 = a2;
        if (a0 < columns) continue;
        return;
      } else { // 000
        if (cursor.pos >= bitSize) return;
        
        if (_nextBit(srcBuf, cursor)) { // 0001
          // Pass Mode
          if (!a0color) {
            _faxFillBits(destBuf, columns, a0, b2);
          }
          if (b2 >= columns) return;
          a0 = b2;
          continue;
        }
        
        // 0000
        if (cursor.pos >= bitSize) return;
        
        bool nextBit1 = _nextBit(srcBuf, cursor);
        if (cursor.pos >= bitSize) return;
        bool nextBit2 = _nextBit(srcBuf, cursor);
        
        if (nextBit1) { // 00001
           // VR(2) or VL(2)
           vDelta = nextBit2 ? 2 : -2;
        } else if (nextBit2) { // 000001
           if (cursor.pos >= bitSize) return;
           // VR(3) or VL(3)
           vDelta = _nextBit(srcBuf, cursor) ? 3 : -3;
        } else { // 000000
           if (cursor.pos >= bitSize) return;
           // Extension
           if (_nextBit(srcBuf, cursor)) {
             // 0000001
             cursor.pos += 3;
             continue; // Uncompressed?
           }
           cursor.pos += 5; // EOF?
           return;
        }
      }
    } else {
      // 1 -> Vertical 0
      vDelta = 0;
    }
    
    int a1 = b1 + vDelta;
    if (!a0color) {
      _faxFillBits(destBuf, columns, a0, a1);
    }
    if (a1 >= columns) return;
    if (a0 >= a1) return; // Monotonic increase required
    
    a0 = a1;
    a0color = !a0color;
  }
}
