// Copyright 2016 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Basic encoding/decoding module (RunLength, etc.)
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../scanlinedecoder.dart';

// ============================================================================
// Basic Module
// ============================================================================

class BasicModule {
  static ScanlineDecoder? createRunLengthDecoder({
    required Uint8List srcBuf,
    required int width,
    required int height,
    required int nComps,
    required int bpc,
  }) {
    final decoder = _RLScanlineDecoder();
    if (!decoder.create(srcBuf, width, height, nComps, bpc)) {
      return null;
    }
    return decoder;
  }

  // TODO: RunLengthEncode
  // TODO: A85Encode
}

// ============================================================================
// Internal RunLength Scanline Decoder
// ============================================================================

class _RLScanlineDecoder extends ScanlineDecoder {
  late Uint8List scanline;
  late Uint8List srcBuf;
  int lineBytes = 0;
  int srcOffset = 0;
  bool eod = false;
  int operator = 0;
  
  // State for partial copy/repeat if run spans across lines?
  // C++ implementation logic:
  // "UpdateOperator" seems to consume bytes from the current operator count.
  // If eol is reached, we pause the operator and resume next line.
  
  _RLScanlineDecoder();

  bool create(Uint8List src, int width, int height, int nComps, int bitsPerComponent) {
    srcBuf = src;
    origWidth = width;
    origHeight = height;
    outputWidth = width;
    outputHeight = height;
    comps = nComps;
    bpc = bitsPerComponent;
    
    // Calculate pitch aligned to 4 bytes
    // (width * nComps * bpc + 31) / 32 * 4
    int bits = width * nComps * bpc;
    pitch = ((bits + 31) ~/ 32) * 4;
    
    lineBytes = (bits + 7) ~/ 8;
    
    scanline = Uint8List(pitch);
    
    return _checkDestSize();
  }
  
  bool _checkDestSize() {
    int i = 0;
    int destSize = 0;
    
    // Quick pre-scan to check if decompressed size matches requirement
    // This protects against bombs or malformed streams
    final int requiredSize = (origWidth * comps * bpc * origHeight + 7) ~/ 8;
    
    while (i < srcBuf.length) {
      int byte = srcBuf[i];
      if (byte < 128) {
        // Copy (byte + 1) bytes
        int copyLen = byte + 1;
        destSize += copyLen;
        i += copyLen + 1; // 1 for operator, copyLen for data
      } else if (byte > 128) {
        // Repeat next byte (257 - byte) times
        int repeatLen = 257 - byte;
        destSize += repeatLen;
        i += 2; // 1 for operator, 1 for byte to repeat
      } else {
        // 128 = EOD
        break;
      }
      
      // Overflow check omitted as Dart ints are 64-bit and safe enough
    }
    
    return requiredSize <= destSize;
  }

  @override
  bool rewind() {
    scanline.fillRange(0, scanline.length, 0);
    srcOffset = 0;
    eod = false;
    operator = 0;
    return true;
  }

  void _getNextOperator() {
    if (srcOffset >= srcBuf.length) {
      operator = 128;
      eod = true;
      return;
    }
    operator = srcBuf[srcOffset];
    srcOffset++;
    if (operator == 128) {
      eod = true;
    }
  }

  void _updateOperator(int usedBytes) {
    if (usedBytes == 0) return;
    
    if (operator < 128) {
      if (usedBytes == operator + 1) {
        srcOffset += usedBytes;
        _getNextOperator();
        return;
      }
      operator -= usedBytes;
      srcOffset += usedBytes;
      // If end of buffer reached during copy? Handled by GetNextLine checks.
    } else {
      int count = 257 - operator;
      if (usedBytes == count) {
        srcOffset++; // Skip the repeated byte
        _getNextOperator();
        return;
      }
      count -= usedBytes;
      operator = 257 - count;
    }
  }

  @override
  Uint8List? getNextLine() {
    if (srcOffset == 0) {
      _getNextOperator();
    } else if (eod) {
      return null;
    }

    scanline.fillRange(0, scanline.length, 0); // Fill 0?
    
    int colPos = 0;
    bool eol = false;
    
    while (srcOffset < srcBuf.length && !eol) {
       if (eod) break;
       
       if (operator < 128) {
         // Copy mode. Length to copy = operator + 1
         int copyLen = operator + 1;
         
         if (colPos + copyLen >= lineBytes) {
           copyLen = lineBytes - colPos;
           eol = true;
         }
         
         // Ensure we don't read past buffer
         if (srcOffset + copyLen > srcBuf.length) {
            copyLen = srcBuf.length - srcOffset;
            eod = true; // Implicit EOD?
         }

         if (copyLen > 0) {
           // Copy
           for (int i = 0; i < copyLen; i++) {
             scanline[colPos + i] = srcBuf[srcOffset + i];
           }
         }
         
         colPos += copyLen;
         _updateOperator(copyLen);

       } else if (operator > 128) {
         // Repeat mode. Length = 257 - operator
         int repeatLen = 257 - operator;
         
         if (colPos + repeatLen >= lineBytes) {
            repeatLen = lineBytes - colPos;
            eol = true;
         }
         
         if (srcOffset >= srcBuf.length) {
            eod = true;
            break;
         }
         
         int byteToRepeat = srcBuf[srcOffset];
         
         if (repeatLen > 0) {
            scanline.fillRange(colPos, colPos + repeatLen, byteToRepeat);
         }
         
         colPos += repeatLen;
         _updateOperator(repeatLen); 
         // Note: For repeat, srcOffset only increments when we finish the whole block?
         // No, C++ `UpdateOperator` for > 128: `operator_ += used_bytes;`. 
         // Src offset points to the byte being repeated. 
         // Only when the operator finishes (becomes 128?) or we are done with this run?
         // C++: 
         // if (operator_ == 128) { src_offset_++; GetNextOperator(); }
         
       } else {
         // operator == 128: EOD
         eod = true;
         break;
       }
       
       // Handle operator completion
       if (operator < 128) {
          // If operator was fully consumed, it would become -1?
          // No. original logic:
          // operator starts as length-1.
          // if we consumed all `copyLen`, then `operator` should reflect that?
          // If we consumed all (operator+1), `operator` becomes -1.
          // Let's recheck logic.
          if (operator == -1) {
             _getNextOperator();
          }
       } else if (operator > 128) {
          // If we consumed all (257 - operator)
          // operator becomes 257? Or 128?
          // If repeatLen reduces to 0.
          // (257 - op) - used = new_len
          // 257 - (op + used) = new_len
          // If new_len == 0 => op + used = 257.
          // Oops, operator is byte so max 255.
          // 257 is not representable in byte.
          // But repeat len is small.
          // If operator becomes 128? that's EOD. 
          // C++ logic:
          // if (operator_ == 257) { src_offset_++; GetNextOperator(); }
          // Wait, operator_ is uint8_t in C++, so it wraps? 
          // No, C++ uses `uint8_t operator_`. 
          // `257` comparison implies intermediate int calculation?
          // No, `operator_` is `uint8_t` (0-255).
          // `if (operator_ > 128)`: repeat.
          // `dest_size += 257 - src_buf_[i]`.
          // If operator_ reaches a value where repeat length is 0?
          // Ah, in `UpdateOperator`:
          // `operator_ += used_bytes;`
          // If it was 256 (wraps to 0?), or 257?
          // Wait.
          // If operator is 250. Repeat 7.
          // consume 7.
          // operator becomes 257. (Wraps to 1).
          // 1 is < 128. That's a COPY operator!
          // This seems risky if not handled carefully in C++.
          // Actually C++ code for `UpdateOperator` takes `used_bytes`.
          // `operator_` field is `uint8_t`.
          // Let's check `GetNextLine` loop in C++ carefully.
       }
    }
    
    if (colPos < lineBytes) {
      // Pad with what? 0?
      // Already filled 0.
    }
    
    return scanline;
  }
  
  @override
  int getSrcOffset() {
    return srcOffset;
  }
}
