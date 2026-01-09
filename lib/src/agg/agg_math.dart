// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG mathematical functions for geometry calculations.
library;

import 'dart:math' as math;
import 'agg_basics.dart';

// ============================================================================
// Cross Product
// ============================================================================

/// Calculate cross product of vectors (x1,y1)->(x2,y2) and (x2,y2)->(x,y)
double crossProduct(
  double x1, double y1,
  double x2, double y2,
  double x, double y,
) {
  return (x - x2) * (y2 - y1) - (y - y2) * (x2 - x1);
}

// ============================================================================
// Point in Triangle
// ============================================================================

/// Check if point (x,y) is inside triangle (x1,y1), (x2,y2), (x3,y3)
bool pointInTriangle(
  double x1, double y1,
  double x2, double y2,
  double x3, double y3,
  double x, double y,
) {
  final cp1 = crossProduct(x1, y1, x2, y2, x, y) < 0.0;
  final cp2 = crossProduct(x2, y2, x3, y3, x, y) < 0.0;
  final cp3 = crossProduct(x3, y3, x1, y1, x, y) < 0.0;
  return cp1 == cp2 && cp2 == cp3 && cp3 == cp1;
}

// ============================================================================
// Distance Calculations
// ============================================================================

/// Calculate distance between two points
double calcDistance(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return math.sqrt(dx * dx + dy * dy);
}

/// Calculate squared distance between two points (faster, no sqrt)
double calcSqDistance(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return dx * dx + dy * dy;
}

/// Calculate distance from point (x,y) to line (x1,y1)-(x2,y2)
double calcLinePointDistance(
  double x1, double y1,
  double x2, double y2,
  double x, double y,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final d = math.sqrt(dx * dx + dy * dy);
  if (d < vertexDistEpsilon) {
    return calcDistance(x1, y1, x, y);
  }
  return ((x - x2) * dy - (y - y2) * dx) / d;
}

/// Calculate parameter u for closest point on segment to given point
double calcSegmentPointU(
  double x1, double y1,
  double x2, double y2,
  double x, double y,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;

  if (dx == 0 && dy == 0) {
    return 0;
  }

  final pdx = x - x1;
  final pdy = y - y1;

  return (pdx * dx + pdy * dy) / (dx * dx + dy * dy);
}

/// Calculate squared distance from point to segment with given u parameter
double calcSegmentPointSqDistanceWithU(
  double x1, double y1,
  double x2, double y2,
  double x, double y,
  double u,
) {
  if (u <= 0) {
    return calcSqDistance(x, y, x1, y1);
  } else if (u >= 1) {
    return calcSqDistance(x, y, x2, y2);
  }
  return calcSqDistance(x, y, x1 + u * (x2 - x1), y1 + u * (y2 - y1));
}

/// Calculate squared distance from point to segment
double calcSegmentPointSqDistance(
  double x1, double y1,
  double x2, double y2,
  double x, double y,
) {
  return calcSegmentPointSqDistanceWithU(
    x1, y1, x2, y2, x, y,
    calcSegmentPointU(x1, y1, x2, y2, x, y),
  );
}

// ============================================================================
// Line Intersection
// ============================================================================

/// Calculate intersection point of two lines
/// Returns null if lines are parallel
({double x, double y})? calcIntersection(
  double ax, double ay, double bx, double by,
  double cx, double cy, double dx, double dy,
) {
  final num = (ay - cy) * (dx - cx) - (ax - cx) * (dy - cy);
  final den = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx);
  
  if (den.abs() < intersectionEpsilon) return null;
  
  final r = num / den;
  return (x: ax + r * (bx - ax), y: ay + r * (by - ay));
}

/// Check if two line segments intersect
bool intersectionExists(
  double x1, double y1, double x2, double y2,
  double x3, double y3, double x4, double y4,
) {
  final dx1 = x2 - x1;
  final dy1 = y2 - y1;
  final dx2 = x4 - x3;
  final dy2 = y4 - y3;
  
  return ((x3 - x2) * dy1 - (y3 - y2) * dx1 < 0.0) !=
         ((x4 - x2) * dy1 - (y4 - y2) * dx1 < 0.0) &&
         ((x1 - x4) * dy2 - (y1 - y4) * dx2 < 0.0) !=
         ((x2 - x4) * dy2 - (y2 - y4) * dx2 < 0.0);
}

// ============================================================================
// Orthogonal Calculation
// ============================================================================

/// Calculate orthogonal offset for line segment
({double x, double y}) calcOrthogonal(
  double thickness,
  double x1, double y1,
  double x2, double y2,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final d = math.sqrt(dx * dx + dy * dy);
  return (x: thickness * dy / d, y: -thickness * dx / d);
}

// ============================================================================
// Triangle Operations
// ============================================================================

/// Dilate triangle by distance d
/// Returns 6 points (3 edges, 2 points each)
List<double> dilateTriangle(
  double x1, double y1,
  double x2, double y2,
  double x3, double y3,
  double d,
) {
  double dx1 = 0.0, dy1 = 0.0;
  double dx2 = 0.0, dy2 = 0.0;
  double dx3 = 0.0, dy3 = 0.0;
  
  final loc = crossProduct(x1, y1, x2, y2, x3, y3);
  if (loc.abs() > intersectionEpsilon) {
    if (crossProduct(x1, y1, x2, y2, x3, y3) > 0.0) {
      d = -d;
    }
    final o1 = calcOrthogonal(d, x1, y1, x2, y2);
    dx1 = o1.x; dy1 = o1.y;
    final o2 = calcOrthogonal(d, x2, y2, x3, y3);
    dx2 = o2.x; dy2 = o2.y;
    final o3 = calcOrthogonal(d, x3, y3, x1, y1);
    dx3 = o3.x; dy3 = o3.y;
  }
  
  return [
    x1 + dx1, y1 + dy1,
    x2 + dx1, y2 + dy1,
    x2 + dx2, y2 + dy2,
    x3 + dx2, y3 + dy2,
    x3 + dx3, y3 + dy3,
    x1 + dx3, y1 + dy3,
  ];
}

/// Calculate triangle area (signed)
double calcTriangleArea(
  double x1, double y1,
  double x2, double y2,
  double x3, double y3,
) {
  return (x1 * y2 - x2 * y1 + x2 * y3 - x3 * y2 + x3 * y1 - x1 * y3) * 0.5;
}

/// Calculate polygon area from list of points
double calcPolygonArea(List<PointD> points) {
  if (points.isEmpty) return 0.0;
  
  double sum = 0.0;
  double x = points[0].x;
  double y = points[0].y;
  final xs = x;
  final ys = y;

  for (int i = 1; i < points.length; i++) {
    final v = points[i];
    sum += x * v.y - y * v.x;
    x = v.x;
    y = v.y;
  }
  
  return (sum + x * ys - y * xs) * 0.5;
}

// ============================================================================
// Fast Square Root (using lookup tables)
// ============================================================================

/// Sqrt lookup table
final List<int> _sqrtTable = _initSqrtTable();

/// Elder bit lookup table
final List<int> _elderBitTable = _initElderBitTable();

List<int> _initSqrtTable() {
  final table = List<int>.filled(1024, 0);
  for (int i = 0; i < 1024; i++) {
    table[i] = (math.sqrt(i / 1024.0) * 65535.0).round();
  }
  return table;
}

List<int> _initElderBitTable() {
  final table = List<int>.filled(256, 0);
  for (int i = 0; i < 256; i++) {
    int n = i;
    int bit = 0;
    while (n > 0) {
      bit++;
      n >>= 1;
    }
    table[i] = bit;
  }
  return table;
}

/// Fast integer square root
int fastSqrt(int val) {
  if (val == 0) return 0;
  
  int t = val;
  int bit = 0;
  int shift = 11;

  int b = t >> 24;
  if (b != 0) {
    bit = _elderBitTable[b] + 24;
  } else {
    b = (t >> 16) & 0xFF;
    if (b != 0) {
      bit = _elderBitTable[b] + 16;
    } else {
      b = (t >> 8) & 0xFF;
      if (b != 0) {
        bit = _elderBitTable[b] + 8;
      } else {
        bit = _elderBitTable[t & 0xFF];
      }
    }
  }

  bit -= 9;
  if (bit > 0) {
    bit = (bit >> 1) + (bit & 1);
    shift -= bit;
    val >>= (bit << 1);
  }
  
  if (val >= 1024) val = 1023;
  return _sqrtTable[val] >> shift;
}

// ============================================================================
// Bessel Function
// ============================================================================

/// Bessel function of first kind of order n
double besj(double x, int n) {
  if (n < 0) return 0;
  
  const double d = 1e-6;
  double b = 0;
  
  if (x.abs() <= d) {
    if (n != 0) return 0;
    return 1;
  }
  
  double b1 = 0;
  int m1 = x.abs().toInt() + 6;
  if (x.abs() > 5) {
    m1 = (1.4 * x.abs() + 60 / x.abs()).toInt();
  }
  int m2 = (n + 2 + x.abs() / 4).toInt();
  if (m1 > m2) m2 = m1;

  while (true) {
    double c3 = 0;
    double c2 = 1e-30;
    double c4 = 0;
    int m8 = 1;
    if (m2 ~/ 2 * 2 == m2) m8 = -1;
    
    final imax = m2 - 2;
    for (int i = 1; i <= imax; i++) {
      double c6 = 2 * (m2 - i) * c2 / x - c3;
      c3 = c2;
      c2 = c6;
      if (m2 - i - 1 == n) b = c6;
      m8 = -1 * m8;
      if (m8 > 0) c4 = c4 + 2 * c6;
    }
    
    double c6 = 2 * c2 / x - c3;
    if (n == 0) b = c6;
    c4 += c6;
    b /= c4;
    
    if ((b - b1).abs() < d) return b;
    
    b1 = b;
    m2 += 3;
  }
}

// ============================================================================
// Angle and Vector Operations
// ============================================================================

/// Normalize angle to range [0, 2*pi)
double normalizeAngle(double angle) {
  while (angle < 0) angle += 2 * aggPi;
  while (angle >= 2 * aggPi) angle -= 2 * aggPi;
  return angle;
}

/// Calculate angle between two points
double calcAngle(double x1, double y1, double x2, double y2) {
  return math.atan2(y2 - y1, x2 - x1);
}

/// Interpolate between two values
double lerp(double a, double b, double t) {
  return a + (b - a) * t;
}

/// Clamp value to range [min, max]
double clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Clamp integer value to range [min, max]
int clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
