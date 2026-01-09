/// Coordinate types for PDFium Dart
/// 
/// Port of core/fxcrt/fx_coordinates.h

import 'dart:math' as math;

/// Alias for FxPoint to match PDFium naming for float points
typedef FxPointF = FxPoint;

/// 2D Point with floating point coordinates
/// 
/// Equivalent to FS_POINTF in PDFium
class FxPoint {
  final double x;
  final double y;
  
  const FxPoint(this.x, this.y);
  const FxPoint.zero() : x = 0, y = 0;
  
  FxPoint operator +(FxPoint other) => FxPoint(x + other.x, y + other.y);
  FxPoint operator -(FxPoint other) => FxPoint(x - other.x, y - other.y);
  FxPoint operator *(double scale) => FxPoint(x * scale, y * scale);
  FxPoint operator /(double scale) => FxPoint(x / scale, y / scale);
  FxPoint operator -() => FxPoint(-x, -y);
  
  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;
  
  FxPoint normalize() {
    final len = length;
    if (len == 0) return const FxPoint.zero();
    return this / len;
  }
  
  double dot(FxPoint other) => x * other.x + y * other.y;
  double cross(FxPoint other) => x * other.y - y * other.x;
  
  double distanceTo(FxPoint other) => (this - other).length;
  
  FxPoint lerp(FxPoint other, double t) {
    return FxPoint(
      x + (other.x - x) * t,
      y + (other.y - y) * t,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FxPoint && x == other.x && y == other.y;
  
  @override
  int get hashCode => Object.hash(x, y);
  
  @override
  String toString() => 'FxPoint($x, $y)';
}

/// 2D Size with floating point dimensions
/// 
/// Equivalent to FS_SIZEF in PDFium
class FxSize {
  final double width;
  final double height;
  
  const FxSize(this.width, this.height);
  const FxSize.zero() : width = 0, height = 0;
  const FxSize.square(double size) : width = size, height = size;
  
  double get area => width * height;
  bool get isEmpty => width <= 0 || height <= 0;
  
  FxSize operator *(double scale) => FxSize(width * scale, height * scale);
  FxSize operator /(double scale) => FxSize(width / scale, height / scale);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FxSize && width == other.width && height == other.height;
  
  @override
  int get hashCode => Object.hash(width, height);
  
  @override
  String toString() => 'FxSize($width, $height)';
}

/// 2D Size with integer dimensions
class FxSizeInt {
  final int width;
  final int height;
  
  const FxSizeInt(this.width, this.height);
  const FxSizeInt.zero() : width = 0, height = 0;
  const FxSizeInt.square(int size) : width = size, height = size;
  
  int get area => width * height;
  bool get isEmpty => width <= 0 || height <= 0;
  
  FxSize toFloat() => FxSize(width.toDouble(), height.toDouble());
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FxSizeInt && width == other.width && height == other.height;
  
  @override
  int get hashCode => Object.hash(width, height);
  
  @override
  String toString() => 'FxSizeInt($width, $height)';
}

/// Rectangle with floating point coordinates
/// 
/// Equivalent to FS_RECTF in PDFium
class FxRect {
  final double left;
  final double top;
  final double right;
  final double bottom;
  
  const FxRect(this.left, this.top, this.right, this.bottom);
  const FxRect.zero() : left = 0, top = 0, right = 0, bottom = 0;
  
  factory FxRect.fromLTWH(double left, double top, double width, double height) {
    return FxRect(left, top, left + width, top + height);
  }
  
  factory FxRect.fromCenter(FxPoint center, double width, double height) {
    final halfWidth = width / 2;
    final halfHeight = height / 2;
    return FxRect(
      center.x - halfWidth,
      center.y - halfHeight,
      center.x + halfWidth,
      center.y + halfHeight,
    );
  }
  
  factory FxRect.fromPoints(FxPoint p1, FxPoint p2) {
    return FxRect(
      math.min(p1.x, p2.x),
      math.min(p1.y, p2.y),
      math.max(p1.x, p2.x),
      math.max(p1.y, p2.y),
    );
  }
  
  double get width => right - left;
  double get height => bottom - top;
  double get area => width * height;
  bool get isEmpty => width <= 0 || height <= 0;
  
  FxPoint get topLeft => FxPoint(left, top);
  FxPoint get topRight => FxPoint(right, top);
  FxPoint get bottomLeft => FxPoint(left, bottom);
  FxPoint get bottomRight => FxPoint(right, bottom);
  FxPoint get center => FxPoint((left + right) / 2, (top + bottom) / 2);
  FxSize get size => FxSize(width, height);
  
  bool contains(FxPoint point) {
    return point.x >= left && point.x <= right &&
           point.y >= top && point.y <= bottom;
  }
  
  bool containsRect(FxRect other) {
    return other.left >= left && other.right <= right &&
           other.top >= top && other.bottom <= bottom;
  }
  
  bool intersects(FxRect other) {
    return left < other.right && right > other.left &&
           top < other.bottom && bottom > other.top;
  }
  
  FxRect? intersection(FxRect other) {
    final newLeft = math.max(left, other.left);
    final newTop = math.max(top, other.top);
    final newRight = math.min(right, other.right);
    final newBottom = math.min(bottom, other.bottom);
    
    if (newLeft >= newRight || newTop >= newBottom) {
      return null;
    }
    return FxRect(newLeft, newTop, newRight, newBottom);
  }
  
  FxRect union(FxRect other) {
    return FxRect(
      math.min(left, other.left),
      math.min(top, other.top),
      math.max(right, other.right),
      math.max(bottom, other.bottom),
    );
  }
  
  FxRect inflate(double dx, double dy) {
    return FxRect(left - dx, top - dy, right + dx, bottom + dy);
  }
  
  FxRect deflate(double dx, double dy) {
    return FxRect(left + dx, top + dy, right - dx, bottom - dy);
  }
  
  FxRect translate(double dx, double dy) {
    return FxRect(left + dx, top + dy, right + dx, bottom + dy);
  }
  
  FxRect normalized() {
    return FxRect(
      math.min(left, right),
      math.min(top, bottom),
      math.max(left, right),
      math.max(top, bottom),
    );
  }
  
  FxRectInt toInt() {
    return FxRectInt(
      left.floor(),
      top.floor(),
      right.ceil(),
      bottom.ceil(),
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FxRect &&
          left == other.left &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom;
  
  @override
  int get hashCode => Object.hash(left, top, right, bottom);
  
  @override
  String toString() => 'FxRect($left, $top, $right, $bottom)';
}

/// Rectangle with integer coordinates
class FxRectInt {
  final int left;
  final int top;
  final int right;
  final int bottom;
  
  const FxRectInt(this.left, this.top, this.right, this.bottom);
  const FxRectInt.zero() : left = 0, top = 0, right = 0, bottom = 0;
  
  factory FxRectInt.fromLTWH(int left, int top, int width, int height) {
    return FxRectInt(left, top, left + width, top + height);
  }
  
  int get width => right - left;
  int get height => bottom - top;
  int get area => width * height;
  bool get isEmpty => width <= 0 || height <= 0;
  
  FxSizeInt get size => FxSizeInt(width, height);
  
  /// Intersect with another rectangle.
  FxRectInt intersect(FxRectInt other) {
    return FxRectInt(
      math.max(left, other.left),
      math.max(top, other.top),
      math.min(right, other.right),
      math.min(bottom, other.bottom),
    );
  }
  
  /// Check if this rectangle intersects with another.
  bool intersects(FxRectInt other) {
    return left < other.right && right > other.left &&
           top < other.bottom && bottom > other.top;
  }
  
  /// Union with another rectangle.
  FxRectInt union(FxRectInt other) {
    return FxRectInt(
      math.min(left, other.left),
      math.min(top, other.top),
      math.max(right, other.right),
      math.max(bottom, other.bottom),
    );
  }
  
  /// Check if point is inside this rectangle.
  bool contains(int x, int y) {
    return x >= left && x < right && y >= top && y < bottom;
  }
  
  FxRect toFloat() {
    return FxRect(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FxRectInt &&
          left == other.left &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom;
  
  @override
  int get hashCode => Object.hash(left, top, right, bottom);
  
  @override
  String toString() => 'FxRectInt($left, $top, $right, $bottom)';
}

/// Quad points (4 corners) - used for annotations
/// 
/// Equivalent to FS_QUADPOINTSF in PDFium
class FxQuadPoints {
  final FxPoint p1;
  final FxPoint p2;
  final FxPoint p3;
  final FxPoint p4;
  
  const FxQuadPoints(this.p1, this.p2, this.p3, this.p4);
  
  factory FxQuadPoints.fromRect(FxRect rect) {
    return FxQuadPoints(
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    );
  }
  
  FxRect get boundingRect {
    return FxRect(
      [p1.x, p2.x, p3.x, p4.x].reduce(math.min),
      [p1.y, p2.y, p3.y, p4.y].reduce(math.min),
      [p1.x, p2.x, p3.x, p4.x].reduce(math.max),
      [p1.y, p2.y, p3.y, p4.y].reduce(math.max),
    );
  }
  
  @override
  String toString() => 'FxQuadPoints($p1, $p2, $p3, $p4)';
}

/// Transformation matrix for 2D graphics
/// 
/// Equivalent to FS_MATRIX in PDFium:
/// | a  b  0 |
/// | c  d  0 |
/// | e  f  1 |
class FxMatrix {
  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;
  
  const FxMatrix(this.a, this.b, this.c, this.d, this.e, this.f);
  
  /// Identity matrix constructor
  const FxMatrix.identity() : a = 1, b = 0, c = 0, d = 1, e = 0, f = 0;
  
  /// Create a translation matrix
  factory FxMatrix.translate(double tx, double ty) {
    return FxMatrix(1, 0, 0, 1, tx, ty);
  }
  
  /// Create a scaling matrix
  factory FxMatrix.scale(double sx, double sy) {
    return FxMatrix(sx, 0, 0, sy, 0, 0);
  }
  
  /// Create a uniform scaling matrix
  factory FxMatrix.uniformScale(double s) {
    return FxMatrix(s, 0, 0, s, 0, 0);
  }
  
  /// Create a rotation matrix (angle in radians)
  factory FxMatrix.rotate(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return FxMatrix(cos, sin, -sin, cos, 0, 0);
  }
  
  /// Create a rotation matrix (angle in degrees)
  factory FxMatrix.rotateDegrees(double degrees) {
    return FxMatrix.rotate(degrees * math.pi / 180);
  }
  
  /// Create a skew/shear matrix
  factory FxMatrix.skew(double skewX, double skewY) {
    return FxMatrix(1, math.tan(skewY), math.tan(skewX), 1, 0, 0);
  }
  
  /// Translation component
  FxPoint get translation => FxPoint(e, f);
  
  /// Scale component (approximate, doesn't account for rotation)
  FxPoint get scale => FxPoint(
    math.sqrt(a * a + c * c),
    math.sqrt(b * b + d * d),
  );
  
  /// Get X scale unit (magnitude of transformed unit X vector).
  double getXUnit() => math.sqrt(a * a + b * b);
  
  /// Get Y scale unit (magnitude of transformed unit Y vector).
  double getYUnit() => math.sqrt(c * c + d * d);
  
  /// Rotation angle in radians (approximate)
  double get rotation => math.atan2(b, a);
  
  /// Check if this is an identity matrix
  bool get isIdentity =>
      a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;
  
  /// Determinant of the matrix
  double get determinant => a * d - b * c;
  
  /// Check if matrix is invertible
  bool get isInvertible => determinant.abs() > 1e-10;
  
  /// Multiply this matrix by another
  FxMatrix operator *(FxMatrix other) {
    return FxMatrix(
      a * other.a + b * other.c,
      a * other.b + b * other.d,
      c * other.a + d * other.c,
      c * other.b + d * other.d,
      e * other.a + f * other.c + other.e,
      e * other.b + f * other.d + other.f,
    );
  }
  
  /// Transform a point
  FxPoint transformPoint(FxPoint point) {
    return FxPoint(
      a * point.x + c * point.y + e,
      b * point.x + d * point.y + f,
    );
  }
  
  /// Transform a vector (ignores translation)
  FxPoint transformVector(FxPoint vector) {
    return FxPoint(
      a * vector.x + c * vector.y,
      b * vector.x + d * vector.y,
    );
  }
  
  /// Transform a rectangle (returns bounding box of transformed corners)
  FxRect transformRect(FxRect rect) {
    final p1 = transformPoint(rect.topLeft);
    final p2 = transformPoint(rect.topRight);
    final p3 = transformPoint(rect.bottomLeft);
    final p4 = transformPoint(rect.bottomRight);
    
    return FxRect(
      [p1.x, p2.x, p3.x, p4.x].reduce(math.min),
      [p1.y, p2.y, p3.y, p4.y].reduce(math.min),
      [p1.x, p2.x, p3.x, p4.x].reduce(math.max),
      [p1.y, p2.y, p3.y, p4.y].reduce(math.max),
    );
  }
  
  /// Get the inverse matrix
  FxMatrix? inverse() {
    final det = determinant;
    if (det.abs() < 1e-10) return null;
    
    final invDet = 1.0 / det;
    return FxMatrix(
      d * invDet,
      -b * invDet,
      -c * invDet,
      a * invDet,
      (c * f - d * e) * invDet,
      (b * e - a * f) * invDet,
    );
  }
  
  /// Concatenate a translation
  FxMatrix translate(double tx, double ty) {
    return this * FxMatrix.translate(tx, ty);
  }
  
  /// Concatenate a scale
  FxMatrix scaleBy(double sx, double sy) {
    return this * FxMatrix.scale(sx, sy);
  }
  
  /// Concatenate a rotation
  FxMatrix rotateBy(double angle) {
    return this * FxMatrix.rotate(angle);
  }
  
  /// Create array representation [a, b, c, d, e, f]
  List<double> toList() => [a, b, c, d, e, f];
  
  /// Concatenate this matrix with another matrix
  /// Returns this * other (applies other first, then this)
  FxMatrix concat(FxMatrix other) {
    return this * other;
  }
  
  /// Pre-concatenate another matrix with this one  
  /// Returns other * this (applies this first, then other)
  FxMatrix preConcat(FxMatrix other) {
    return other * this;
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FxMatrix &&
          a == other.a &&
          b == other.b &&
          c == other.c &&
          d == other.d &&
          e == other.e &&
          f == other.f;
  
  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);
  
  @override
  String toString() => 'FxMatrix[$a, $b, $c, $d, $e, $f]';
}
