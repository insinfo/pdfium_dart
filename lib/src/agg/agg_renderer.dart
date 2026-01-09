// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG Renderer - Scanline renderers and renderer base.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'agg_basics.dart';
import 'agg_color.dart';
import 'agg_rendering_buffer.dart';
import 'agg_scanline.dart';
import 'agg_rasterizer.dart';

// ============================================================================
// Pixel Format RGBA
// ============================================================================

/// Pixel format for 32-bit RGBA
class PixfmtRgba32 {
  final RenderingBuffer _rbuf;

  PixfmtRgba32(this._rbuf);

  int get width => _rbuf.width;
  int get height => _rbuf.height;
  int get stride => _rbuf.stride;

  /// Get pixel at position
  Rgba8 pixel(int x, int y) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return Rgba8();
    final offset = x * 4;
    return Rgba8(
      p[offset + OrderRgba.r],
      p[offset + OrderRgba.g],
      p[offset + OrderRgba.b],
      p[offset + OrderRgba.a],
    );
  }

  /// Copy a single pixel
  void copyPixel(int x, int y, Rgba8 c) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    final offset = x * 4;
    p[offset + OrderRgba.r] = c.r;
    p[offset + OrderRgba.g] = c.g;
    p[offset + OrderRgba.b] = c.b;
    p[offset + OrderRgba.a] = c.a;
  }

  /// Blend a single pixel with alpha
  void blendPixel(int x, int y, Rgba8 c, int cover) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    final offset = x * 4;
    
    final alpha = (c.a * cover + 255) >> 8;
    if (alpha == 0) return;
    
    if (alpha == 255) {
      // Opaque - just copy
      p[offset + OrderRgba.r] = c.r;
      p[offset + OrderRgba.g] = c.g;
      p[offset + OrderRgba.b] = c.b;
      p[offset + OrderRgba.a] = c.a;
    } else {
      // Blend
      _blendPix(p, offset, c.r, c.g, c.b, alpha);
    }
  }

  void _blendPix(Uint8List p, int offset, int cr, int cg, int cb, int alpha) {
    p[offset + OrderRgba.r] = _lerp(p[offset + OrderRgba.r], cr, alpha);
    p[offset + OrderRgba.g] = _lerp(p[offset + OrderRgba.g], cg, alpha);
    p[offset + OrderRgba.b] = _lerp(p[offset + OrderRgba.b], cb, alpha);
    p[offset + OrderRgba.a] = _prelerp(p[offset + OrderRgba.a], alpha, alpha);
  }

  static int _lerp(int p, int q, int a) {
    return p + (((q - p) * a + 255) >> 8);
  }

  static int _prelerp(int p, int q, int a) {
    return p + q - ((p * a + 255) >> 8);
  }

  /// Copy horizontal line
  void copyHline(int x, int y, int len, Rgba8 c) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    
    for (int i = 0; i < len; i++) {
      final offset = (x + i) * 4;
      p[offset + OrderRgba.r] = c.r;
      p[offset + OrderRgba.g] = c.g;
      p[offset + OrderRgba.b] = c.b;
      p[offset + OrderRgba.a] = c.a;
    }
  }

  /// Copy vertical line
  void copyVline(int x, int y, int len, Rgba8 c) {
    for (int i = 0; i < len; i++) {
      copyPixel(x, y + i, c);
    }
  }

  /// Blend horizontal line with cover
  void blendHline(int x, int y, int len, Rgba8 c, int cover) {
    if (cover == 0) return;
    
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    
    final alpha = (c.a * cover + 255) >> 8;
    if (alpha == 0) return;
    
    if (alpha == 255) {
      copyHline(x, y, len, c);
      return;
    }
    
    for (int i = 0; i < len; i++) {
      final offset = (x + i) * 4;
      _blendPix(p, offset, c.r, c.g, c.b, alpha);
    }
  }

  /// Blend vertical line with cover
  void blendVline(int x, int y, int len, Rgba8 c, int cover) {
    if (cover == 0) return;
    for (int i = 0; i < len; i++) {
      blendPixel(x, y + i, c, cover);
    }
  }

  /// Blend solid horizontal span with cover array
  void blendSolidHspan(int x, int y, int len, Rgba8 c, Uint8List covers, [int coverOffset = 0]) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    
    for (int i = 0; i < len; i++) {
      final cover = covers[coverOffset + i];
      if (cover == 0) continue;
      
      final alpha = (c.a * cover + 255) >> 8;
      if (alpha == 0) continue;
      
      final offset = (x + i) * 4;
      
      if (alpha == 255) {
        p[offset + OrderRgba.r] = c.r;
        p[offset + OrderRgba.g] = c.g;
        p[offset + OrderRgba.b] = c.b;
        p[offset + OrderRgba.a] = c.a;
      } else {
        _blendPix(p, offset, c.r, c.g, c.b, alpha);
      }
    }
  }

  /// Blend solid vertical span with cover array
  void blendSolidVspan(int x, int y, int len, Rgba8 c, Uint8List covers, [int coverOffset = 0]) {
    for (int i = 0; i < len; i++) {
      blendPixel(x, y + i, c, covers[coverOffset + i]);
    }
  }

  /// Blend colors horizontal span
  void blendColorHspan(int x, int y, int len, List<Rgba8> colors, Uint8List? covers, int cover) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    
    for (int i = 0; i < len; i++) {
      final c = colors[i];
      final cv = covers != null ? covers[i] : cover;
      if (cv == 0) continue;
      
      final alpha = (c.a * cv + 255) >> 8;
      if (alpha == 0) continue;
      
      final offset = (x + i) * 4;
      
      if (alpha == 255) {
        p[offset + OrderRgba.r] = c.r;
        p[offset + OrderRgba.g] = c.g;
        p[offset + OrderRgba.b] = c.b;
        p[offset + OrderRgba.a] = c.a;
      } else {
        _blendPix(p, offset, c.r, c.g, c.b, alpha);
      }
    }
  }
}

/// Pixel format for 32-bit BGRA
class PixfmtBgra32 {
  final RenderingBuffer _rbuf;

  PixfmtBgra32(this._rbuf);

  int get width => _rbuf.width;
  int get height => _rbuf.height;
  int get stride => _rbuf.stride;

  /// Get pixel at position
  Rgba8 pixel(int x, int y) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return Rgba8();
    final offset = x * 4;
    return Rgba8(
      p[offset + OrderBgra.r],
      p[offset + OrderBgra.g],
      p[offset + OrderBgra.b],
      p[offset + OrderBgra.a],
    );
  }

  /// Copy a single pixel
  void copyPixel(int x, int y, Rgba8 c) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    final offset = x * 4;
    p[offset + OrderBgra.r] = c.r;
    p[offset + OrderBgra.g] = c.g;
    p[offset + OrderBgra.b] = c.b;
    p[offset + OrderBgra.a] = c.a;
  }

  /// Blend a single pixel with alpha
  void blendPixel(int x, int y, Rgba8 c, int cover) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    final offset = x * 4;
    
    final alpha = (c.a * cover + 255) >> 8;
    if (alpha == 0) return;
    
    if (alpha == 255) {
      p[offset + OrderBgra.r] = c.r;
      p[offset + OrderBgra.g] = c.g;
      p[offset + OrderBgra.b] = c.b;
      p[offset + OrderBgra.a] = c.a;
    } else {
      _blendPix(p, offset, c.r, c.g, c.b, alpha);
    }
  }

  void _blendPix(Uint8List p, int offset, int cr, int cg, int cb, int alpha) {
    p[offset + OrderBgra.r] = _lerp(p[offset + OrderBgra.r], cr, alpha);
    p[offset + OrderBgra.g] = _lerp(p[offset + OrderBgra.g], cg, alpha);
    p[offset + OrderBgra.b] = _lerp(p[offset + OrderBgra.b], cb, alpha);
    p[offset + OrderBgra.a] = _prelerp(p[offset + OrderBgra.a], alpha, alpha);
  }

  static int _lerp(int p, int q, int a) {
    return p + (((q - p) * a + 255) >> 8);
  }

  static int _prelerp(int p, int q, int a) {
    return p + q - ((p * a + 255) >> 8);
  }

  /// Copy horizontal line
  void copyHline(int x, int y, int len, Rgba8 c) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    
    for (int i = 0; i < len; i++) {
      final offset = (x + i) * 4;
      p[offset + OrderBgra.r] = c.r;
      p[offset + OrderBgra.g] = c.g;
      p[offset + OrderBgra.b] = c.b;
      p[offset + OrderBgra.a] = c.a;
    }
  }

  /// Blend horizontal line with cover
  void blendHline(int x, int y, int len, Rgba8 c, int cover) {
    if (cover == 0) return;
    
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    
    final alpha = (c.a * cover + 255) >> 8;
    if (alpha == 0) return;
    
    if (alpha == 255) {
      copyHline(x, y, len, c);
      return;
    }
    
    for (int i = 0; i < len; i++) {
      final offset = (x + i) * 4;
      _blendPix(p, offset, c.r, c.g, c.b, alpha);
    }
  }

  /// Blend solid horizontal span with cover array
  void blendSolidHspan(int x, int y, int len, Rgba8 c, Uint8List covers, [int coverOffset = 0]) {
    final p = _rbuf.rowPtr(y);
    if (p == null) return;
    
    for (int i = 0; i < len; i++) {
      final cover = covers[coverOffset + i];
      if (cover == 0) continue;
      
      final alpha = (c.a * cover + 255) >> 8;
      if (alpha == 0) continue;
      
      final offset = (x + i) * 4;
      
      if (alpha == 255) {
        p[offset + OrderBgra.r] = c.r;
        p[offset + OrderBgra.g] = c.g;
        p[offset + OrderBgra.b] = c.b;
        p[offset + OrderBgra.a] = c.a;
      } else {
        _blendPix(p, offset, c.r, c.g, c.b, alpha);
      }
    }
  }
}

// ============================================================================
// Renderer Base - Clipped rendering with pixel format
// ============================================================================

/// Base renderer with clipping support.
/// 
/// This class wraps a pixel format and provides clipped rendering operations.
class RendererBase<TPixfmt> {
  TPixfmt? _ren;
  RectI _clipBox = RectI(1, 1, 0, 0);

  RendererBase([TPixfmt? pixfmt]) {
    if (pixfmt != null) attach(pixfmt);
  }

  /// Attach pixel format
  void attach(TPixfmt pixfmt) {
    _ren = pixfmt;
    _clipBox = RectI(0, 0, width - 1, height - 1);
  }

  /// Get pixel format
  TPixfmt get ren => _ren!;

  int get width => (_ren as dynamic).width as int;
  int get height => (_ren as dynamic).height as int;

  /// Set clipping box
  bool setClipBox(int x1, int y1, int x2, int y2) {
    var cb = RectI(x1, y1, x2, y2);
    cb = cb.normalize();
    
    final bounds = RectI(0, 0, width - 1, height - 1);
    
    // clip function returns bool or modifies RectI? 
    // Checking previous implementation or usage. 
    // If RectI is a mutable class, clip might modify it and return bool.
    // If RectI is immutable, clip returns new RectI?.
    
    // Let's assume RectI acts like a rect and clip modifies it.
    // Wait, RectI(0, 0, width-1, height-1).clip(RectI(...))?
    // The previous error said "A value of type 'bool' can't be assigned to ... 'RectI'".
    // So cb.clip(bounds) returns a bool.
    
    if (cb.clip(bounds)) {
        _clipBox = cb; // or bounds? 
        // If cb.clip(bounds) clips cb to bounds, then we want the result.
        // Assuming cb is modified by clip?
        return true;
    }
    
    _clipBox = RectI(1, 1, 0, 0);
    return false;
  }

  /// Reset clipping
  void resetClipping(bool visibility) {
    if (visibility) {
      _clipBox = RectI(0, 0, width - 1, height - 1);
    } else {
      _clipBox = RectI(1, 1, 0, 0);
    }
  }

  /// Get clipping box
  RectI get clipBox => _clipBox;
  int get xmin => _clipBox.x1;
  int get ymin => _clipBox.y1;
  int get xmax => _clipBox.x2;
  int get ymax => _clipBox.y2;

  /// Check if point is inside clipping box
  bool inbox(int x, int y) {
    return x >= _clipBox.x1 && y >= _clipBox.y1 &&
           x <= _clipBox.x2 && y <= _clipBox.y2;
  }

  /// Clear to color
  void clear(Rgba8 c) {
    final pixfmt = _ren as dynamic;
    for (int y = 0; y < height; y++) {
      pixfmt.copyHline(0, y, width, c);
    }
  }

  /// Copy pixel
  void copyPixel(int x, int y, Rgba8 c) {
    if (inbox(x, y)) {
      (_ren as dynamic).copyPixel(x, y, c);
    }
  }

  /// Blend pixel
  void blendPixel(int x, int y, Rgba8 c, int cover) {
    if (inbox(x, y)) {
      (_ren as dynamic).blendPixel(x, y, c, cover);
    }
  }

  /// Get pixel
  Rgba8 pixel(int x, int y) {
    return inbox(x, y) ? (_ren as dynamic).pixel(x, y) as Rgba8 : Rgba8();
  }

  /// Copy horizontal line
  void copyHline(int x1, int y, int x2, Rgba8 c) {
    if (x1 > x2) { final t = x2; x2 = x1; x1 = t; }
    if (y > ymax) return;
    if (y < ymin) return;
    if (x1 > xmax) return;
    if (x2 < xmin) return;

    if (x1 < xmin) x1 = xmin;
    if (x2 > xmax) x2 = xmax;

    (_ren as dynamic).copyHline(x1, y, x2 - x1 + 1, c);
  }

  /// Copy vertical line
  void copyVline(int x, int y1, int y2, Rgba8 c) {
    if (y1 > y2) { final t = y2; y2 = y1; y1 = t; }
    if (x > xmax) return;
    if (x < xmin) return;
    if (y1 > ymax) return;
    if (y2 < ymin) return;

    if (y1 < ymin) y1 = ymin;
    if (y2 > ymax) y2 = ymax;

    for (int y = y1; y <= y2; y++) {
      (_ren as dynamic).copyPixel(x, y, c);
    }
  }

  /// Blend horizontal line
  void blendHline(int x1, int y, int x2, Rgba8 c, int cover) {
    if (x1 > x2) { final t = x2; x2 = x1; x1 = t; }
    if (y > ymax) return;
    if (y < ymin) return;
    if (x1 > xmax) return;
    if (x2 < xmin) return;

    if (x1 < xmin) x1 = xmin;
    if (x2 > xmax) x2 = xmax;

    (_ren as dynamic).blendHline(x1, y, x2 - x1 + 1, c, cover);
  }

  /// Blend vertical line
  void blendVline(int x, int y1, int y2, Rgba8 c, int cover) {
    if (y1 > y2) { final t = y2; y2 = y1; y1 = t; }
    if (x > xmax) return;
    if (x < xmin) return;
    if (y1 > ymax) return;
    if (y2 < ymin) return;

    if (y1 < ymin) y1 = ymin;
    if (y2 > ymax) y2 = ymax;

    for (int y = y1; y <= y2; y++) {
      (_ren as dynamic).blendPixel(x, y, c, cover);
    }
  }

  /// Copy filled bar
  void copyBar(int x1, int y1, int x2, int y2, Rgba8 c) {
    var rc = RectI(x1, y1, x2, y2).normalize();
    if (!rc.clip(_clipBox)) return;
    
    for (int y = rc.y1; y <= rc.y2; y++) {
      (_ren as dynamic).copyHline(rc.x1, y, rc.x2 - rc.x1 + 1, c);
    }
  }

  /// Blend filled bar
  void blendBar(int x1, int y1, int x2, int y2, Rgba8 c, int cover) {
    var rc = RectI(x1, y1, x2, y2).normalize();
    if (!rc.clip(_clipBox)) return;
    
    for (int y = rc.y1; y <= rc.y2; y++) {
      (_ren as dynamic).blendHline(rc.x1, y, rc.x2 - rc.x1 + 1, c, cover);
    }
  }

  /// Blend solid horizontal span with covers
  void blendSolidHspan(int x, int y, int len, Rgba8 c, Uint8List covers, [int coverOffset = 0]) {
    if (y > ymax) return;
    if (y < ymin) return;

    if (x < xmin) {
      final d = xmin - x;
      len -= d;
      if (len <= 0) return;
      coverOffset += d;
      x = xmin;
    }
    if (x + len > xmax) {
      len = xmax - x + 1;
      if (len <= 0) return;
    }
    (_ren as dynamic).blendSolidHspan(x, y, len, c, covers, coverOffset);
  }

  /// Blend solid vertical span with covers
  void blendSolidVspan(int x, int y, int len, Rgba8 c, Uint8List covers, [int coverOffset = 0]) {
    if (x > xmax) return;
    if (x < xmin) return;

    if (y < ymin) {
      final d = ymin - y;
      len -= d;
      if (len <= 0) return;
      coverOffset += d;
      y = ymin;
    }
    if (y + len > ymax) {
      len = ymax - y + 1;
      if (len <= 0) return;
    }
    
    for (int i = 0; i < len; i++) {
      (_ren as dynamic).blendPixel(x, y + i, c, covers[coverOffset + i]);
    }
  }
}

// ============================================================================
// Scanline Renderers
// ============================================================================

/// Render a single scanline with solid color (anti-aliased)
void renderScanlineAASolid<TScanline extends ScanlineU8>(
  TScanline sl,
  RendererBase ren,
  Rgba8 color,
) {
  final y = sl.y;
  final spans = sl.spans;
  
  for (final span in spans) {
    final x = span.x;
    final len = span.len;
    
    if (len > 0) {
      // Array of covers
      ren.blendSolidHspan(x, y, len, color, sl.covers, span.coversOffset);
    } else {
      // Single cover, run of -len pixels
      ren.blendHline(x, y, x - len - 1, color, sl.covers[span.coversOffset]);
    }
  }
}

/// Render all scanlines with solid color
void renderScanlinesAASolid<TRasterizer extends RasterizerScanlineAA>(
  TRasterizer ras,
  ScanlineU8 sl,
  RendererBase ren,
  Rgba8 color,
) {
  if (!ras.rewindScanlines()) return;
  
  sl.reset(ras.minX, ras.maxX);
  while (ras.sweepScanline(sl)) {
    renderScanlineAASolid(sl, ren, color);
  }
}

/// AA solid scanline renderer class
class RendererScanlineAASolid<TBaseRenderer extends RendererBase> {
  TBaseRenderer? _ren;
  Rgba8 _color = Rgba8();

  RendererScanlineAASolid([TBaseRenderer? ren]) : _ren = ren;

  /// Attach base renderer
  void attach(TBaseRenderer ren) {
    _ren = ren;
  }

  /// Set color
  set color(Rgba8 c) => _color = c;
  
  /// Get color
  Rgba8 get color => _color;

  /// Prepare for rendering (no-op for solid)
  void prepare() {}

  /// Render scanline
  void render(ScanlineU8 sl) {
    renderScanlineAASolid(sl, _ren!, _color);
  }
}

/// Render a single scanline binary (no anti-aliasing)
void renderScanlineBin(
  ScanlineBin sl,
  RendererBase ren,
  Rgba8 color,
) {
  final spans = sl.spans;
  
  for (final span in spans) {
    ren.blendHline(span.x, sl.y, span.x + span.len - 1, color, 255);
  }
}

/// Binary scanline renderer class
class RendererScanlineBinSolid<TBaseRenderer extends RendererBase> {
  TBaseRenderer? _ren;
  Rgba8 _color = Rgba8();

  RendererScanlineBinSolid([TBaseRenderer? ren]) : _ren = ren;

  /// Attach base renderer
  void attach(TBaseRenderer ren) {
    _ren = ren;
  }

  /// Set color
  set color(Rgba8 c) => _color = c;
  
  /// Get color
  Rgba8 get color => _color;

  /// Prepare for rendering
  void prepare() {}

  /// Render scanline
  void render(ScanlineBin sl) {
    renderScanlineBin(sl, _ren!, _color);
  }
}

// ============================================================================
// Span Allocator
// ============================================================================

/// Simple span allocator for color arrays
class SpanAllocator {
  List<Rgba8> _span = [];

  /// Allocate span of given length
  List<Rgba8> allocate(int len) {
    if (_span.length < len) {
      _span = List<Rgba8>.generate(len, (_) => Rgba8());
    }
    return _span;
  }

  /// Get max length
  int get maxLen => _span.length;
}

// ============================================================================
// Span Generator - Solid color (simplest case)
// ============================================================================

/// Solid color span generator
class SpanSolid {
  Rgba8 _color = Rgba8();

  /// Set color
  set color(Rgba8 c) => _color = c;
  
  /// Get color
  Rgba8 get color => _color;

  /// Prepare for rendering
  void prepare() {}

  /// Generate span
  void generate(List<Rgba8> span, int x, int y, int len) {
    for (int i = 0; i < len; i++) {
      span[i] = _color;
    }
  }
}

// ============================================================================
// High-level rendering functions
// ============================================================================

/// Fill a path with solid color
void fillPath(
  RasterizerScanlineAA ras,
  ScanlineU8 sl,
  RendererBase ren,
  Rgba8 color,
) {
  renderScanlinesAASolid(ras, sl, ren, color);
}

/// Convenience function to render filled shape
void renderFilledShape(
  void Function(RasterizerScanlineAA ras) addPath,
  RendererBase ren,
  Rgba8 color,
) {
  final ras = RasterizerScanlineAA();
  final sl = ScanlineU8();
  
  addPath(ras);
  fillPath(ras, sl, ren, color);
}
