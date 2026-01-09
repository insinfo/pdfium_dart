// Copyright 2016 The PDFium Authors
// Ported to Dart
//
// CFX_RenderDevice - Main rendering device class.

/// CFX_RenderDevice - Main rendering device class.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../fxcrt/fx_coordinates.dart';
import '../fpdfapi/font/pdf_font.dart';
import '../../agg/agg.dart';
import '../../freetype/freetype.dart' show FtOutline;
import 'fx_dib.dart';
import 'cfx_agg_devicedriver.dart';
import 'cfx_glyphcache.dart';
import 'cfx_glyphbitmap.dart';
import 'cfx_font.dart';

// ============================================================================
// Device Type
// ============================================================================

/// Type of render device.
enum DeviceType {
  /// Display device (screen).
  display,
  /// Printer device.
  printer,
}

// ============================================================================
// Blend Mode
// ============================================================================

/// Blend modes for compositing.
enum BlendMode {
  normal,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  hue,
  saturation,
  color,
  luminosity,
}

// ============================================================================
// Render Capabilities
// ============================================================================

/// Render device capabilities.
class RenderCaps {
  static const int getbits = 1 << 0;
  static const int setbits = 1 << 1;
  static const int alpha = 1 << 2;
  static const int pathStroke = 1 << 3;
  static const int pathFill = 1 << 4;
  static const int alphaPath = 1 << 5;
  static const int alphaImage = 1 << 6;
  static const int blendMode = 1 << 7;
}

// ============================================================================
// CFX_RenderDevice
// ============================================================================

/// Main rendering device class.
/// 
/// Provides rendering operations for paths, text, and images to a bitmap.
class CFX_RenderDevice {
  FxDIBitmap? _bitmap;
  CfxAggDeviceDriver? _driver;
  int _width = 0;
  int _height = 0;
  DeviceType _deviceType = DeviceType.display;
  int _renderCaps = RenderCaps.getbits | RenderCaps.setbits | 
                    RenderCaps.alpha | RenderCaps.pathStroke | 
                    RenderCaps.pathFill | RenderCaps.alphaPath;
  FxRectInt _clipBox = const FxRectInt(0, 0, 0, 0);
  final List<_SavedState> _stateStack = [];

  int get width => _width;
  int get height => _height;
  FxDIBitmap? get bitmap => _bitmap;
  DeviceType get deviceType => _deviceType;
  int get renderCaps => _renderCaps;
  FxRectInt get clipBox => _clipBox;

  /// Set the bitmap to render to.
  void setBitmap(FxDIBitmap bitmap, {bool rgbByteOrder = false}) {
    _bitmap = bitmap;
    _width = bitmap.width;
    _height = bitmap.height;
    _clipBox = FxRectInt(0, 0, _width, _height);
    _driver = CfxAggDeviceDriver(bitmap, rgbByteOrder: rgbByteOrder);
  }

  /// Save current state.
  void saveState() {
    _stateStack.add(_SavedState(
      clipBox: _clipBox,
    ));
    _driver?.saveState();
  }

  /// Restore state.
  void restoreState(bool keepSaved) {
    if (_stateStack.isEmpty) return;
    
    if (keepSaved) {
      final state = _stateStack.last;
      _clipBox = state.clipBox;
    } else {
      final state = _stateStack.removeLast();
      _clipBox = state.clipBox;
    }
    _driver?.restoreState(keepSaved);
  }

  /// Get the flip matrix for converting page to device coordinates.
  static FxMatrix getFlipMatrix(double width, double height, double left, double top) {
    return FxMatrix(width, 0, 0, -height, left, top + height);
  }

  /// Set clip to a rectangle.
  bool setClipRect(FxRectInt rect) {
    _clipBox = _clipBox.intersect(rect);
    return _driver?.setClipRect(rect) ?? true;
  }

  /// Set clip to a path fill.
  bool setClipPathFill(
    PathStorage path,
    FxMatrix? matrix,
    CfxFillRenderOptions fillOptions,
  ) {
    return _driver?.setClipPathFill(path, matrix, fillOptions) ?? false;
  }

  /// Fill a rectangle with color.
  bool fillRect(FxRect rect, int color) {
    if (_bitmap == null) return false;
    
    final rectInt = FxRectInt(
      rect.left.round(),
      rect.top.round(),
      rect.right.round(),
      rect.bottom.round(),
    );
    
    return _driver?.fillRect(rectInt, color) ?? false;
  }

  /// Fill a rectangle with integer coordinates.
  bool fillRectInt(FxRectInt rect, int color) {
    if (_bitmap == null) return false;
    return _driver?.fillRect(rect, color) ?? false;
  }

  /// Draw a path with fill and/or stroke.
  bool drawPath(
    PathStorage path,
    FxMatrix? matrix,
    CfxGraphStateData? graphState,
    int fillColor,
    int strokeColor,
    CfxFillRenderOptions fillOptions,
  ) {
    return _driver?.drawPath(path, matrix, graphState, fillColor, strokeColor, fillOptions) ?? false;
  }

  /// Clear the device with a color.
  void clear(int color) {
    _driver?.clear(color);
  }

  /// Draw normal (filled) text.
  bool drawNormalText(
    List<TextCharPos> charPosList,
    CfxFont font,
    double fontSize,
    FxMatrix textMatrix,
    int fillColor,
    CfxTextRenderOptions options,
  ) {
    if (_bitmap == null || charPosList.isEmpty) return false;
    
    final fxColor = FxColor(fillColor);
    if (fxColor.alpha == 0) return true;
    
    // Calculate matrix for text rendering
    // Font size affects the scale
    final scale = fontSize / (font.face?.unitsPerEM ?? 1000);
    
    for (final charPos in charPosList) {
      final glyphIndex = charPos.glyphIndex;
      
      // Calculate position in device space
      final pos = textMatrix.transformPoint(charPos.origin);
      
      // Create glyph matrix
      final glyphMatrix = FxMatrix(
        textMatrix.a * scale,
        textMatrix.b * scale,
        textMatrix.c * scale,
        textMatrix.d * scale,
        0, 0,
      );
      
      // Get glyph bitmap
      final glyphBitmap = font.loadGlyphBitmap(
        glyphIndex: glyphIndex,
        bFontStyle: true,
        matrix: glyphMatrix,
        destWidth: 0,
        antiAlias: options.aliasMode,
        textOptions: options,
      );
      
      if (glyphBitmap == null || glyphBitmap.isEmpty) {
        continue;
      }
      
      // Composite glyph to device
      _compositeGlyph(
        glyphBitmap,
        (pos.x + glyphBitmap.left).round(),
        (pos.y - glyphBitmap.top).round(),
        fxColor,
      );
    }
    
    return true;
  }

  /// Draw a single character (legacy method).
  void drawChar(PdfFont pdfFont, int charCode, FxMatrix matrix, int color) {
    if (_bitmap == null) return;
    
    // Create a minimal CfxFont wrapper
    final font = CfxFont();
    final flags = pdfFont.descriptor?.flags;
    font.loadSubst(
      faceName: pdfFont.name,
      weight: (flags?.forceBold ?? false) ? 700 : 400,
      italicAngle: (flags?.italic ?? false) ? 12 : 0,
    );
    
    // Get glyph index (simplified - use charCode as glyph index for now)
    final glyphIndex = charCode;
    
    final charPos = TextCharPos(
      unicode: charCode,
      glyphIndex: glyphIndex,
      font: font,
      origin: const FxPoint(0, 0),
    );
    
    final fontSize = matrix.getYUnit();
    
    drawNormalText(
      [charPos],
      font,
      fontSize,
      matrix,
      color,
      CfxTextRenderOptions.defaultOptions,
    );
  }

  /// Draw text using path outlines (for stroked text).
  bool drawTextPath(
    List<TextCharPos> charPosList,
    CfxFont font,
    double fontSize,
    FxMatrix textMatrix,
    FxMatrix? deviceMatrix,
    CfxGraphStateData? graphState,
    int fillColor,
    int strokeColor,
    PathStorage? clippingPath,
    CfxFillRenderOptions fillOptions,
  ) {
    if (charPosList.isEmpty) return true;
    
    final scale = fontSize / (font.face?.unitsPerEM ?? 1000);
    final path = PathStorage();
    
    for (final charPos in charPosList) {
      // Get glyph path
      final outline = font.loadGlyphPath(charPos.glyphIndex, 0);
      if (outline == null || outline.isEmpty) continue;
      
      // Calculate position
      final pos = textMatrix.transformPoint(charPos.origin);
      
      // Add outline to path with transformation
      _addOutlineToPath(path, outline, pos.x, pos.y, scale);
    }
    
    // Draw the combined path
    return drawPath(path, deviceMatrix, graphState, fillColor, strokeColor, fillOptions);
  }

  /// Set DIBits to device.
  bool setDIBits(FxDIBitmap sourceBitmap, int left, int top) {
    if (_bitmap == null) return false;
    
    // Clip to device bounds
    final srcRect = FxRectInt(0, 0, sourceBitmap.width, sourceBitmap.height);
    final dstRect = FxRectInt(left, top, left + sourceBitmap.width, top + sourceBitmap.height);
    final clippedDst = dstRect.intersect(_clipBox);
    
    if (clippedDst.isEmpty) return true;
    
    // Copy pixels
    final srcStartX = clippedDst.left - left;
    final srcStartY = clippedDst.top - top;
    
    for (int y = 0; y < clippedDst.height; y++) {
      for (int x = 0; x < clippedDst.width; x++) {
        final srcPixel = sourceBitmap.getPixel(srcStartX + x, srcStartY + y);
        final dstX = clippedDst.left + x;
        final dstY = clippedDst.top + y;
        
        if (srcPixel.alpha == 255) {
          _bitmap!.setPixel(dstX, dstY, srcPixel);
        } else if (srcPixel.alpha > 0) {
          _blendPixel(dstX, dstY, srcPixel);
        }
      }
    }
    
    return true;
  }

  /// Stretch DIBits to device.
  bool stretchDIBits(
    FxDIBitmap sourceBitmap,
    int left,
    int top,
    int destWidth,
    int destHeight,
  ) {
    if (_bitmap == null || destWidth == 0 || destHeight == 0) return false;
    
    // Simple nearest-neighbor scaling
    final scaleX = sourceBitmap.width / destWidth.abs();
    final scaleY = sourceBitmap.height / destHeight.abs();
    
    final dstRect = FxRectInt(
      left,
      top,
      left + destWidth.abs(),
      top + destHeight.abs(),
    );
    final clippedDst = dstRect.intersect(_clipBox);
    
    if (clippedDst.isEmpty) return true;
    
    for (int dstY = clippedDst.top; dstY < clippedDst.bottom; dstY++) {
      for (int dstX = clippedDst.left; dstX < clippedDst.right; dstX++) {
        final srcX = ((dstX - left) * scaleX).floor().clamp(0, sourceBitmap.width - 1);
        final srcY = ((dstY - top) * scaleY).floor().clamp(0, sourceBitmap.height - 1);
        
        final srcPixel = sourceBitmap.getPixel(srcX, srcY);
        
        if (srcPixel.alpha == 255) {
          _bitmap!.setPixel(dstX, dstY, srcPixel);
        } else if (srcPixel.alpha > 0) {
          _blendPixel(dstX, dstY, srcPixel);
        }
      }
    }
    
    return true;
  }

  // Internal methods

  void _compositeGlyph(CfxGlyphBitmap glyph, int x, int y, FxColor color) {
    final clipBox = _clipBox;
    
    for (int gy = 0; gy < glyph.rows; gy++) {
      final dstY = y + gy;
      if (dstY < clipBox.top || dstY >= clipBox.bottom) continue;
      
      for (int gx = 0; gx < glyph.width; gx++) {
        final dstX = x + gx;
        if (dstX < clipBox.left || dstX >= clipBox.right) continue;
        
        final coverage = glyph.buffer[gy * glyph.pitch + gx];
        if (coverage == 0) continue;
        
        final srcAlpha = (color.alpha * coverage) ~/ 255;
        if (srcAlpha == 0) continue;
        
        _blendPixelWithAlpha(dstX, dstY, color, srcAlpha);
      }
    }
  }

  void _blendPixel(int x, int y, FxColor src) {
    if (_bitmap == null) return;
    
    final dst = _bitmap!.getPixel(x, y);
    
    if (src.alpha == 255) {
      _bitmap!.setPixel(x, y, src);
      return;
    }
    
    final outAlpha = src.alpha + dst.alpha - (src.alpha * dst.alpha) ~/ 255;
    if (outAlpha == 0) return;
    
    final alphaRatio = (src.alpha * 255) ~/ outAlpha;
    
    _bitmap!.setPixel(x, y, FxColor.fromARGB(
      outAlpha,
      _alphaMerge(dst.red, src.red, alphaRatio),
      _alphaMerge(dst.green, src.green, alphaRatio),
      _alphaMerge(dst.blue, src.blue, alphaRatio),
    ));
  }

  void _blendPixelWithAlpha(int x, int y, FxColor src, int srcAlpha) {
    if (_bitmap == null) return;
    
    final dst = _bitmap!.getPixel(x, y);
    
    if (srcAlpha == 255) {
      _bitmap!.setPixel(x, y, src);
      return;
    }
    
    final outAlpha = srcAlpha + dst.alpha - (srcAlpha * dst.alpha) ~/ 255;
    if (outAlpha == 0) return;
    
    final alphaRatio = (srcAlpha * 255) ~/ outAlpha;
    
    _bitmap!.setPixel(x, y, FxColor.fromARGB(
      outAlpha,
      _alphaMerge(dst.red, src.red, alphaRatio),
      _alphaMerge(dst.green, src.green, alphaRatio),
      _alphaMerge(dst.blue, src.blue, alphaRatio),
    ));
  }

  int _alphaMerge(int backdrop, int src, int alpha) {
    return backdrop + ((src - backdrop) * alpha) ~/ 255;
  }

  void _addOutlineToPath(PathStorage path, dynamic outline, double x, double y, double scale) {
    // Add outline points to path with transformation
    if (outline is! FtOutline) return;
    
    final ft = outline as FtOutline;
    if (ft.nContours == 0) return;
    
    int first = 0;
    for (int c = 0; c < ft.nContours; c++) {
      final last = ft.contours[c];
      
      if (last >= first) {
        // Move to first point
        final p0 = ft.points[first];
        path.moveTo(
          x + p0.x * scale / 64.0,
          y - p0.y * scale / 64.0,
        );
        
        // Line to remaining points
        for (int i = first + 1; i <= last; i++) {
          final p = ft.points[i];
          path.lineTo(
            x + p.x * scale / 64.0,
            y - p.y * scale / 64.0,
          );
        }
        
        path.closePolygon();
      }
      
      first = last + 1;
    }
  }
}

/// Internal saved state.
class _SavedState {
  final FxRectInt clipBox;
  
  _SavedState({required this.clipBox});
}
