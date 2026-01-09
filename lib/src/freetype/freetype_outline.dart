// FreeType 2 - A high-quality font engine
// Copyright (C) 1996-2025 by David Turner, Robert Wilhelm, and Werner Lemberg.
// Ported to Dart
//
// This file is part of the FreeType project, and may only be used,
// modified, and distributed under the terms of the FreeType project
// license.

/// FreeType outline representation and processing.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'freetype_types.dart';

// ============================================================================
// Outline Flags
// ============================================================================

/// Outline flags used in FT_Outline.flags.
class FtOutlineFlags {
  /// No flag set.
  static const int none = 0x0;
  
  /// The outline owns its arrays.
  static const int owner = 0x1;
  
  /// Use even-odd fill rule instead of non-zero winding.
  static const int evenOddFill = 0x2;
  
  /// Reverse fill direction (typically for Type 1 fonts).
  static const int reverseFill = 0x4;
  
  /// Ignore drop-outs during rasterization.
  static const int ignoreDropouts = 0x8;
  
  /// Use smart dropout control.
  static const int smartDropouts = 0x10;
  
  /// Include stubs in dropout control.
  static const int includeStubs = 0x20;
  
  /// Outline has overlapping contours.
  static const int overlap = 0x40;
  
  /// Use highest quality rendering.
  static const int highPrecision = 0x100;
  
  /// Use single pass rendering.
  static const int singlePass = 0x200;
}

// ============================================================================
// Curve Tags
// ============================================================================

/// Point tags for outline points.
class FtCurveTag {
  /// Point is on the curve.
  static const int on = 0x01;
  
  /// Second-order control point (conic/quadratic Bezier).
  static const int conic = 0x00;
  
  /// Third-order control point (cubic Bezier).
  static const int cubic = 0x02;
  
  /// Has scanmode information.
  static const int hasScanmode = 0x04;
  
  /// Reserved for TrueType hinter.
  static const int touchX = 0x08;
  
  /// Reserved for TrueType hinter.
  static const int touchY = 0x10;
  
  /// Touch both X and Y.
  static const int touchBoth = touchX | touchY;
}

/// Get the curve type from a tag byte.
int ftCurveTagType(int tag) => tag & 0x03;

/// Check if point is on the curve.
bool ftIsPointOnCurve(int tag) => (tag & FtCurveTag.on) != 0;

/// Check if control point is cubic (third-order).
bool ftIsCubicControl(int tag) => (tag & FtCurveTag.cubic) != 0;

/// Check if control point is conic (second-order).
bool ftIsConicControl(int tag) => ftCurveTagType(tag) == FtCurveTag.conic;

// ============================================================================
// Outline
// ============================================================================

/// Glyph outline representation.
/// 
/// An outline is a collection of contours, each defined by a series of
/// points with associated tags indicating whether each point is on the
/// curve or a control point.
class FtOutline {
  /// Number of contours.
  int nContours;
  
  /// Number of points.
  int nPoints;

  // Aliases for compatibility
  int get numContours => nContours;
  int get numPoints => nPoints;
  
  /// Array of point coordinates.
  List<FtVector> points;
  
  /// Array of point tags (on-curve, conic, cubic).
  Uint8List tags;
  
  /// Array of contour end point indices.
  Int16List contours;
  
  /// Outline flags.
  int flags;

  FtOutline({
    this.nContours = 0,
    this.nPoints = 0,
    List<FtVector>? points,
    Uint8List? tags,
    Int16List? contours,
    this.flags = 0,
  }) : points = points ?? [],
       tags = tags ?? Uint8List(0),
       contours = contours ?? Int16List(0);

  /// Create an empty outline with the given capacity.
  factory FtOutline.create(int maxContours, int maxPoints) {
    return FtOutline(
      nContours: 0,
      nPoints: 0,
      points: List<FtVector>.generate(maxPoints, (_) => FtVector()),
      tags: Uint8List(maxPoints),
      contours: Int16List(maxContours),
      flags: FtOutlineFlags.owner,
    );
  }

  /// Copy the outline.
  FtOutline copy() {
    final result = FtOutline(
      nContours: nContours,
      nPoints: nPoints,
      points: List<FtVector>.generate(nPoints, (i) => FtVector.copy(points[i])),
      tags: Uint8List.fromList(tags.sublist(0, nPoints)),
      contours: Int16List.fromList(contours.sublist(0, nContours)),
      flags: flags & ~FtOutlineFlags.owner,
    );
    return result;
  }

  /// Check if outline is empty.
  bool get isEmpty => nContours == 0 || nPoints == 0;

  /// Calculate bounding box.
  FtBBox getBBox() {
    if (nPoints == 0) {
      return FtBBox();
    }
    
    var xMin = points[0].x;
    var yMin = points[0].y;
    var xMax = xMin;
    var yMax = yMin;
    
    for (int i = 1; i < nPoints; i++) {
      final x = points[i].x;
      final y = points[i].y;
      
      if (x < xMin) xMin = x;
      if (x > xMax) xMax = x;
      if (y < yMin) yMin = y;
      if (y > yMax) yMax = y;
    }
    
    return FtBBox(xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax);
  }

  /// Translate the outline.
  void translate(int xOffset, int yOffset) {
    for (int i = 0; i < nPoints; i++) {
      points[i].x += xOffset;
      points[i].y += yOffset;
    }
  }

  /// Transform the outline by a 2x2 matrix.
  void transform(FtMatrix matrix) {
    for (int i = 0; i < nPoints; i++) {
      final p = points[i];
      final x = ftMulFix(p.x, matrix.xx) + ftMulFix(p.y, matrix.xy);
      final y = ftMulFix(p.x, matrix.yx) + ftMulFix(p.y, matrix.yy);
      p.x = x;
      p.y = y;
    }
  }

  /// Reverse the outline (flip contour orientation).
  void reverse() {
    if (nPoints == 0) return;
    
    int first = 0;
    for (int c = 0; c < nContours; c++) {
      final last = contours[c];
      
      // Reverse points in this contour
      int i = first;
      int j = last;
      while (i < j) {
        // Swap points
        final tmp = points[i];
        points[i] = points[j];
        points[j] = tmp;
        
        // Swap tags
        final tmpTag = tags[i];
        tags[i] = tags[j];
        tags[j] = tmpTag;
        
        i++;
        j--;
      }
      
      // Rotate tags to preserve first point's on-curve status
      if (last > first) {
        final firstTag = tags[first];
        for (int i = first; i < last; i++) {
          tags[i] = tags[i + 1];
        }
        tags[last] = firstTag;
      }
      
      first = last + 1;
    }
  }

  /// Decompose outline into moveto/lineto/conicto/cubicto callbacks.
  FtError decompose(FtOutlineFuncs funcs, [dynamic user]) {
    if (nContours == 0) {
      return FtErrors.ok;
    }
    
    int first = 0;
    
    for (int c = 0; c < nContours; c++) {
      final last = contours[c];
      
      if (last < first) {
        return FtErrors.invalidOutline;
      }
      
      // Find first on-curve point
      int start = first;
      int tag = ftCurveTagType(tags[start]);
      
      // Skip initial off-curve points
      while (tag != FtCurveTag.on && start <= last) {
        start++;
        if (start > last) {
          // All points are off-curve - need synthetic start point
          start = first;
          break;
        }
        tag = ftCurveTagType(tags[start]);
      }
      
      // Get starting point
      FtVector startPoint;
      if (ftIsPointOnCurve(tags[start])) {
        startPoint = points[start];
      } else {
        // All off-curve - start at midpoint between first and last
        startPoint = FtVector(
          (points[first].x + points[last].x) ~/ 2,
          (points[first].y + points[last].y) ~/ 2,
        );
      }
      
      // Move to start
      var error = funcs.moveTo?.call(startPoint, user) ?? 0;
      if (error != 0) return error;
      
      // Process points in contour
      int i = start;
      do {
        i++;
        if (i > last) i = first;
        if (i == start) break;
        
        final currentTag = ftCurveTagType(tags[i]);
        
        if (currentTag == FtCurveTag.on) {
          // Line to on-curve point
          error = funcs.lineTo?.call(points[i], user) ?? 0;
          if (error != 0) return error;
        } else if (currentTag == FtCurveTag.conic) {
          // Quadratic Bezier
          var control = points[i];
          
          // Look at next point
          int next = i + 1;
          if (next > last) next = first;
          
          final nextTag = ftCurveTagType(tags[next]);
          FtVector to;
          
          if (nextTag == FtCurveTag.on) {
            // Simple conic to next on-curve point
            to = points[next];
            i = next;
          } else {
            // Multiple off-curve points - insert on-curve point at midpoint
            to = FtVector(
              (control.x + points[next].x) ~/ 2,
              (control.y + points[next].y) ~/ 2,
            );
          }
          
          error = funcs.conicTo?.call(control, to, user) ?? 0;
          if (error != 0) return error;
          
          if (next == start) break;
        } else {
          // Cubic Bezier
          final control1 = points[i];
          
          int next = i + 1;
          if (next > last) next = first;
          
          if (ftCurveTagType(tags[next]) != FtCurveTag.cubic) {
            return FtErrors.invalidOutline;
          }
          
          final control2 = points[next];
          
          int next2 = next + 1;
          if (next2 > last) next2 = first;
          
          FtVector to;
          if (ftIsPointOnCurve(tags[next2])) {
            to = points[next2];
            i = next2;
          } else {
            return FtErrors.invalidOutline;
          }
          
          error = funcs.cubicTo?.call(control1, control2, to, user) ?? 0;
          if (error != 0) return error;
          
          if (next2 == start) break;
        }
      } while (true);
      
      first = last + 1;
    }
    
    return FtErrors.ok;
  }

  /// Embolden (make bolder) the outline.
  void embolden(int strength) {
    if (nPoints == 0) return;
    
    int first = 0;
    for (int c = 0; c < nContours; c++) {
      final last = contours[c];
      
      // Process each point in contour
      for (int i = first; i <= last; i++) {
        // Get previous and next points
        int prev = i - 1;
        if (prev < first) prev = last;
        
        int next = i + 1;
        if (next > last) next = first;
        
        // Calculate normal direction
        final dx1 = points[i].x - points[prev].x;
        final dy1 = points[i].y - points[prev].y;
        final dx2 = points[next].x - points[i].x;
        final dy2 = points[next].y - points[i].y;
        
        // Average direction
        var nx = -(dy1 + dy2);
        var ny = dx1 + dx2;
        
        // Normalize
        final len = math.sqrt(nx * nx + ny * ny);
        if (len > 0) {
          nx = (nx * strength / len).round();
          ny = (ny * strength / len).round();
          
          points[i].x += nx;
          points[i].y += ny;
        }
      }
      
      first = last + 1;
    }
  }

  @override
  String toString() => 'FtOutline($nContours contours, $nPoints points)';
}

// ============================================================================
// Outline Decomposition Functions
// ============================================================================

/// Callback function types for outline decomposition.
typedef FtOutlineMoveToFunc = int Function(FtVector to, dynamic user);
typedef FtOutlineLineToFunc = int Function(FtVector to, dynamic user);
typedef FtOutlineConicToFunc = int Function(FtVector control, FtVector to, dynamic user);
typedef FtOutlineCubicToFunc = int Function(FtVector control1, FtVector control2, FtVector to, dynamic user);

/// Function table for outline decomposition.
class FtOutlineFuncs {
  FtOutlineMoveToFunc? moveTo;
  FtOutlineLineToFunc? lineTo;
  FtOutlineConicToFunc? conicTo;
  FtOutlineCubicToFunc? cubicTo;
  
  /// Shift applied to coordinates before sending to callbacks.
  int shift;
  
  /// Delta applied to coordinates after shift.
  int delta;

  FtOutlineFuncs({
    this.moveTo,
    this.lineTo,
    this.conicTo,
    this.cubicTo,
    this.shift = 0,
    this.delta = 0,
  });
}

// ============================================================================
// Outline Builder
// ============================================================================

/// Helper class to build outlines from drawing commands.
class FtOutlineBuilder {
  final List<FtVector> _points = [];
  final List<int> _tags = [];
  final List<int> _contours = [];
  bool _inContour = false;

  /// Start a new contour at the given point.
  void moveTo(int x, int y) {
    if (_inContour) {
      closeContour();
    }
    _points.add(FtVector(x, y));
    _tags.add(FtCurveTag.on);
    _inContour = true;
  }

  /// Add a line to the given point.
  void lineTo(int x, int y) {
    if (!_inContour) {
      moveTo(x, y);
      return;
    }
    _points.add(FtVector(x, y));
    _tags.add(FtCurveTag.on);
  }

  /// Add a quadratic bezier curve.
  void conicTo(int cx, int cy, int x, int y) {
    if (!_inContour) {
      moveTo(cx, cy);
    }
    _points.add(FtVector(cx, cy));
    _tags.add(FtCurveTag.conic);
    _points.add(FtVector(x, y));
    _tags.add(FtCurveTag.on);
  }

  /// Add a cubic bezier curve.
  void cubicTo(int cx1, int cy1, int cx2, int cy2, int x, int y) {
    if (!_inContour) {
      moveTo(cx1, cy1);
    }
    _points.add(FtVector(cx1, cy1));
    _tags.add(FtCurveTag.cubic);
    _points.add(FtVector(cx2, cy2));
    _tags.add(FtCurveTag.cubic);
    _points.add(FtVector(x, y));
    _tags.add(FtCurveTag.on);
  }

  /// Close the current contour.
  void closeContour() {
    if (_inContour && _points.isNotEmpty) {
      _contours.add(_points.length - 1);
      _inContour = false;
    }
  }

  /// Build the outline.
  FtOutline build() {
    if (_inContour) {
      closeContour();
    }
    
    return FtOutline(
      nContours: _contours.length,
      nPoints: _points.length,
      points: List.from(_points),
      tags: Uint8List.fromList(_tags),
      contours: Int16List.fromList(_contours),
      flags: 0,
    );
  }

  /// Reset the builder.
  void reset() {
    _points.clear();
    _tags.clear();
    _contours.clear();
    _inContour = false;
  }
}
