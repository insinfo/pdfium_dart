// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG Rendering Buffer - provides access to pixel data in memory.
library;

import 'dart:typed_data';
import 'agg_basics.dart';

// ============================================================================
// RowInfo - Information about a row in the buffer
// ============================================================================

/// Information about a row of pixels
class RowInfo {
  final int x1;
  final int x2;
  final int offset;

  RowInfo(this.x1, this.x2, this.offset);
}

// ============================================================================
// RenderingBuffer - Main rendering buffer class
// ============================================================================

/// A rendering buffer provides access to pixel data organized as rows.
///
/// The buffer supports both top-down (positive stride) and bottom-up
/// (negative stride) row ordering, which is useful for interoperability
/// with different image formats and APIs.
class RenderingBuffer {
  Uint8List? _buf;
  int _width = 0;
  int _height = 0;
  int _stride = 0;
  int _startOffset = 0;

  /// Create an empty rendering buffer
  RenderingBuffer();

  /// Create a rendering buffer with attached data
  RenderingBuffer.attach(Uint8List buf, int width, int height, int stride) {
    attach(buf, width, height, stride);
  }

  /// Create a new rendering buffer with allocated memory
  factory RenderingBuffer.create(int width, int height, int bytesPerPixel) {
    final stride = width * bytesPerPixel;
    final buf = Uint8List(height * stride);
    return RenderingBuffer.attach(buf, width, height, stride);
  }

  /// Attach buffer data
  void attach(Uint8List buf, int width, int height, int stride) {
    _buf = buf;
    _width = width;
    _height = height;
    _stride = stride;

    if (stride < 0) {
      _startOffset = -(height - 1) * stride;
    } else {
      _startOffset = 0;
    }
  }

  /// Detach buffer data
  void detach() {
    _buf = null;
    _width = 0;
    _height = 0;
    _stride = 0;
    _startOffset = 0;
  }

  /// Get the raw buffer
  Uint8List? get buf => _buf;

  /// Get buffer width in pixels
  int get width => _width;

  /// Get buffer height in pixels
  int get height => _height;

  /// Get stride (bytes per row, can be negative)
  int get stride => _stride;

  /// Get absolute stride
  int get strideAbs => _stride < 0 ? -_stride : _stride;

  /// Check if buffer is attached
  bool get isAttached => _buf != null;

  /// Get offset to start of row y
  int rowOffset(int y) {
    return _startOffset + y * _stride;
  }

  /// Get row data info
  RowInfo row(int y) {
    return RowInfo(0, _width - 1, rowOffset(y));
  }

  /// Get a view of row y as Uint8List
  Uint8List? rowPtr(int y) {
    if (_buf == null || y < 0 || y >= _height) return null;
    final offset = rowOffset(y);
    return Uint8List.sublistView(_buf!, offset, offset + strideAbs);
  }

  /// Get pixel at (x, y) - returns offset into buffer
  int pixelOffset(int x, int y, int bytesPerPixel) {
    return rowOffset(y) + x * bytesPerPixel;
  }

  /// Copy from another rendering buffer
  void copyFrom(RenderingBuffer src) {
    if (_buf == null || src._buf == null) return;

    int h = _height;
    if (src._height < h) h = src._height;

    int l = strideAbs;
    if (src.strideAbs < l) l = src.strideAbs;

    for (int y = 0; y < h; y++) {
      final dstOffset = rowOffset(y);
      final srcOffset = src.rowOffset(y);
      _buf!.setRange(dstOffset, dstOffset + l, src._buf!, srcOffset);
    }
  }

  /// Clear buffer with a single byte value
  void clear(int value) {
    if (_buf == null) return;
    _buf!.fillRange(0, _buf!.length, value);
  }

  /// Clear buffer with a pattern (e.g., 4 bytes for RGBA)
  void clearPattern(List<int> pattern) {
    if (_buf == null || pattern.isEmpty) return;

    final patternLength = pattern.length;
    final bufLength = _buf!.length;

    for (int i = 0; i < bufLength; i += patternLength) {
      for (int j = 0; j < patternLength && i + j < bufLength; j++) {
        _buf![i + j] = pattern[j];
      }
    }
  }

  /// Fill rectangle with single byte value
  void fillRect(int x, int y, int w, int h, int value) {
    if (_buf == null) return;

    // Clip to buffer bounds
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > _width) w = _width - x;
    if (y + h > _height) h = _height - y;

    if (w <= 0 || h <= 0) return;

    for (int row = y; row < y + h; row++) {
      final offset = rowOffset(row) + x;
      _buf!.fillRange(offset, offset + w, value);
    }
  }
}

// ============================================================================
// RenderingBuffer32 - Rendering buffer with 32-bit pixel access
// ============================================================================

/// Rendering buffer optimized for 32-bit (4 bytes per pixel) access.
class RenderingBuffer32 extends RenderingBuffer {
  static const int bytesPerPixel = 4;

  RenderingBuffer32() : super();

  RenderingBuffer32.attach(Uint8List buf, int width, int height, int stride)
    : super.attach(buf, width, height, stride);

  factory RenderingBuffer32.create(int width, int height) {
    final stride = width * bytesPerPixel;
    final buf = Uint8List(height * stride);
    return RenderingBuffer32.attach(buf, width, height, stride);
  }

  /// Get pixel as 32-bit value (RGBA)
  int getPixel(int x, int y) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return 0;
    }
    final offset = pixelOffset(x, y, bytesPerPixel);
    return buf![offset] |
           (buf![offset + 1] << 8) |
           (buf![offset + 2] << 16) |
           (buf![offset + 3] << 24);
  }

  /// Set pixel as 32-bit value (RGBA)
  void setPixel(int x, int y, int rgba) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }
    final offset = pixelOffset(x, y, bytesPerPixel);
    buf![offset] = rgba & 0xFF;
    buf![offset + 1] = (rgba >> 8) & 0xFF;
    buf![offset + 2] = (rgba >> 16) & 0xFF;
    buf![offset + 3] = (rgba >> 24) & 0xFF;
  }

  /// Get pixel components
  ({int r, int g, int b, int a}) getPixelRgba(int x, int y) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return (r: 0, g: 0, b: 0, a: 0);
    }
    final offset = pixelOffset(x, y, bytesPerPixel);
    return (
      r: buf![offset],
      g: buf![offset + 1],
      b: buf![offset + 2],
      a: buf![offset + 3],
    );
  }

  /// Set pixel components
  void setPixelRgba(int x, int y, int r, int g, int b, int a) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }
    final offset = pixelOffset(x, y, bytesPerPixel);
    buf![offset] = r;
    buf![offset + 1] = g;
    buf![offset + 2] = b;
    buf![offset + 3] = a;
  }

  /// Fill rectangle with RGBA color
  void fillRectRgba(int x, int y, int w, int h, int r, int g, int b, int a) {
    if (buf == null) return;

    // Clip to buffer bounds
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > width) w = width - x;
    if (y + h > height) h = height - y;

    if (w <= 0 || h <= 0) return;

    for (int row = y; row < y + h; row++) {
      for (int col = x; col < x + w; col++) {
        setPixelRgba(col, row, r, g, b, a);
      }
    }
  }

  /// Blend source over destination using alpha
  void blendPixel(int x, int y, int r, int g, int b, int a) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }
    if (a == 0) return;
    if (a == 255) {
      setPixelRgba(x, y, r, g, b, 255);
      return;
    }

    final dst = getPixelRgba(x, y);
    final invA = 255 - a;

    final newR = ((r * a + dst.r * invA) ~/ 255).clamp(0, 255);
    final newG = ((g * a + dst.g * invA) ~/ 255).clamp(0, 255);
    final newB = ((b * a + dst.b * invA) ~/ 255).clamp(0, 255);
    final newA = (a + dst.a - (a * dst.a) ~/ 255).clamp(0, 255);

    setPixelRgba(x, y, newR, newG, newB, newA);
  }
}

// ============================================================================
// RenderingBuffer24 - Rendering buffer with 24-bit (RGB) pixel access
// ============================================================================

/// Rendering buffer for 24-bit (3 bytes per pixel, RGB) access.
class RenderingBuffer24 extends RenderingBuffer {
  static const int bytesPerPixel = 3;

  RenderingBuffer24() : super();

  RenderingBuffer24.attach(Uint8List buf, int width, int height, int stride)
    : super.attach(buf, width, height, stride);

  factory RenderingBuffer24.create(int width, int height) {
    final stride = width * bytesPerPixel;
    final buf = Uint8List(height * stride);
    return RenderingBuffer24.attach(buf, width, height, stride);
  }

  /// Get pixel components
  ({int r, int g, int b}) getPixelRgb(int x, int y) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return (r: 0, g: 0, b: 0);
    }
    final offset = pixelOffset(x, y, bytesPerPixel);
    return (
      r: buf![offset],
      g: buf![offset + 1],
      b: buf![offset + 2],
    );
  }

  /// Set pixel components
  void setPixelRgb(int x, int y, int r, int g, int b) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }
    final offset = pixelOffset(x, y, bytesPerPixel);
    buf![offset] = r;
    buf![offset + 1] = g;
    buf![offset + 2] = b;
  }
}

// ============================================================================
// RenderingBuffer8 - Grayscale rendering buffer
// ============================================================================

/// Rendering buffer for 8-bit (1 byte per pixel, grayscale) access.
class RenderingBuffer8 extends RenderingBuffer {
  static const int bytesPerPixel = 1;

  RenderingBuffer8() : super();

  RenderingBuffer8.attach(Uint8List buf, int width, int height, int stride)
    : super.attach(buf, width, height, stride);

  factory RenderingBuffer8.create(int width, int height) {
    final stride = width * bytesPerPixel;
    final buf = Uint8List(height * stride);
    return RenderingBuffer8.attach(buf, width, height, stride);
  }

  /// Get pixel value
  int getPixelValue(int x, int y) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return 0;
    }
    return buf![pixelOffset(x, y, bytesPerPixel)];
  }

  /// Set pixel value
  void setPixelValue(int x, int y, int value) {
    if (buf == null || x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }
    buf![pixelOffset(x, y, bytesPerPixel)] = value;
  }
}
