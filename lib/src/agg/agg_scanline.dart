// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG Scanline classes for storing and iterating over horizontal spans.
library;

import 'dart:typed_data';
import 'agg_basics.dart';

// ============================================================================
// Span - A horizontal span of pixels with coverage values
// ============================================================================

/// A horizontal span of pixels with coverage values.
class Span {
  int x;
  int len;
  int coversOffset;

  Span([this.x = 0, this.len = 0, this.coversOffset = 0]);

  @override
  String toString() => 'Span(x: $x, len: $len)';
}

// ============================================================================
// ScanlineU8 - Unpacked scanline container
// ============================================================================

/// Unpacked scanline container class.
///
/// This class is used to transfer data from a scanline rasterizer
/// to the rendering buffer. It stores information of horizontal spans
/// to render into a pixel-map buffer.
///
/// Usage protocol:
/// 1. reset(minX, maxX)
/// 2. addCell() / addSpan() - accumulate scanline
/// 3. Call finalize(y) and render the scanline
/// 4. Call resetSpans() to prepare for the new scanline
class ScanlineU8 {
  Uint8List _covers = Uint8List(0);
  List<Span> _spans = [];
  int _minX = 0;
  int _lastX = 0x7FFFFFF0;
  int _y = 0;
  int _curSpanIdx = 0;

  ScanlineU8();

  /// Reset scanline for new row
  void reset(int minX, int maxX) {
    final maxLen = maxX - minX + 2;
    if (maxLen > _covers.length) {
      _covers = Uint8List(maxLen);
      _spans = List.generate(maxLen, (_) => Span());
    }
    _lastX = 0x7FFFFFF0;
    _minX = minX;
    _curSpanIdx = 0;
  }

  /// Add a single cell with coverage value
  void addCell(int x, int cover) {
    x -= _minX;
    _covers[x] = cover & 0xFF;
    
    if (x == _lastX + 1) {
      _spans[_curSpanIdx].len++;
    } else {
      _curSpanIdx++;
      _spans[_curSpanIdx].x = x + _minX;
      _spans[_curSpanIdx].len = 1;
      _spans[_curSpanIdx].coversOffset = x;
    }
    _lastX = x;
  }

  /// Add multiple cells with coverage values
  void addCells(int x, int len, Uint8List covers, int coversOffset) {
    x -= _minX;
    
    // Copy covers
    for (int i = 0; i < len; i++) {
      _covers[x + i] = covers[coversOffset + i];
    }
    
    if (x == _lastX + 1) {
      _spans[_curSpanIdx].len += len;
    } else {
      _curSpanIdx++;
      _spans[_curSpanIdx].x = x + _minX;
      _spans[_curSpanIdx].len = len;
      _spans[_curSpanIdx].coversOffset = x;
    }
    _lastX = x + len - 1;
  }

  /// Add a span with uniform coverage
  void addSpan(int x, int len, int cover) {
    x -= _minX;
    
    // Fill covers with uniform value
    for (int i = 0; i < len; i++) {
      _covers[x + i] = cover & 0xFF;
    }
    
    if (x == _lastX + 1) {
      _spans[_curSpanIdx].len += len;
    } else {
      _curSpanIdx++;
      _spans[_curSpanIdx].x = x + _minX;
      _spans[_curSpanIdx].len = len;
      _spans[_curSpanIdx].coversOffset = x;
    }
    _lastX = x + len - 1;
  }

  /// Finalize scanline with Y coordinate
  void finalize(int y) {
    _y = y;
  }

  /// Reset spans for next scanline
  void resetSpans() {
    _lastX = 0x7FFFFFF0;
    _curSpanIdx = 0;
  }

  /// Get Y coordinate
  int get y => _y;

  /// Get number of spans
  int get numSpans => _curSpanIdx;

  /// Check if scanline is empty
  bool get isEmpty => _curSpanIdx == 0;

  /// Get span at index (1-based for compatibility)
  Span getSpan(int idx) {
    if (idx >= 1 && idx <= _curSpanIdx) {
      return _spans[idx];
    }
    return Span();
  }

  /// Get covers array
  Uint8List get covers => _covers;

  /// Get cover value at offset
  int getCover(int offset) {
    if (offset >= 0 && offset < _covers.length) {
      return _covers[offset];
    }
    return 0;
  }

  /// Iterate over spans
  Iterable<Span> get spans sync* {
    for (int i = 1; i <= _curSpanIdx; i++) {
      yield _spans[i];
    }
  }
}

// ============================================================================
// ScanlineU8AM - Scanline with alpha mask
// ============================================================================

/// Scanline with alpha mask support.
class ScanlineU8AM extends ScanlineU8 {
  Uint8List? _alphaMask;
  int _alphaMaskY = 0;

  ScanlineU8AM();

  /// Set alpha mask
  void setAlphaMask(Uint8List mask, int y) {
    _alphaMask = mask;
    _alphaMaskY = y;
  }

  /// Clear alpha mask
  void clearAlphaMask() {
    _alphaMask = null;
  }

  @override
  void addCell(int x, int cover) {
    if (_alphaMask != null && x >= 0 && x < _alphaMask!.length) {
      cover = (cover * _alphaMask![x]) >> 8;
    }
    super.addCell(x, cover);
  }

  @override
  void addSpan(int x, int len, int cover) {
    if (_alphaMask != null) {
      final x0 = x - _minX;
      for (int i = 0; i < len; i++) {
        final mx = x + i;
        int c = cover;
        if (mx >= 0 && mx < _alphaMask!.length) {
          c = (c * _alphaMask![mx]) >> 8;
        }
        _covers[x0 + i] = c & 0xFF;
      }
      
      if (x - _minX == _lastX + 1) {
        _spans[_curSpanIdx].len += len;
      } else {
        _curSpanIdx++;
        _spans[_curSpanIdx].x = x;
        _spans[_curSpanIdx].len = len;
        _spans[_curSpanIdx].coversOffset = x - _minX;
      }
      _lastX = x - _minX + len - 1;
    } else {
      super.addSpan(x, len, cover);
    }
  }
}

// ============================================================================
// ScanlineBin - Binary scanline (no anti-aliasing)
// ============================================================================

/// Binary scanline without anti-aliasing coverage values.
/// 
/// Each span represents a fully opaque horizontal run of pixels.
class ScanlineBin {
  List<Span> _spans = [];
  int _lastX = 0x7FFFFFF0;
  int _y = 0;
  int _curSpanIdx = 0;

  ScanlineBin();

  /// Reset scanline for new row
  void reset(int minX, int maxX) {
    final maxLen = maxX - minX + 2;
    if (maxLen > _spans.length) {
      _spans = List.generate(maxLen, (_) => Span());
    }
    _lastX = 0x7FFFFFF0;
    _curSpanIdx = 0;
  }

  /// Add a single cell
  void addCell(int x, int cover) {
    if (x == _lastX + 1) {
      _spans[_curSpanIdx].len++;
    } else {
      _curSpanIdx++;
      _spans[_curSpanIdx].x = x;
      _spans[_curSpanIdx].len = 1;
    }
    _lastX = x;
  }

  /// Add a span
  void addSpan(int x, int len, int cover) {
    if (x == _lastX + 1) {
      _spans[_curSpanIdx].len += len;
    } else {
      _curSpanIdx++;
      _spans[_curSpanIdx].x = x;
      _spans[_curSpanIdx].len = len;
    }
    _lastX = x + len - 1;
  }

  /// Finalize scanline with Y coordinate
  void finalize(int y) {
    _y = y;
  }

  /// Reset spans for next scanline
  void resetSpans() {
    _lastX = 0x7FFFFFF0;
    _curSpanIdx = 0;
  }

  /// Get Y coordinate
  int get y => _y;

  /// Get number of spans
  int get numSpans => _curSpanIdx;

  /// Check if scanline is empty
  bool get isEmpty => _curSpanIdx == 0;

  /// Get span at index (1-based)
  Span getSpan(int idx) {
    if (idx >= 1 && idx <= _curSpanIdx) {
      return _spans[idx];
    }
    return Span();
  }

  /// Iterate over spans
  Iterable<Span> get spans sync* {
    for (int i = 1; i <= _curSpanIdx; i++) {
      yield _spans[i];
    }
  }
}

// ============================================================================
// ScanlineP8 - Packed scanline (for solid fills)
// ============================================================================

/// Packed scanline - stores spans with a single cover value per span.
/// 
/// More memory efficient for solid fills where coverage doesn't vary
/// within a span.
class ScanlineP8 {
  List<({int x, int len, int cover})> _spans = [];
  int _lastX = 0x7FFFFFF0;
  int _y = 0;
  int _coverLast = 0;

  ScanlineP8();

  /// Reset scanline for new row
  void reset(int minX, int maxX) {
    _spans.clear();
    _lastX = 0x7FFFFFF0;
    _coverLast = 0;
  }

  /// Add a single cell
  void addCell(int x, int cover) {
    if (x == _lastX + 1 && cover == _coverLast) {
      // Extend last span
      final last = _spans.last;
      _spans[_spans.length - 1] = (x: last.x, len: last.len + 1, cover: cover);
    } else {
      _spans.add((x: x, len: 1, cover: cover));
      _coverLast = cover;
    }
    _lastX = x;
  }

  /// Add a span
  void addSpan(int x, int len, int cover) {
    if (x == _lastX + 1 && cover == _coverLast) {
      // Extend last span
      final last = _spans.last;
      _spans[_spans.length - 1] = (x: last.x, len: last.len + len, cover: cover);
    } else {
      _spans.add((x: x, len: len, cover: cover));
      _coverLast = cover;
    }
    _lastX = x + len - 1;
  }

  /// Finalize scanline with Y coordinate
  void finalize(int y) {
    _y = y;
  }

  /// Reset spans for next scanline
  void resetSpans() {
    _spans.clear();
    _lastX = 0x7FFFFFF0;
    _coverLast = 0;
  }

  /// Get Y coordinate
  int get y => _y;

  /// Get number of spans
  int get numSpans => _spans.length;

  /// Check if scanline is empty
  bool get isEmpty => _spans.isEmpty;

  /// Iterate over spans
  Iterable<({int x, int len, int cover})> get spans => _spans;
}
