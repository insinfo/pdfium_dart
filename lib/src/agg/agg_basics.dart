

import 'dart:math' as math;
import 'dart:typed_data';

// ============================================================================
// Basic Constants
// ============================================================================

/// Pi constant
const double aggPi = 3.14159265358979323846;

/// Affine epsilon for matrix comparisons
const double affineEpsilon = 1e-14;

/// Coinciding points maximal distance (Epsilon)
const double vertexDistEpsilon = 1e-14;

/// Intersection calculation epsilon
const double intersectionEpsilon = 1.0e-30;

/// Vertex information
class Vertex {
  double x;
  double y;
  int cmd;

  Vertex(this.x, this.y, this.cmd);
  
  @override
  String toString() => 'Vertex($x, $y, $cmd)';
}

// ============================================================================
// Rounding Functions
// ============================================================================

/// Round to nearest integer
int iround(double v) {
  return (v < 0.0) ? (v - 0.5).toInt() : (v + 0.5).toInt();
}

/// Round to nearest unsigned integer
int uround(double v) {
  return (v + 0.5).toInt();
}

/// Floor to integer
int ifloor(double v) {
  int i = v.toInt();
  return i - (i > v ? 1 : 0);
}

/// Floor to unsigned integer
int ufloor(double v) {
  return v.toInt();
}

/// Ceiling to integer
int iceil(double v) {
  return v.ceil();
}

/// Ceiling to unsigned integer
int uceil(double v) {
  return v.ceil();
}

/// Saturated round with limit
int saturatedRound(double v, int limit) {
  if (v < -limit) return -limit;
  if (v > limit) return limit;
  return iround(v);
}

// ============================================================================
// Degree/Radian Conversion
// ============================================================================

/// Convert degrees to radians
double deg2rad(double deg) => deg * aggPi / 180.0;

/// Convert radians to degrees
double rad2deg(double rad) => rad * 180.0 / aggPi;

// ============================================================================
// Cover Type for Anti-Aliasing
// ============================================================================

/// Cover type for anti-aliasing (0-255)
typedef CoverType = int;

/// Cover scale constants
abstract class CoverScale {
  static const int shift = 8;
  static const int size = 1 << shift; // 256
  static const int mask = size - 1; // 255
  static const int none = 0;
  static const int full = mask; // 255
}

// ============================================================================
// Subpixel Scale for Polygon Rasterization
// ============================================================================

/// Subpixel scale constants for polygon rasterization
abstract class PolySubpixelScale {
  static const int shift = 8;
  static const int scale = 1 << shift; // 256
  static const int mask = scale - 1; // 255
}

// ============================================================================
// Filling Rule
// ============================================================================

/// Filling rule enumeration
enum FillingRule {
  nonZero,
  evenOdd,
}

// ============================================================================
// Path Commands
// ============================================================================

/// Path command types
abstract class PathCmd {
  static const int stop = 0;
  static const int moveTo = 1;
  static const int lineTo = 2;
  static const int curve3 = 3;
  static const int curve4 = 4;
  static const int curveN = 5;
  static const int catrom = 6;
  static const int ubspline = 7;
  static const int endPoly = 0x0F;
  static const int mask = 0x0F;
}

/// Path flags
abstract class PathFlags {
  static const int none = 0;
  static const int ccw = 0x10; // Counter-clockwise
  static const int cw = 0x20; // Clockwise
  static const int close = 0x40;
  static const int mask = 0xF0;
}

// ============================================================================
// Path Command Functions
// ============================================================================

/// Check if command is a vertex command
bool isVertex(int cmd) {
  return cmd >= PathCmd.moveTo && cmd < PathCmd.endPoly;
}

/// Check if command is a drawing command
bool isDrawing(int cmd) {
  return cmd >= PathCmd.lineTo && cmd < PathCmd.endPoly;
}

/// Check if command is stop
bool isStop(int cmd) {
  return cmd == PathCmd.stop;
}

/// Check if command is move_to
bool isMoveTo(int cmd) {
  return cmd == PathCmd.moveTo;
}

/// Check if command is line_to
bool isLineTo(int cmd) {
  return cmd == PathCmd.lineTo;
}

/// Check if command is a curve (curve3 or curve4)
bool isCurve(int cmd) {
  return cmd == PathCmd.curve3 || cmd == PathCmd.curve4;
}

/// Check if command is curve3
bool isCurve3(int cmd) {
  return cmd == PathCmd.curve3;
}

/// Check if command is curve4
bool isCurve4(int cmd) {
  return cmd == PathCmd.curve4;
}

/// Check if command is end_poly
bool isEndPoly(int cmd) {
  return (cmd & PathCmd.mask) == PathCmd.endPoly;
}

/// Check if command is close
bool isClose(int cmd) {
  return (cmd & ~(PathFlags.cw | PathFlags.ccw)) ==
      (PathCmd.endPoly | PathFlags.close);
}

/// Check if command starts next polygon
bool isNextPoly(int cmd) {
  return isStop(cmd) || isMoveTo(cmd) || isEndPoly(cmd);
}

/// Check if path is clockwise
bool isCw(int cmd) {
  return (cmd & PathFlags.cw) != 0;
}

/// Check if path is counter-clockwise
bool isCcw(int cmd) {
  return (cmd & PathFlags.ccw) != 0;
}

/// Check if path has orientation
bool isOriented(int cmd) {
  return (cmd & (PathFlags.cw | PathFlags.ccw)) != 0;
}

/// Check if path is closed
bool isClosed(int cmd) {
  return (cmd & PathFlags.close) != 0;
}

/// Get close flag from command
int getCloseFlag(int cmd) {
  return cmd & PathFlags.close;
}

/// Clear orientation from command
int clearOrientation(int cmd) {
  return cmd & ~(PathFlags.cw | PathFlags.ccw);
}

/// Get orientation from command
int getOrientation(int cmd) {
  return cmd & (PathFlags.cw | PathFlags.ccw);
}

/// Set orientation on command
int setOrientation(int cmd, int orientation) {
  return clearOrientation(cmd) | orientation;
}

// ============================================================================
// Point Types
// ============================================================================

/// Integer point
class PointI {
  int x;
  int y;

  PointI([this.x = 0, this.y = 0]);

  PointI.from(PointI other) : x = other.x, y = other.y;

  @override
  bool operator ==(Object other) =>
      other is PointI && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PointI($x, $y)';
}

/// Float point
class PointF {
  double x;
  double y;

  PointF([this.x = 0.0, this.y = 0.0]);

  PointF.from(PointF other) : x = other.x, y = other.y;

  @override
  bool operator ==(Object other) =>
      other is PointF && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PointF($x, $y)';
}

/// Double precision point
class PointD {
  double x;
  double y;

  PointD([this.x = 0.0, this.y = 0.0]);

  PointD.from(PointD other) : x = other.x, y = other.y;

  @override
  bool operator ==(Object other) =>
      other is PointD && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PointD($x, $y)';
}

// ============================================================================
// Vertex Types
// ============================================================================

/// Vertex with integer coordinates
class VertexI {
  int x;
  int y;
  int cmd;

  VertexI([this.x = 0, this.y = 0, this.cmd = PathCmd.stop]);
}

/// Vertex with float coordinates
class VertexF {
  double x;
  double y;
  int cmd;

  VertexF([this.x = 0.0, this.y = 0.0, this.cmd = PathCmd.stop]);
}

/// Vertex with double precision coordinates
class VertexD {
  double x;
  double y;
  int cmd;

  VertexD([this.x = 0.0, this.y = 0.0, this.cmd = PathCmd.stop]);

  VertexD.from(VertexD other)
    : x = other.x,
      y = other.y,
      cmd = other.cmd;

  @override
  String toString() => 'VertexD($x, $y, cmd: $cmd)';
}

// ============================================================================
// Rectangle Types
// ============================================================================

/// Generic rectangle base
class RectBase<T extends num> {
  T x1, y1, x2, y2;

  RectBase(this.x1, this.y1, this.x2, this.y2);

  void init(T x1, T y1, T x2, T y2) {
    this.x1 = x1;
    this.y1 = y1;
    this.x2 = x2;
    this.y2 = y2;
  }

  bool get isValid => x1 <= x2 && y1 <= y2;

  bool hitTest(T x, T y) {
    return x >= x1 && x <= x2 && y >= y1 && y <= y2;
  }

  bool overlaps(RectBase<T> r) {
    return !(r.x1 > x2 || r.x2 < x1 || r.y1 > y2 || r.y2 < y1);
  }

  bool clip(RectBase<T> r) {
    if (x2 < r.x1 || x1 > r.x2 || y2 < r.y1 || y1 > r.y2) {
      x1 = x2;
      y1 = y2; // Empty
      return false;
    }
    if (x1 < r.x1) x1 = r.x1;
    if (y1 < r.y1) y1 = r.y1;
    if (x2 > r.x2) x2 = r.x2;
    if (y2 > r.y2) y2 = r.y2;
    return true;
  }

  @override
  String toString() => 'Rect($x1, $y1, $x2, $y2)';
}

/// Integer rectangle
class RectI extends RectBase<int> {
  RectI([int x1 = 0, int y1 = 0, int x2 = 0, int y2 = 0]) : super(x1, y1, x2, y2);

  RectI.from(RectI other) : super(other.x1, other.y1, other.x2, other.y2);

  RectI normalize() {
    if (x1 > x2) {
      final t = x1;
      x1 = x2;
      x2 = t;
    }
    if (y1 > y2) {
      final t = y1;
      y1 = y2;
      y2 = t;
    }
    return this;
  }

  @override
  bool clip(RectBase<int> r) {
    if (x2 > r.x2) x2 = r.x2;
    if (y2 > r.y2) y2 = r.y2;
    if (x1 < r.x1) x1 = r.x1;
    if (y1 < r.y1) y1 = r.y1;
    return x1 <= x2 && y1 <= y2;
  }
}

/// Float rectangle
class RectF extends RectBase<double> {
  RectF([double x1 = 0, double y1 = 0, double x2 = 0, double y2 = 0])
    : super(x1, y1, x2, y2);

  RectF.from(RectF other) : super(other.x1, other.y1, other.x2, other.y2);

  RectF normalize() {
    if (x1 > x2) {
      final t = x1;
      x1 = x2;
      x2 = t;
    }
    if (y1 > y2) {
      final t = y1;
      y1 = y2;
      y2 = t;
    }
    return this;
  }

  @override
  bool clip(RectBase<double> r) {
    if (x2 > r.x2) x2 = r.x2;
    if (y2 > r.y2) y2 = r.y2;
    if (x1 < r.x1) x1 = r.x1;
    if (y1 < r.y1) y1 = r.y1;
    return x1 <= x2 && y1 <= y2;
  }
}

/// Double precision rectangle
class RectD extends RectBase<double> {
  RectD([double x1 = 0, double y1 = 0, double x2 = 0, double y2 = 0])
    : super(x1, y1, x2, y2);

  RectD.from(RectD other) : super(other.x1, other.y1, other.x2, other.y2);

  RectD normalize() {
    if (x1 > x2) {
      final t = x1;
      x1 = x2;
      x2 = t;
    }
    if (y1 > y2) {
      final t = y1;
      y1 = y2;
      y2 = t;
    }
    return this;
  }

  @override
  bool clip(RectBase<double> r) {
    if (x2 > r.x2) x2 = r.x2;
    if (y2 > r.y2) y2 = r.y2;
    if (x1 < r.x1) x1 = r.x1;
    if (y1 < r.y1) y1 = r.y1;
    return x1 <= x2 && y1 <= y2;
  }
}

// ============================================================================
// Rectangle Operations
// ============================================================================

/// Intersect two rectangles
RectI intersectRectanglesI(RectI r1, RectI r2) {
  final r = RectI.from(r1);
  if (r.x2 > r2.x2) r.x2 = r2.x2;
  if (r.y2 > r2.y2) r.y2 = r2.y2;
  if (r.x1 < r2.x1) r.x1 = r2.x1;
  if (r.y1 < r2.y1) r.y1 = r2.y1;
  return r;
}

/// Unite two rectangles
RectI uniteRectanglesI(RectI r1, RectI r2) {
  final r = RectI.from(r1);
  if (r.x2 < r2.x2) r.x2 = r2.x2;
  if (r.y2 < r2.y2) r.y2 = r2.y2;
  if (r.x1 > r2.x1) r.x1 = r2.x1;
  if (r.y1 > r2.y1) r.y1 = r2.y1;
  return r;
}

/// Intersect two rectangles (double)
RectD intersectRectanglesD(RectD r1, RectD r2) {
  final r = RectD.from(r1);
  if (r.x2 > r2.x2) r.x2 = r2.x2;
  if (r.y2 > r2.y2) r.y2 = r2.y2;
  if (r.x1 < r2.x1) r.x1 = r2.x1;
  if (r.y1 < r2.y1) r.y1 = r2.y1;
  return r;
}

/// Unite two rectangles (double)
RectD uniteRectanglesD(RectD r1, RectD r2) {
  final r = RectD.from(r1);
  if (r.x2 < r2.x2) r.x2 = r2.x2;
  if (r.y2 < r2.y2) r.y2 = r2.y2;
  if (r.x1 > r2.x1) r.x1 = r2.x1;
  if (r.y1 > r2.y1) r.y1 = r2.y1;
  return r;
}

// ============================================================================
// Row Info for Rendering Buffer
// ============================================================================

/// Row info for rendering buffer
class RowInfo<T> {
  int x1;
  int x2;
  T ptr;

  RowInfo(this.x1, this.x2, this.ptr);
}

// ============================================================================
// Equality with Epsilon
// ============================================================================

/// Check if two values are equal within epsilon
bool isEqualEps(double v1, double v2, double epsilon) {
  bool neg1 = v1 < 0.0;
  bool neg2 = v2 < 0.0;

  if (neg1 != neg2) {
    return v1.abs() < epsilon && v2.abs() < epsilon;
  }

  // Simplified comparison for Dart
  return (v1 - v2).abs() < epsilon * (1.0 + v1.abs().clamp(0, double.maxFinite));
}

// ============================================================================
// Multiply One (for fixed-point arithmetic)
// ============================================================================

/// Multiply with rounding for fixed-point arithmetic
int mulOne(int a, int b, int shift) {
  int q = a * b + (1 << (shift - 1));
  return (q + (q >> shift)) >> shift;
}
