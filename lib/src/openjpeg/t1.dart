// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tier-1 coding (T1) - Code-block coding.
/// 
/// Port of t1.c from OpenJPEG library.
/// Implements encoding/decoding of code-blocks.
library;

import 'dart:typed_data';

import 'mqc.dart';
import 'openjpeg_types.dart';

// ==========================================================
//   T1 Constants
// ==========================================================

/// Context labels for significance propagation
class T1Context {
  T1Context._();
  
  static const int sigNe = 0; // NE neighbor significant
  static const int sigSe = 1;
  static const int sigSw = 2;
  static const int sigNw = 3;
  static const int sigN = 4;
  static const int sigE = 5;
  static const int sigS = 6;
  static const int sigW = 7;
  static const int sigOth = 8;
  
  static const int run = 9;
  static const int uni = 10;
  static const int agr = 11;
  static const int zc = 12;
  static const int mag = 13; // Magnitude refinement
  static const int sc = 14; // Sign coding
  
  static const int numCtxs = 18;
}

/// T1 flags
class T1Flags {
  T1Flags._();
  
  static const int sig = 0x0001;    // Significant
  static const int visit = 0x0002; // Visited
  static const int refine = 0x0004; // Refinement pass
  static const int sigN = 0x0010;
  static const int sigE = 0x0020;
  static const int sigS = 0x0040;
  static const int sigW = 0x0080;
  static const int sigNe = 0x0100;
  static const int sigSe = 0x0200;
  static const int sigSw = 0x0400;
  static const int sigNw = 0x0800;
  static const int sign = 0x1000; // Negative sign
}

// ==========================================================
//   Code-block structure
// ==========================================================

/// Code-block for T1 coding
class T1CodeBlock {
  /// Block position x
  int x0;
  
  /// Block position y
  int y0;
  
  /// Block width
  int width;
  
  /// Block height
  int height;
  
  /// Coded data
  Uint8List? data;
  
  /// Number of coding passes
  int numPasses;
  
  /// Total length in bytes
  int totalLength;
  
  /// Number of zero bit-planes
  int numZeroBitPlanes;
  
  /// Length of each pass
  List<int> passLengths;
  
  /// Lengths included
  List<bool> passLengthsIncluded;

  T1CodeBlock({
    this.x0 = 0,
    this.y0 = 0,
    this.width = 0,
    this.height = 0,
    this.data,
    this.numPasses = 0,
    this.totalLength = 0,
    this.numZeroBitPlanes = 0,
    List<int>? passLengths,
    List<bool>? passLengthsIncluded,
  })  : passLengths = passLengths ?? [],
        passLengthsIncluded = passLengthsIncluded ?? [];
}

// ==========================================================
//   T1 Decoder
// ==========================================================

/// Tier-1 decoder
class T1Decoder {
  /// MQ decoder
  final MqDecoder _mqc = MqDecoder();
  
  /// Sample data (coefficients)
  Int32List? _data;
  
  /// Flags
  Int32List? _flags;
  
  /// Width including padding
  int _w = 0;
  
  /// Height including padding
  int _h = 0;
  
  /// Data stride
  int _dataStride = 0;
  
  /// Flags stride
  int _flagsStride = 0;

  T1Decoder();

  /// Decodes a code-block
  bool decode(
    T1CodeBlock cblk,
    int orient,
    int roiShift,
    int cblkStyle,
    Int32List outData,
    int outStride,
  ) {
    final w = cblk.width;
    final h = cblk.height;
    
    if (w == 0 || h == 0) return true;
    
    // Allocate working buffers with border
    _w = w;
    _h = h;
    _dataStride = w;
    _flagsStride = w + 2;
    
    _data = Int32List(w * h);
    _flags = Int32List((w + 2) * (h + 2));
    
    // Initialize MQ decoder
    if (cblk.data != null && cblk.totalLength > 0) {
      _mqc.init(cblk.data!, 0, cblk.totalLength);
    } else {
      // Empty code-block
      return true;
    }
    
    // Reset contexts
    _resetContexts();
    
    // Get number of bit-planes
    final numBps = roiShift + cblk.numZeroBitPlanes + 
        _log2Floor(cblk.numPasses ~/ 3 + 1) + 1;
    
    // Decode passes
    var bpno = numBps - 1;
    var passtype = 2; // Start with cleanup pass
    var passno = 0;
    
    while (passno < cblk.numPasses) {
      switch (passtype) {
        case 0: // Significance propagation
          _sigPropPass(bpno, orient, cblkStyle);
          break;
        case 1: // Magnitude refinement
          _magRefPass(bpno, cblkStyle);
          break;
        case 2: // Cleanup
          _cleanupPass(bpno, orient, cblkStyle);
          break;
      }
      
      passtype = (passtype + 1) % 3;
      if (passtype == 0) {
        bpno--;
      }
      passno++;
    }
    
    // Copy to output with proper scaling
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final val = _data![y * _dataStride + x];
        outData[y * outStride + x] = val;
      }
    }
    
    return true;
  }

  void _resetContexts() {
    for (var i = 0; i < T1Context.numCtxs; i++) {
      _mqc.resetContext(i, 0);
    }
    // Set run-length context
    _mqc.resetContext(T1Context.run, 0);
    _mqc.resetContext(T1Context.uni, 0);
  }

  /// Significance propagation pass
  void _sigPropPass(int bpno, int orient, int cblkStyle) {
    final one = 1 << bpno;
    final half = one >> 1;
    
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final flagIdx = (y + 1) * _flagsStride + (x + 1);
        final dataIdx = y * _dataStride + x;
        final flag = _flags![flagIdx];
        
        // Skip if already significant or no significant neighbors
        if ((flag & T1Flags.sig) != 0) continue;
        if ((flag & 0xFF0) == 0) continue; // No significant neighbors
        
        // Set context based on neighbors
        final ctx = _getZcContext(flag, orient);
        _mqc.setContext(ctx);
        
        if (_mqc.decode() != 0) {
          // Became significant
          _mqc.setContext(T1Context.sc);
          final sign = _mqc.decode();
          
          _data![dataIdx] = sign != 0 ? -(one | half) : (one | half);
          _flags![flagIdx] |= T1Flags.sig | T1Flags.visit;
          if (sign != 0) _flags![flagIdx] |= T1Flags.sign;
          
          _updateNeighborFlags(x, y);
        }
        _flags![flagIdx] |= T1Flags.visit;
      }
    }
    
    // Clear visit flags
    for (var i = 0; i < _flags!.length; i++) {
      _flags![i] &= ~T1Flags.visit;
    }
  }

  /// Magnitude refinement pass
  void _magRefPass(int bpno, int cblkStyle) {
    final one = 1 << bpno;
    
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final flagIdx = (y + 1) * _flagsStride + (x + 1);
        final dataIdx = y * _dataStride + x;
        final flag = _flags![flagIdx];
        
        // Only refine significant coefficients
        if ((flag & (T1Flags.sig | T1Flags.visit)) != T1Flags.sig) continue;
        
        // Get context
        final ctx = _getMagContext(flag);
        _mqc.setContext(ctx);
        
        if (_mqc.decode() != 0) {
          _data![dataIdx] |= one;
        }
        
        _flags![flagIdx] |= T1Flags.visit | T1Flags.refine;
      }
    }
    
    // Clear visit flags
    for (var i = 0; i < _flags!.length; i++) {
      _flags![i] &= ~T1Flags.visit;
    }
  }

  /// Cleanup pass
  void _cleanupPass(int bpno, int orient, int cblkStyle) {
    final one = 1 << bpno;
    final half = one >> 1;
    
    for (var y = 0; y < _h; y += 4) {
      for (var x = 0; x < _w; x++) {
        // Check for run-length mode
        var runLen = 0;
        
        if (_canUseRunMode(x, y)) {
          _mqc.setContext(T1Context.run);
          runLen = _mqc.decode() != 0 ? 0 : 4;
          
          if (runLen == 0) {
            // Decode uniform context for position
            _mqc.setContext(T1Context.uni);
            runLen = _mqc.decode();
            runLen = (runLen << 1) | _mqc.decode();
          }
        }
        
        for (var j = runLen; j < 4 && (y + j) < _h; j++) {
          final yy = y + j;
          final flagIdx = (yy + 1) * _flagsStride + (x + 1);
          final dataIdx = yy * _dataStride + x;
          final flag = _flags![flagIdx];
          
          if ((flag & T1Flags.sig) != 0) continue;
          
          final ctx = _getZcContext(flag, orient);
          _mqc.setContext(ctx);
          
          if (_mqc.decode() != 0) {
            // Became significant
            _mqc.setContext(T1Context.sc);
            final sign = _mqc.decode();
            
            _data![dataIdx] = sign != 0 ? -(one | half) : (one | half);
            _flags![flagIdx] |= T1Flags.sig;
            if (sign != 0) _flags![flagIdx] |= T1Flags.sign;
            
            _updateNeighborFlags(x, yy);
          }
        }
      }
    }
  }

  bool _canUseRunMode(int x, int y) {
    // Can use run mode if first column, all 4 samples exist, and no significant neighbors
    if (x != 0) return false;
    if (y + 3 >= _h) return false;
    
    for (var j = 0; j < 4; j++) {
      final flag = _flags![(y + j + 1) * _flagsStride + 1];
      if ((flag & (T1Flags.sig | 0xFF0)) != 0) return false;
    }
    
    return true;
  }

  int _getZcContext(int flag, int orient) {
    // Simplified zero-coding context
    final h = (((flag & T1Flags.sigE) != 0) ? 1 : 0) +
              (((flag & T1Flags.sigW) != 0) ? 1 : 0);
    final v = (((flag & T1Flags.sigN) != 0) ? 1 : 0) +
              (((flag & T1Flags.sigS) != 0) ? 1 : 0);
    final d = (((flag & T1Flags.sigNe) != 0) ? 1 : 0) +
              (((flag & T1Flags.sigNw) != 0) ? 1 : 0) +
              (((flag & T1Flags.sigSe) != 0) ? 1 : 0) +
              (((flag & T1Flags.sigSw) != 0) ? 1 : 0);

    // Context depends on orientation
    switch (orient) {
      case 0: // LL or LH
        if (h == 2) return 8;
        if (h == 1) {
          if (v >= 1) return 7;
          if (d >= 1) return 6;
          return 5;
        }
        if (v == 2) return 4;
        if (v == 1) return d >= 1 ? 3 : 2;
        return d >= 2 ? 1 : 0;
      case 1: // HL
        if (v == 2) return 8;
        if (v == 1) {
          if (h >= 1) return 7;
          if (d >= 1) return 6;
          return 5;
        }
        if (h == 2) return 4;
        if (h == 1) return d >= 1 ? 3 : 2;
        return d >= 2 ? 1 : 0;
      default: // HH
        final hv = h + v;
        if (d >= 3) return 8;
        if (d == 2) return hv >= 1 ? 7 : 6;
        if (d == 1) return hv >= 2 ? 5 : (hv == 1 ? 4 : 3);
        return hv >= 2 ? 2 : (hv == 1 ? 1 : 0);
    }
  }

  int _getMagContext(int flag) {
    // Magnitude refinement context
    if ((flag & T1Flags.refine) != 0) {
      return T1Context.mag + 2;
    }
    
    final neighborSig = (flag & 0xFF0) != 0;
    return neighborSig ? T1Context.mag + 1 : T1Context.mag;
  }

  void _updateNeighborFlags(int x, int y) {
    final center = (y + 1) * _flagsStride + (x + 1);
    
    // Update cardinal neighbors
    if (y > 0) _flags![center - _flagsStride] |= T1Flags.sigS;
    if (y < _h - 1) _flags![center + _flagsStride] |= T1Flags.sigN;
    if (x > 0) _flags![center - 1] |= T1Flags.sigE;
    if (x < _w - 1) _flags![center + 1] |= T1Flags.sigW;
    
    // Update diagonal neighbors
    if (y > 0 && x > 0) _flags![center - _flagsStride - 1] |= T1Flags.sigSe;
    if (y > 0 && x < _w - 1) _flags![center - _flagsStride + 1] |= T1Flags.sigSw;
    if (y < _h - 1 && x > 0) _flags![center + _flagsStride - 1] |= T1Flags.sigNe;
    if (y < _h - 1 && x < _w - 1) _flags![center + _flagsStride + 1] |= T1Flags.sigNw;
  }

  static int _log2Floor(int val) {
    if (val <= 0) return 0;
    var result = 0;
    while (val > 1) {
      val >>= 1;
      result++;
    }
    return result;
  }
}
