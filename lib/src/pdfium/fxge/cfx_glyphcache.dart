// Copyright 2016 The PDFium Authors
// Ported to Dart
//
// Glyph cache for efficient rendering.

/// Glyph cache for efficient rendering.
library;

import 'dart:typed_data';
import 'dart:math' as math;

import '../fxcrt/fx_coordinates.dart';
import '../../freetype/freetype.dart';
import 'cfx_glyphbitmap.dart';

// ============================================================================
// Font Anti-Aliasing Mode
// ============================================================================

/// Anti-aliasing modes for font rendering.
enum FontAntiAliasingMode {
  /// No anti-aliasing (monochrome).
  none,
  /// Normal grayscale anti-aliasing.
  normal,
  /// LCD sub-pixel anti-aliasing (horizontal RGB).
  lcdHorizontal,
  /// LCD sub-pixel anti-aliasing (vertical RGB).
  lcdVertical,
}

// ============================================================================
// Text Render Options
// ============================================================================

/// Options for text rendering.
class CfxTextRenderOptions {
  /// Native text rendering (platform-specific).
  bool nativeText;
  
  /// Anti-aliasing mode.
  FontAntiAliasingMode aliasMode;

  CfxTextRenderOptions({
    this.nativeText = false,
    this.aliasMode = FontAntiAliasingMode.normal,
  });

  /// Default options.
  static CfxTextRenderOptions get defaultOptions => CfxTextRenderOptions();
}

// ============================================================================
// Unique Key Generator for Cache
// ============================================================================

/// Generates unique keys for glyph cache lookup.
class _UniqueKeyGen {
  final List<int> _key = [];

  _UniqueKeyGen({
    required FxMatrix matrix,
    required int destWidth,
    required FontAntiAliasingMode antiAlias,
    int weight = 0,
    int italicAngle = 0,
    bool vertical = false,
  }) {
    // Convert matrix to integer representation (10000x precision)
    _key.add((matrix.a * 10000).round());
    _key.add((matrix.b * 10000).round());
    _key.add((matrix.c * 10000).round());
    _key.add((matrix.d * 10000).round());
    _key.add(destWidth);
    _key.add(antiAlias.index);
    if (weight != 0 || italicAngle != 0 || vertical) {
      _key.add(weight);
      _key.add(italicAngle);
      _key.add(vertical ? 1 : 0);
    }
  }

  String get keyString => _key.join('_');
}

// ============================================================================
// Glyph Cache
// ============================================================================

/// Cache for rendered glyph bitmaps.
/// 
/// Caches rendered glyphs to avoid re-rasterization for the same
/// glyph/size/transform combinations.
class CfxGlyphCache {
  /// The font face this cache belongs to.
  final FtFace? face;
  
  /// Cache of size-specific glyph bitmaps.
  /// Key: "sizeKey_glyphIndex"
  final Map<String, Map<int, CfxGlyphBitmap>> _sizeCache = {};
  
  /// Cache of glyph paths.
  /// Key: (glyphIndex, destWidth, weight, angle, vertical)
  final Map<String, FtOutline> _pathCache = {};
  
  /// Cache of glyph widths.
  /// Key: (glyphIndex, destWidth, weight)
  final Map<String, int> _widthCache = {};

  CfxGlyphCache(this.face);

  /// Load a glyph bitmap from cache or render it.
  CfxGlyphBitmap? loadGlyphBitmap({
    required int glyphIndex,
    required bool bFontStyle,
    required FxMatrix matrix,
    required int destWidth,
    required FontAntiAliasingMode antiAlias,
    int weight = 0,
    int italicAngle = 0,
    bool vertical = false,
  }) {
    if (face == null) return null;

    // Generate cache key
    final keyGen = _UniqueKeyGen(
      matrix: matrix,
      destWidth: destWidth,
      antiAlias: antiAlias,
      weight: weight,
      italicAngle: italicAngle,
      vertical: vertical,
    );
    final sizeKey = keyGen.keyString;

    // Check cache
    final sizeMap = _sizeCache[sizeKey];
    if (sizeMap != null) {
      final cached = sizeMap[glyphIndex];
      if (cached != null) {
        return cached;
      }
    }

    // Render the glyph
    final bitmap = _renderGlyph(
      glyphIndex: glyphIndex,
      bFontStyle: bFontStyle,
      matrix: matrix,
      destWidth: destWidth,
      antiAlias: antiAlias,
      weight: weight,
      italicAngle: italicAngle,
    );

    if (bitmap == null) return null;

    // Store in cache
    _sizeCache.putIfAbsent(sizeKey, () => {});
    _sizeCache[sizeKey]![glyphIndex] = bitmap;

    return bitmap;
  }

  /// Load a glyph path from cache or create it.
  FtOutline? loadGlyphPath({
    required int glyphIndex,
    required int destWidth,
    int weight = 0,
    int angle = 0,
    bool vertical = false,
  }) {
    if (face == null) return null;

    final key = '${glyphIndex}_${destWidth}_${weight}_${angle}_$vertical';
    
    final cached = _pathCache[key];
    if (cached != null) {
      return cached;
    }

    // Load outline from glyph
    final slot = face!.glyph;
    if (slot.format != FtGlyphFormat.outline) {
      return null;
    }

    final outline = slot.outline.copy();
    
    // Apply transformations for weight/italic
    if (weight > 0 || angle != 0) {
      _transformOutline(outline, weight, angle, vertical);
    }

    _pathCache[key] = outline;
    return outline;
  }

  /// Get the width of a glyph.
  int getGlyphWidth({
    required int glyphIndex,
    required int destWidth,
    int weight = 0,
  }) {
    final key = '${glyphIndex}_${destWidth}_$weight';
    
    final cached = _widthCache[key];
    if (cached != null) {
      return cached;
    }

    if (face == null) return 0;

    // Get advance width from metrics
    final metrics = face!.glyph.metrics;
    int width = metrics.horiAdvance;

    // Adjust for weight
    if (weight > 0) {
      width += weight ~/ 4;
    }

    _widthCache[key] = width;
    return width;
  }

  /// Clear the cache.
  void clear() {
    _sizeCache.clear();
    _pathCache.clear();
    _widthCache.clear();
  }

  // Internal rendering method
  CfxGlyphBitmap? _renderGlyph({
    required int glyphIndex,
    required bool bFontStyle,
    required FxMatrix matrix,
    required int destWidth,
    required FontAntiAliasingMode antiAlias,
    int weight = 0,
    int italicAngle = 0,
  }) {
    if (face == null) return null;

    final slot = face!.glyph;
    
    // If already a bitmap, use it directly
    if (slot.format == FtGlyphFormat.bitmap) {
      final ftBitmap = slot.bitmap;
      if (ftBitmap.buffer == null || ftBitmap.width <= 0 || ftBitmap.rows <= 0) {
        return CfxGlyphBitmap.empty();
      }
      return CfxGlyphBitmap(
        left: slot.bitmapLeft,
        top: slot.bitmapTop,
        width: ftBitmap.width,
        rows: ftBitmap.rows,
        pitch: ftBitmap.pitch,
        buffer: Uint8List.fromList(ftBitmap.buffer!),
      );
    }

    // Render from outline
    if (slot.format != FtGlyphFormat.outline) {
      return CfxGlyphBitmap.empty();
    }

    final outline = slot.outline;
    
    // Transform outline based on matrix
    final transformedOutline = outline.copy();
    
    // Apply matrix transformation (FtMatrix uses positional args)
    final ftMatrix = FtMatrix(
      (matrix.a * 0x10000).round(),
      (matrix.b * 0x10000).round(),
      (matrix.c * 0x10000).round(),
      (matrix.d * 0x10000).round(),
    );
    transformedOutline.transform(ftMatrix);

    // Apply weight/italic transformations
    if (weight > 0 || italicAngle != 0) {
      _transformOutline(transformedOutline, weight, italicAngle, false);
    }

    // Get bounding box
    final bbox = transformedOutline.getBBox();
    
    // Calculate bitmap dimensions (26.6 fixed point to pixels)
    final left = bbox.xMin >> 6;
    final top = (bbox.yMax + 63) >> 6;
    final width = ((bbox.xMax + 63) >> 6) - left;
    final height = top - (bbox.yMin >> 6);

    if (width <= 0 || height <= 0) {
      return CfxGlyphBitmap.empty();
    }

    // Create bitmap buffer
    final pitch = width;
    final buffer = Uint8List(width * height);

    // Render the outline to bitmap
    _renderOutlineToBitmap(
      transformedOutline,
      buffer,
      width,
      height,
      pitch,
      -left,
      top,
      antiAlias,
    );

    return CfxGlyphBitmap(
      left: left,
      top: top,
      width: width,
      rows: height,
      pitch: pitch,
      buffer: buffer,
    );
  }

  void _transformOutline(FtOutline outline, int weight, int angle, bool vertical) {
    // Embolden for weight
    if (weight > 0) {
      // Simple emboldening: expand points outward
      final strength = weight << 6; // Convert to 26.6
      outline.embolden(strength);
    }

    // Slant for italic
    if (angle != 0) {
      // Create slant matrix (positional args)
      final slant = math.tan(angle * math.pi / 180.0);
      final slantMatrix = FtMatrix(
        0x10000,
        (slant * 0x10000).round(),
        0,
        0x10000,
      );
      outline.transform(slantMatrix);
    }
  }

  void _renderOutlineToBitmap(
    FtOutline outline,
    Uint8List buffer,
    int width,
    int height,
    int pitch,
    int offsetX,
    int offsetY,
    FontAntiAliasingMode antiAlias,
  ) {
    // Use scanline rasterizer
    final edges = <_Edge>[];
    _buildEdgeList(outline, edges, offsetX << 6, offsetY << 6);

    if (edges.isEmpty) return;

    // Sort edges by yMin
    edges.sort((a, b) => a.yMin.compareTo(b.yMin));

    // Scanline rendering
    final activeEdges = <_Edge>[];
    int edgeIndex = 0;

    for (int y = 0; y < height; y++) {
      final scanY = y << 6;

      // Add edges that start at this scanline
      while (edgeIndex < edges.length && edges[edgeIndex].yMin <= scanY) {
        if (edges[edgeIndex].yMax > scanY) {
          activeEdges.add(edges[edgeIndex]);
        }
        edgeIndex++;
      }

      // Remove edges that end at this scanline
      activeEdges.removeWhere((e) => e.yMax <= scanY);

      if (activeEdges.isEmpty) continue;

      // Sort active edges by x
      activeEdges.sort((a, b) => a.x.compareTo(b.x));

      // Fill spans using even-odd rule
      final rowOffset = y * pitch;
      
      for (int i = 0; i < activeEdges.length - 1; i += 2) {
        final x1 = math.max(0, (activeEdges[i].x >> 6));
        final x2 = math.min(width - 1, (activeEdges[i + 1].x >> 6));

        if (antiAlias == FontAntiAliasingMode.none) {
          // Monochrome: fill solid
          for (int x = x1; x <= x2; x++) {
            buffer[rowOffset + x] = 255;
          }
        } else {
          // Anti-aliased: use coverage
          for (int x = x1; x <= x2; x++) {
            // Full coverage for interior pixels
            int coverage = 255;
            
            // Edge pixels get partial coverage
            if (x == x1) {
              final frac = activeEdges[i].x & 0x3F;
              coverage = 255 - (frac << 2);
            } else if (x == x2) {
              final frac = activeEdges[i + 1].x & 0x3F;
              coverage = frac << 2;
            }
            
            // Blend with existing value
            final existing = buffer[rowOffset + x];
            buffer[rowOffset + x] = math.min(255, existing + coverage);
          }
        }
      }

      // Advance x coordinates
      for (final edge in activeEdges) {
        edge.x += edge.dx;
      }
    }
  }

  void _buildEdgeList(FtOutline outline, List<_Edge> edges, int offsetX, int offsetY) {
    if (outline.points.isEmpty) return;

    int contourStart = 0;
    
    for (final contourEnd in outline.contours) {
      // Process each segment in the contour
      for (int i = contourStart; i <= contourEnd; i++) {
        final next = (i == contourEnd) ? contourStart : i + 1;
        
        final p1 = outline.points[i];
        final p2 = outline.points[next];
        
        // Transform points
        int x1 = p1.x + offsetX;
        int y1 = offsetY - p1.y; // Flip Y
        int x2 = p2.x + offsetX;
        int y2 = offsetY - p2.y;

        // Skip horizontal edges
        if (y1 == y2) continue;

        // Ensure y1 < y2
        if (y1 > y2) {
          final tx = x1; x1 = x2; x2 = tx;
          final ty = y1; y1 = y2; y2 = ty;
        }

        // Calculate dx (x change per scanline)
        final dx = ((x2 - x1) << 6) ~/ (y2 - y1);

        edges.add(_Edge(
          yMin: y1,
          yMax: y2,
          x: x1,
          dx: dx,
        ));
      }
      
      contourStart = contourEnd + 1;
    }
  }
}

/// Edge for scanline rasterization.
class _Edge {
  int yMin;
  int yMax;
  int x;
  int dx;

  _Edge({
    required this.yMin,
    required this.yMax,
    required this.x,
    required this.dx,
  });
}
