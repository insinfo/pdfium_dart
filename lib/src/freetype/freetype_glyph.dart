// FreeType 2 - A high-quality font engine
// Copyright (C) 1996-2025 by David Turner, Robert Wilhelm, and Werner Lemberg.
// Ported to Dart
//
// Glyph loading, scaling, and rendering.

/// FreeType glyph management and rendering.
library;

import 'dart:typed_data';
import 'dart:math' as math;
import 'freetype_types.dart';
import 'freetype_outline.dart';
import 'freetype_face.dart';

// ============================================================================
// Glyph Operations
// ============================================================================

/// Abstract base class for glyphs.
abstract class FtGlyph {
  /// Format of the glyph.
  FtGlyphFormat get format;
  
  /// Advance vector (in 16.16 fixed-point).
  FtVector advance = FtVector();
  
  /// Copy this glyph.
  FtGlyph copy();
  
  /// Transform the glyph.
  void transform(FtMatrix? matrix, FtVector? delta);
  
  /// Get the bounding box.
  FtBBox getBBox(int bboxMode);
  
  /// Convert to bitmap.
  FtBitmapGlyph? toBitmap(FtRenderMode renderMode, FtVector? origin, bool destroy);
}

/// Bitmap glyph (rendered).
class FtBitmapGlyph extends FtGlyph {
  @override
  FtGlyphFormat get format => FtGlyphFormat.bitmap;
  
  /// Left offset of bitmap.
  int left = 0;
  
  /// Top offset of bitmap.
  int top = 0;
  
  /// The bitmap data.
  FtBitmap bitmap = FtBitmap();

  FtBitmapGlyph();

  @override
  FtBitmapGlyph copy() {
    final result = FtBitmapGlyph();
    result.advance = advance.copy();
    result.left = left;
    result.top = top;
    result.bitmap = bitmap.copy();
    return result;
  }

  @override
  void transform(FtMatrix? matrix, FtVector? delta) {
    // Bitmap transformation is limited
    if (delta != null) {
      left += ftFixedToInt(delta.x);
      top += ftFixedToInt(delta.y);
    }
    // Matrix transform would need resampling - not implemented here
  }

  @override
  FtBBox getBBox(int bboxMode) {
    return FtBBox(
      xMin: left,
      yMin: top - bitmap.rows,
      xMax: left + bitmap.width,
      yMax: top,
    );
  }

  @override
  FtBitmapGlyph? toBitmap(FtRenderMode renderMode, FtVector? origin, bool destroy) {
    // Already a bitmap
    return destroy ? this : copy();
  }
}

/// Outline glyph (scalable).
class FtOutlineGlyph extends FtGlyph {
  @override
  FtGlyphFormat get format => FtGlyphFormat.outline;
  
  /// The outline data.
  FtOutline outline = FtOutline();

  FtOutlineGlyph();

  @override
  FtOutlineGlyph copy() {
    final result = FtOutlineGlyph();
    result.advance = advance.copy();
    result.outline = outline.copy();
    return result;
  }

  @override
  void transform(FtMatrix? matrix, FtVector? delta) {
    if (matrix != null) outline.transform(matrix);
    if (delta != null) {
      outline.translate(delta.x, delta.y);
    }
  }

  @override
  FtBBox getBBox(int bboxMode) {
    return outline.getBBox();
  }

  @override
  FtBitmapGlyph? toBitmap(FtRenderMode renderMode, FtVector? origin, bool destroy) {
    // Create bitmap glyph and render
    final result = FtBitmapGlyph();
    result.advance = advance.copy();
    
    // Get bounding box
    final bbox = outline.getBBox();
    
    // Compute bitmap dimensions (26.6 to pixels)
    final left = bbox.xMin >> 6;
    final top = (bbox.yMax + 63) >> 6;
    final width = ((bbox.xMax + 63) >> 6) - left;
    final height = top - (bbox.yMin >> 6);
    
    if (width <= 0 || height <= 0) {
      return result;
    }
    
    result.left = left;
    result.top = top;
    
    // Setup bitmap
    result.bitmap.width = width;
    result.bitmap.rows = height;
    result.bitmap.pitch = width;
    result.bitmap.pixelMode = FtPixelMode.gray;
    result.bitmap.numGrays = 256;
    result.bitmap.buffer = Uint8List(width * height);
    
    // Render using scanline converter
    _renderOutline(outline, result.bitmap, -left, top, renderMode);
    
    return result;
  }
}

// ============================================================================
// Scanline Rendering
// ============================================================================

/// Internal rendering context.
class _RenderContext {
  final FtBitmap bitmap;
  final int offsetX;
  final int offsetY;
  final FtRenderMode mode;
  
  _RenderContext(this.bitmap, this.offsetX, this.offsetY, this.mode);
}

/// Edge for scanline rasterization.
class _Edge {
  int yMin;
  int yMax;
  FtFixed x;
  FtFixed dx;
  int direction;
  
  _Edge({
    required this.yMin,
    required this.yMax,
    required this.x,
    required this.dx,
    required this.direction,
  });
}

/// Render an outline to a bitmap.
void _renderOutline(FtOutline outline, FtBitmap bitmap, 
                    int offsetX, int offsetY, FtRenderMode mode) {
  if (bitmap.buffer == null) return;
  
  // Build edge list
  final edges = <_Edge>[];
  _buildEdges(outline, edges, offsetX << 6, offsetY << 6);
  
  if (edges.isEmpty) return;
  
  // Sort edges by yMin
  edges.sort((a, b) => a.yMin.compareTo(b.yMin));
  
  // Scanline render
  final width = bitmap.width;
  final height = bitmap.rows;
  final buffer = bitmap.buffer!;
  final pitch = bitmap.pitch;
  
  // Active edge list
  final active = <_Edge>[];
  var edgeIndex = 0;
  
  for (var y = 0; y < height; y++) {
    final scanY = y << 6; // Convert to 26.6
    
    // Add edges that start at this scanline
    while (edgeIndex < edges.length && edges[edgeIndex].yMin <= scanY) {
      if (edges[edgeIndex].yMax > scanY) {
        active.add(edges[edgeIndex]);
      }
      edgeIndex++;
    }
    
    // Remove edges that end before this scanline
    active.removeWhere((e) => e.yMax <= scanY);
    
    if (active.isEmpty) continue;
    
    // Sort active edges by x
    active.sort((a, b) => a.x.compareTo(b.x));
    
    // Fill spans using winding rule
    var winding = 0;
    var startX = 0;
    
    for (final edge in active) {
      final x = (edge.x + 32) >> 6; // Round to pixel
      
      if (winding != 0) {
        // Fill from startX to x
        final x0 = math.max(0, startX);
        final x1 = math.min(width, x);
        for (var px = x0; px < x1; px++) {
          buffer[y * pitch + px] = 255;
        }
      }
      
      winding += edge.direction;
      startX = x;
      
      // Update x for next scanline
      edge.x += edge.dx;
    }
  }
}

/// Build edge list from outline.
void _buildEdges(FtOutline outline, List<_Edge> edges, int offsetX, int offsetY) {
  if (outline.numPoints == 0) return;
  
  var contourStart = 0;
  
  for (var c = 0; c < outline.numContours; c++) {
    final contourEnd = outline.contours[c];
    
    for (var i = contourStart; i <= contourEnd; i++) {
      final next = (i == contourEnd) ? contourStart : i + 1;
      
      var x0 = outline.points[i].x + offsetX;
      var y0 = -outline.points[i].y + offsetY; // Flip Y
      var x1 = outline.points[next].x + offsetX;
      var y1 = -outline.points[next].y + offsetY;
      
      // Skip horizontal edges
      if (y0 == y1) continue;
      
      // Ensure y0 < y1
      int direction;
      if (y0 > y1) {
        final tx = x0; x0 = x1; x1 = tx;
        final ty = y0; y0 = y1; y1 = ty;
        direction = -1;
      } else {
        direction = 1;
      }
      
      // Calculate dx/dy
      final dy = y1 - y0;
      final dx = ((x1 - x0) << 16) ~/ dy;
      
      edges.add(_Edge(
        yMin: y0,
        yMax: y1,
        x: x0 << 10, // Pre-scale for precision
        dx: dx,
        direction: direction,
      ));
    }
    
    contourStart = contourEnd + 1;
  }
}

// ============================================================================
// Glyph Scaling
// ============================================================================

/// Scale font metrics.
class FtScaler {
  /// Scale a value from font units to 26.6 pixels.
  static FtPos scaleValue(int value, FtFixed scale) {
    return ftMulFix(value, scale);
  }
  
  /// Scale a vector from font units to 26.6 pixels.
  static void scaleVector(FtVector v, FtFixed xScale, FtFixed yScale) {
    v.x = ftMulFix(v.x, xScale);
    v.y = ftMulFix(v.y, yScale);
  }
  
  /// Scale an outline from font units to 26.6 pixels.
  static void scaleOutline(FtOutline outline, FtFixed xScale, FtFixed yScale) {
    for (var i = 0; i < outline.numPoints; i++) {
      outline.points[i].x = ftMulFix(outline.points[i].x, xScale);
      outline.points[i].y = ftMulFix(outline.points[i].y, yScale);
    }
  }
  
  /// Calculate scale from size and units per EM.
  static FtFixed calculateScale(int pixelSize, int unitsPerEM) {
    if (unitsPerEM == 0) return 0;
    return ftDivFix(pixelSize << 6, unitsPerEM);
  }
}

// ============================================================================
// Kerning
// ============================================================================

/// Kerning mode.
enum FtKerningMode {
  /// Default kerning (scaled font units).
  defaultMode,
  /// Unscaled kerning (font units).
  unfitted,
  /// Unscaled kerning.
  unscaled,
}

/// Kerning pair.
class FtKerningPair {
  /// Left glyph index.
  final int leftGlyph;
  
  /// Right glyph index.
  final int rightGlyph;
  
  /// Kerning value.
  final FtVector kerning;

  FtKerningPair({
    required this.leftGlyph,
    required this.rightGlyph,
    required this.kerning,
  });
}

/// Kerning table (simplified).
class FtKerningTable {
  final Map<int, FtVector> _pairs = {};

  /// Make a key from two glyph indices.
  static int _makeKey(int left, int right) => (left << 16) | right;

  /// Add a kerning pair.
  void addPair(int leftGlyph, int rightGlyph, int x, int y) {
    _pairs[_makeKey(leftGlyph, rightGlyph)] = FtVector(x, y);
  }

  /// Get kerning for a glyph pair.
  FtVector? getKerning(int leftGlyph, int rightGlyph) {
    return _pairs[_makeKey(leftGlyph, rightGlyph)];
  }

  /// Check if table has any pairs.
  bool get isEmpty => _pairs.isEmpty;
}

// ============================================================================
// Sub-pixel Positioning
// ============================================================================

/// Sub-pixel position utilities.
class FtSubPixel {
  /// Number of sub-pixel positions (4 = 1/4 pixel).
  static const int positions = 4;
  
  /// Mask for sub-pixel position.
  static const int mask = positions - 1;
  
  /// Bits for sub-pixel position.
  static const int bits = 2;
  
  /// Get sub-pixel position from 26.6 value.
  static int getPosition(FtPos value) {
    return (value >> (6 - bits)) & mask;
  }
  
  /// Round to sub-pixel grid.
  static FtPos round(FtPos value) {
    final shift = 6 - bits;
    return ((value + (1 << (shift - 1))) >> shift) << shift;
  }
  
  /// Floor to sub-pixel grid.
  static FtPos floor(FtPos value) {
    final shift = 6 - bits;
    return (value >> shift) << shift;
  }
  
  /// Ceil to sub-pixel grid.
  static FtPos ceil(FtPos value) {
    final shift = 6 - bits;
    return ((value + ((1 << shift) - 1)) >> shift) << shift;
  }
}
