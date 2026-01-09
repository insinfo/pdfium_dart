// Copyright 2014 The PDFium Authors
// Ported to Dart
//
// AGG-based device driver for rendering.

/// AGG-based device driver for rendering.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../fxcrt/fx_coordinates.dart';
import '../fxcrt/fx_types.dart';
import '../../agg/agg.dart';
import 'fx_dib.dart';
import 'cfx_glyphcache.dart';
import 'cfx_glyphbitmap.dart';

// ============================================================================
// Clip Region
// ============================================================================

/// Type of clip region.
enum ClipRegionType {
  /// Rectangular clip.
  rect,
  /// Mask-based clip.
  mask,
}

/// Clip region for AGG rendering.
class CfxAggClipRgn {
  ClipRegionType _type;
  FxRectInt _box;
  FxDIBitmap? _mask;

  CfxAggClipRgn(int width, int height)
      : _type = ClipRegionType.rect,
        _box = FxRectInt(0, 0, width, height);

  CfxAggClipRgn.copy(CfxAggClipRgn other)
      : _type = other._type,
        _box = FxRectInt(other._box.left, other._box.top, 
                         other._box.right, other._box.bottom),
        _mask = other._mask;

  ClipRegionType get type => _type;
  FxRectInt get box => _box;
  FxDIBitmap? get mask => _mask;

  /// Intersect with a rectangle.
  void intersectRect(FxRectInt rect) {
    if (_type == ClipRegionType.mask && _mask != null) {
      _intersectMaskRect(rect);
      return;
    }
    _type = ClipRegionType.rect;
    _box = _box.intersect(rect);
  }

  /// Intersect with a mask.
  void intersectMask(FxDIBitmap mask, int left, int top) {
    if (_type == ClipRegionType.rect) {
      _initMaskFromRect(mask, left, top);
      return;
    }
    _intersectMaskMask(mask, left, top);
  }

  void _intersectMaskRect(FxRectInt rect) {
    final newBox = _box.intersect(rect);
    if (newBox.isEmpty) {
      _type = ClipRegionType.rect;
      _box = newBox;
      _mask = null;
      return;
    }
    _box = newBox;
  }

  void _initMaskFromRect(FxDIBitmap mask, int left, int top) {
    final maskRect = FxRectInt(left, top, 
                                left + mask.width, top + mask.height);
    final newBox = _box.intersect(maskRect);
    if (newBox.isEmpty) {
      return;
    }
    
    _type = ClipRegionType.mask;
    _box = newBox;
    
    // Create new mask cropped to clip box
    final newMask = FxDIBitmap(newBox.width, newBox.height, BitmapFormat.gray);
    
    for (int y = 0; y < newBox.height; y++) {
      for (int x = 0; x < newBox.width; x++) {
        final srcX = newBox.left - left + x;
        final srcY = newBox.top - top + y;
        if (srcX >= 0 && srcX < mask.width && srcY >= 0 && srcY < mask.height) {
          final alpha = mask.getPixelGray(srcX, srcY);
          newMask.setPixelGray(x, y, alpha);
        }
      }
    }
    
    _mask = newMask;
  }

  void _intersectMaskMask(FxDIBitmap mask, int left, int top) {
    if (_mask == null) return;
    
    final maskRect = FxRectInt(left, top,
                                left + mask.width, top + mask.height);
    final newBox = _box.intersect(maskRect);
    if (newBox.isEmpty) {
      _type = ClipRegionType.rect;
      _box = newBox;
      _mask = null;
      return;
    }
    
    // Intersect masks
    final newMask = FxDIBitmap(newBox.width, newBox.height, BitmapFormat.gray);
    
    for (int y = 0; y < newBox.height; y++) {
      for (int x = 0; x < newBox.width; x++) {
        final oldX = newBox.left - _box.left + x;
        final oldY = newBox.top - _box.top + y;
        final srcX = newBox.left - left + x;
        final srcY = newBox.top - top + y;
        
        int oldAlpha = 255;
        if (oldX >= 0 && oldX < _mask!.width && 
            oldY >= 0 && oldY < _mask!.height) {
          oldAlpha = _mask!.getPixelGray(oldX, oldY);
        }
        
        int newAlpha = 255;
        if (srcX >= 0 && srcX < mask.width && srcY >= 0 && srcY < mask.height) {
          newAlpha = mask.getPixelGray(srcX, srcY);
        }
        
        newMask.setPixelGray(x, y, (oldAlpha * newAlpha) ~/ 255);
      }
    }
    
    _box = newBox;
    _mask = newMask;
  }
}

// ============================================================================
// Fill Render Options
// ============================================================================

/// Fill type for path rendering.
enum FillType {
  /// No fill.
  none,
  /// Even-odd fill rule.
  evenOdd,
  /// Non-zero winding fill rule.
  winding,
}

/// Options for fill rendering.
class CfxFillRenderOptions {
  FillType fillType;
  bool fullCover;
  bool rectAA;
  bool textMode;
  bool noPathSmooth;

  CfxFillRenderOptions({
    this.fillType = FillType.winding,
    this.fullCover = false,
    this.rectAA = true,
    this.textMode = false,
    this.noPathSmooth = false,
  });
}

// ============================================================================
// Graph State Data
// ============================================================================

/// Line cap styles.
enum LineCap { butt, round, square }

/// Line join styles.
enum LineJoin { miter, round, bevel }

/// Graphics state data.
class CfxGraphStateData {
  LineCap lineCap;
  LineJoin lineJoin;
  double lineWidth;
  double miterLimit;
  List<double> dashArray;
  double dashPhase;

  CfxGraphStateData({
    this.lineCap = LineCap.butt,
    this.lineJoin = LineJoin.miter,
    this.lineWidth = 1.0,
    this.miterLimit = 10.0,
    List<double>? dashArray,
    this.dashPhase = 0.0,
  }) : dashArray = dashArray ?? [];
}

// ============================================================================
// AGG Device Driver
// ============================================================================

/// AGG-based device driver for rendering paths, images, and text.
class CfxAggDeviceDriver {
  final FxDIBitmap _bitmap;
  final bool _rgbByteOrder;
  final bool _groupKnockout;
  final FxDIBitmap? _backdropBitmap;
  
  CfxAggClipRgn? _clipRgn;
  final List<CfxAggClipRgn?> _stateStack = [];
  CfxFillRenderOptions _fillOptions = CfxFillRenderOptions();

  CfxAggDeviceDriver(
    this._bitmap, {
    bool rgbByteOrder = false,
    FxDIBitmap? backdropBitmap,
    bool groupKnockout = false,
  })  : _rgbByteOrder = rgbByteOrder,
        _backdropBitmap = backdropBitmap,
        _groupKnockout = groupKnockout {
    _clipRgn = CfxAggClipRgn(_bitmap.width, _bitmap.height);
  }

  int get width => _bitmap.width;
  int get height => _bitmap.height;
  FxDIBitmap get bitmap => _bitmap;

  /// Save current state.
  void saveState() {
    _stateStack.add(_clipRgn != null ? CfxAggClipRgn.copy(_clipRgn!) : null);
  }

  /// Restore state.
  void restoreState(bool keepSaved) {
    if (_stateStack.isEmpty) return;
    
    if (keepSaved) {
      _clipRgn = _stateStack.last != null 
          ? CfxAggClipRgn.copy(_stateStack.last!) 
          : null;
    } else {
      _clipRgn = _stateStack.removeLast();
    }
  }

  /// Get clip box.
  FxRectInt getClipBox() {
    if (_clipRgn != null) {
      return _clipRgn!.box;
    }
    return FxRectInt(0, 0, _bitmap.width, _bitmap.height);
  }

  /// Set clip to a rectangle.
  bool setClipRect(FxRectInt rect) {
    _clipRgn ??= CfxAggClipRgn(_bitmap.width, _bitmap.height);
    _clipRgn!.intersectRect(rect);
    return true;
  }

  /// Set clip to a path fill.
  bool setClipPathFill(
    PathStorage path,
    FxMatrix? matrix,
    CfxFillRenderOptions fillOptions,
  ) {
    // Rasterize path to mask
    final rasterizer = RasterizerScanlineAA();
    
    // Add path to rasterizer
    _addPathToRasterizer(rasterizer, path, matrix, fillOptions);
    
    // Create mask from rasterizer
    final clipBox = getClipBox();
    final mask = FxDIBitmap(clipBox.width, clipBox.height, BitmapFormat.gray);
    
    _renderRasterizerToMask(rasterizer, mask, clipBox.left, clipBox.top);
    
    _clipRgn ??= CfxAggClipRgn(_bitmap.width, _bitmap.height);
    _clipRgn!.intersectMask(mask, clipBox.left, clipBox.top);
    
    return true;
  }

  /// Fill a rectangle.
  bool fillRect(FxRectInt rect, int color) {
    final clipBox = getClipBox();
    final fillRect = rect.intersect(clipBox);
    if (fillRect.isEmpty) return true;

    final fxColor = FxColor(color);
    
    if (_clipRgn != null && _clipRgn!.type == ClipRegionType.mask) {
      // Use mask for clipping
      _fillRectWithMask(fillRect, fxColor, _clipRgn!.mask!, _clipRgn!.box);
    } else {
      // Simple rect fill
      _bitmap.fillRect(fillRect, fxColor);
    }
    
    return true;
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
    final rasterizer = RasterizerScanlineAA();
    
    // Fill path
    if (fillOptions.fillType != FillType.none && FxColor(fillColor).alpha > 0) {
      _addPathToRasterizer(rasterizer, path, matrix, fillOptions);
      _renderRasterizer(rasterizer, fillColor, fillOptions.fullCover);
      rasterizer.reset();
    }
    
    // Stroke path
    if (graphState != null && graphState.lineWidth > 0 && 
        FxColor(strokeColor).alpha > 0) {
      _strokePath(rasterizer, path, matrix, graphState);
      _renderRasterizer(rasterizer, strokeColor, fillOptions.fullCover);
    }
    
    return true;
  }

  /// Clear bitmap with color.
  void clear(int color) {
    _bitmap.clear(FxColor(color));
  }

  void _addPathToRasterizer(
    RasterizerScanlineAA rasterizer,
    PathStorage path,
    FxMatrix? matrix,
    CfxFillRenderOptions fillOptions,
  ) {
    // Set fill rule
    rasterizer.setFillingRule(fillOptions.fillType == FillType.evenOdd
        ? FillingRule.evenOdd
        : FillingRule.nonZero);
    
    // Transform and add path
    path.rewind();
    
    var result = path.nextVertex();
    while (result.cmd != PathCmd.stop) {
      var x = result.x;
      var y = result.y;
      final cmd = result.cmd;
      
      if (matrix != null) {
        final pt = matrix.transformPoint(FxPoint(x, y));
        x = pt.x;
        y = pt.y;
      }
      
      // Clamp coordinates
      x = x.clamp(-32000.0, 32000.0);
      y = y.clamp(-32000.0, 32000.0);
      
      if (isMoveTo(cmd)) {
        rasterizer.moveToD(x, y);
      } else if (isLineTo(cmd)) {
        rasterizer.lineToD(x, y);
      } else if (isClose(cmd)) {
        rasterizer.closePolygon();
      }
      
      result = path.nextVertex();
    }
  }

  void _strokePath(
    RasterizerScanlineAA rasterizer,
    PathStorage path,
    FxMatrix? matrix,
    CfxGraphStateData graphState,
  ) {
    // Calculate scale for line width
    double scale = 1.0;
    if (matrix != null) {
      scale = (matrix.getXUnit() + matrix.getYUnit()) / 2.0;
    }
    
    final width = math.max(graphState.lineWidth * scale, 1.0 / scale);
    
    // Convert path to stroke outline using AGG
    path.rewind();
    
    // Build stroked path
    final strokedPath = PathStorage();
    _buildStrokePath(strokedPath, path, matrix, graphState, width);
    
    // Add stroked path to rasterizer
    _addPathToRasterizer(rasterizer, strokedPath, null, 
        CfxFillRenderOptions(fillType: FillType.winding));
  }

  void _buildStrokePath(
    PathStorage output,
    PathStorage input,
    FxMatrix? matrix,
    CfxGraphStateData graphState,
    double width,
  ) {
    // Simple stroke by offsetting path - real implementation would use AGG stroke converter
    // This is a simplified version
    
    final halfWidth = width / 2;
    final points = <FxPoint>[];
    
    input.rewind();
    var result = input.nextVertex();
    
    while (result.cmd != PathCmd.stop) {
      var x = result.x;
      var y = result.y;
      final cmd = result.cmd;
      
      if (matrix != null) {
        final pt = matrix.transformPoint(FxPoint(x, y));
        x = pt.x;
        y = pt.y;
      }
      
      if (isMoveTo(cmd) || isLineTo(cmd)) {
        points.add(FxPoint(x, y));
      } else if (isClose(cmd)) {
        // Close and stroke the polyline
        if (points.length >= 2) {
          _strokePolyline(output, points, halfWidth, true, graphState);
        }
        points.clear();
      }
      
      result = input.nextVertex();
    }
    
    // Handle unclosed path
    if (points.length >= 2) {
      _strokePolyline(output, points, halfWidth, false, graphState);
    }
  }

  void _strokePolyline(
    PathStorage output,
    List<FxPoint> points,
    double halfWidth,
    bool closed,
    CfxGraphStateData graphState,
  ) {
    if (points.length < 2) return;
    
    // Create offset curves on both sides
    final leftPoints = <FxPoint>[];
    final rightPoints = <FxPoint>[];
    
    for (int i = 0; i < points.length; i++) {
      FxPoint dir;
      
      if (i == 0) {
        dir = _normalize(points[1] - points[0]);
      } else if (i == points.length - 1) {
        dir = _normalize(points[i] - points[i - 1]);
      } else {
        final d1 = _normalize(points[i] - points[i - 1]);
        final d2 = _normalize(points[i + 1] - points[i]);
        dir = _normalize(FxPoint((d1.x + d2.x) / 2, (d1.y + d2.y) / 2));
      }
      
      // Perpendicular
      final perp = FxPoint(-dir.y, dir.x);
      
      leftPoints.add(FxPoint(
        points[i].x + perp.x * halfWidth,
        points[i].y + perp.y * halfWidth,
      ));
      rightPoints.add(FxPoint(
        points[i].x - perp.x * halfWidth,
        points[i].y - perp.y * halfWidth,
      ));
    }
    
    // Build outline path
    if (leftPoints.isNotEmpty) {
      output.moveTo(leftPoints[0].x, leftPoints[0].y);
      for (int i = 1; i < leftPoints.length; i++) {
        output.lineTo(leftPoints[i].x, leftPoints[i].y);
      }
      
      // Add end cap or connection
      if (!closed) {
        _addLineCap(output, points.last, rightPoints.last, graphState.lineCap);
      }
      
      // Right side in reverse
      for (int i = rightPoints.length - 1; i >= 0; i--) {
        output.lineTo(rightPoints[i].x, rightPoints[i].y);
      }
      
      // Start cap or close
      if (!closed) {
        _addLineCap(output, points.first, leftPoints.first, graphState.lineCap);
      }
      
      output.closePolygon();
    }
  }

  FxPoint _normalize(FxPoint p) {
    final len = math.sqrt(p.x * p.x + p.y * p.y);
    if (len < 0.0001) return const FxPoint(1, 0);
    return FxPoint(p.x / len, p.y / len);
  }

  void _addLineCap(PathStorage output, FxPoint point, FxPoint endPoint, LineCap cap) {
    switch (cap) {
      case LineCap.round:
        // Add semicircle - simplified as line for now
        output.lineTo(endPoint.x, endPoint.y);
        break;
      case LineCap.square:
        // Extend by half width
        final dx = endPoint.x - point.x;
        final dy = endPoint.y - point.y;
        output.lineTo(endPoint.x + dy, endPoint.y - dx);
        break;
      case LineCap.butt:
      default:
        output.lineTo(endPoint.x, endPoint.y);
        break;
    }
  }

  void _renderRasterizer(RasterizerScanlineAA rasterizer, int color, bool fullCover) {
    final fxColor = FxColor(color);
    if (fxColor.alpha == 0) return;
    
    final clipBox = getClipBox();
    
    // Use scanline renderer
    final scanline = ScanlineU8();
    
    rasterizer.sort();
    
    while (rasterizer.sweepScanline(scanline)) {
      final y = scanline.y;
      if (y < clipBox.top || y >= clipBox.bottom) continue;
      
      for (final span in scanline.spans) {
        int x = span.x;
        int len = span.len;
        
        if (x < clipBox.left) {
          len -= clipBox.left - x;
          x = clipBox.left;
        }
        if (x + len > clipBox.right) {
          len = clipBox.right - x;
        }
        if (len <= 0) continue;
        
        // Render span - always use covers array
        _compositeSpan(x, y, len, fxColor, scanline.covers, span.coversOffset, fullCover);
      }
    }
  }

  void _compositeSpan(
    int x, int y, int len, 
    FxColor color, Uint8List covers, int coverOffset,
    bool fullCover,
  ) {
    if (_clipRgn != null && _clipRgn!.type == ClipRegionType.mask) {
      _compositeSpanWithMask(x, y, len, color, covers, coverOffset, fullCover);
      return;
    }
    
    for (int i = 0; i < len; i++) {
      final cover = covers[coverOffset + i];
      if (cover == 0) continue;
      
      final srcAlpha = fullCover 
          ? color.alpha 
          : (color.alpha * cover) ~/ 255;
      
      if (srcAlpha == 0) continue;
      
      _blendPixel(x + i, y, color, srcAlpha);
    }
  }

  void _compositeSolidSpan(
    int x, int y, int len,
    FxColor color, int cover,
    bool fullCover,
  ) {
    if (cover == 0) return;
    
    final srcAlpha = fullCover 
        ? color.alpha 
        : (color.alpha * cover) ~/ 255;
    
    if (srcAlpha == 0) return;
    
    for (int i = 0; i < len; i++) {
      _blendPixel(x + i, y, color, srcAlpha);
    }
  }

  void _compositeSpanWithMask(
    int x, int y, int len,
    FxColor color, Uint8List covers, int coverOffset,
    bool fullCover,
  ) {
    if (_clipRgn?.mask == null) return;
    
    final mask = _clipRgn!.mask!;
    final maskBox = _clipRgn!.box;
    
    for (int i = 0; i < len; i++) {
      final px = x + i;
      final maskX = px - maskBox.left;
      final maskY = y - maskBox.top;
      
      if (maskX < 0 || maskX >= mask.width || 
          maskY < 0 || maskY >= mask.height) continue;
      
      final maskAlpha = mask.getPixelGray(maskX, maskY);
      if (maskAlpha == 0) continue;
      
      final cover = covers[coverOffset + i];
      if (cover == 0) continue;
      
      final srcAlpha = fullCover
          ? (color.alpha * maskAlpha) ~/ 255
          : (color.alpha * cover * maskAlpha) ~/ (255 * 255);
      
      if (srcAlpha == 0) continue;
      
      _blendPixel(px, y, color, srcAlpha);
    }
  }

  void _blendPixel(int x, int y, FxColor color, int srcAlpha) {
    if (x < 0 || x >= _bitmap.width || y < 0 || y >= _bitmap.height) return;
    
    if (srcAlpha == 255) {
      _bitmap.setPixel(x, y, color);
      return;
    }
    
    final dst = _bitmap.getPixel(x, y);
    
    // Alpha blend
    final outAlpha = srcAlpha + dst.alpha - (srcAlpha * dst.alpha) ~/ 255;
    if (outAlpha == 0) return;
    
    final alphaRatio = (srcAlpha * 255) ~/ outAlpha;
    
    final outR = _alphaMerge(dst.red, color.red, alphaRatio);
    final outG = _alphaMerge(dst.green, color.green, alphaRatio);
    final outB = _alphaMerge(dst.blue, color.blue, alphaRatio);
    
    _bitmap.setPixel(x, y, FxColor.fromARGB(outAlpha, outR, outG, outB));
  }

  int _alphaMerge(int backdrop, int src, int alpha) {
    return backdrop + ((src - backdrop) * alpha) ~/ 255;
  }

  void _fillRectWithMask(FxRectInt rect, FxColor color, FxDIBitmap mask, FxRectInt maskBox) {
    for (int y = rect.top; y < rect.bottom; y++) {
      for (int x = rect.left; x < rect.right; x++) {
        final maskX = x - maskBox.left;
        final maskY = y - maskBox.top;
        
        if (maskX < 0 || maskX >= mask.width ||
            maskY < 0 || maskY >= mask.height) continue;
        
        final maskAlpha = mask.getPixelGray(maskX, maskY);
        if (maskAlpha == 0) continue;
        
        final srcAlpha = (color.alpha * maskAlpha) ~/ 255;
        if (srcAlpha == 0) continue;
        
        _blendPixel(x, y, color, srcAlpha);
      }
    }
  }

  void _renderRasterizerToMask(RasterizerScanlineAA rasterizer, FxDIBitmap mask, int offsetX, int offsetY) {
    final scanline = ScanlineU8();
    
    rasterizer.sort();
    
    while (rasterizer.sweepScanline(scanline)) {
      final y = scanline.y - offsetY;
      if (y < 0 || y >= mask.height) continue;
      
      for (final span in scanline.spans) {
        int x = span.x - offsetX;
        int len = span.len;
        
        if (x < 0) {
          len += x;
          x = 0;
        }
        if (x + len > mask.width) {
          len = mask.width - x;
        }
        if (len <= 0) continue;
        
        // Use scanline covers array
        for (int i = 0; i < len; i++) {
          final cover = scanline.getCover(span.coversOffset + i);
          final existing = mask.getPixelGray(x + i, y);
          mask.setPixelGray(x + i, y, math.max(existing, cover));
        }
      }
    }
  }
}
