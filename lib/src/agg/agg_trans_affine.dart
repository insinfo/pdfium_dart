// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG Affine transformation classes.
///
/// Affine transformations are linear transformations in Cartesian coordinates.
/// They include rotation, scaling, translation and skewing.
/// After any affine transformation a line segment remains a line segment.
library;

import 'dart:math' as math;
import 'agg_basics.dart';

// ============================================================================
// TransAffine - 2D Affine Transformation Matrix
// ============================================================================

/// 2D Affine transformation matrix.
///
/// The matrix is stored as:
/// ```
/// | sx  shy 0 |
/// | shx sy  0 |
/// | tx  ty  1 |
/// ```
///
/// Where:
/// - sx, sy: scaling factors
/// - shx, shy: shearing factors
/// - tx, ty: translation
///
/// Usage example:
/// ```dart
/// final m = TransAffine();
/// m.rotate(30.0 * pi / 180.0);
/// m.scale(2.0, 1.5);
/// m.translate(100.0, 100.0);
/// final point = m.transform(x, y);
/// ```
class TransAffine {
  double sx;
  double shy;
  double shx;
  double sy;
  double tx;
  double ty;

  /// Create identity matrix
  TransAffine()
    : sx = 1.0,
      shy = 0.0,
      shx = 0.0,
      sy = 1.0,
      tx = 0.0,
      ty = 0.0;

  /// Create matrix with custom values
  TransAffine.values(this.sx, this.shy, this.shx, this.sy, this.tx, this.ty);

  /// Create matrix from array [sx, shy, shx, sy, tx, ty]
  TransAffine.fromArray(List<double> m)
    : sx = m[0],
      shy = m[1],
      shx = m[2],
      sy = m[3],
      tx = m[4],
      ty = m[5];

  /// Copy constructor
  TransAffine.from(TransAffine other)
    : sx = other.sx,
      shy = other.shy,
      shx = other.shx,
      sy = other.sy,
      tx = other.tx,
      ty = other.ty;

  /// Create transformation from rectangle to parallelogram
  factory TransAffine.rectToParl(
    double x1, double y1, double x2, double y2,
    List<double> parl,
  ) {
    final m = TransAffine();
    m._rectToParl(x1, y1, x2, y2, parl);
    return m;
  }

  /// Create transformation from parallelogram to rectangle
  factory TransAffine.parlToRect(
    List<double> parl,
    double x1, double y1, double x2, double y2,
  ) {
    final m = TransAffine();
    m._parlToRect(parl, x1, y1, x2, y2);
    return m;
  }

  /// Create transformation from parallelogram to parallelogram
  factory TransAffine.parlToParl(List<double> src, List<double> dst) {
    final m = TransAffine();
    m._parlToParl(src, dst);
    return m;
  }

  // -------------------------------------------------------------------------
  // Parallelogram transformations
  // -------------------------------------------------------------------------

  void _parlToParl(List<double> src, List<double> dst) {
    sx = src[2] - src[0];
    shy = src[3] - src[1];
    shx = src[4] - src[0];
    sy = src[5] - src[1];
    tx = src[0];
    ty = src[1];
    invert();
    multiply(TransAffine.values(
      dst[2] - dst[0], dst[3] - dst[1],
      dst[4] - dst[0], dst[5] - dst[1],
      dst[0], dst[1],
    ));
  }

  void _rectToParl(double x1, double y1, double x2, double y2, List<double> parl) {
    final src = [x1, y1, x2, y1, x2, y2];
    _parlToParl(src, parl);
  }

  void _parlToRect(List<double> parl, double x1, double y1, double x2, double y2) {
    final dst = [x1, y1, x2, y1, x2, y2];
    _parlToParl(parl, dst);
  }

  // -------------------------------------------------------------------------
  // Reset to identity
  // -------------------------------------------------------------------------

  /// Reset to identity matrix
  TransAffine reset() {
    sx = 1.0;
    shy = 0.0;
    shx = 0.0;
    sy = 1.0;
    tx = 0.0;
    ty = 0.0;
    return this;
  }

  // -------------------------------------------------------------------------
  // Direct transformations
  // -------------------------------------------------------------------------

  /// Add translation
  TransAffine translate(double x, double y) {
    tx += x;
    ty += y;
    return this;
  }

  /// Add rotation (angle in radians)
  TransAffine rotate(double a) {
    final ca = math.cos(a);
    final sa = math.sin(a);
    final t0 = sx * ca - shy * sa;
    final t2 = shx * ca - sy * sa;
    final t4 = tx * ca - ty * sa;
    shy = sx * sa + shy * ca;
    sy = shx * sa + sy * ca;
    ty = tx * sa + ty * ca;
    sx = t0;
    shx = t2;
    tx = t4;
    return this;
  }

  /// Add uniform scaling
  TransAffine scaleUniform(double s) {
    sx *= s;
    shx *= s;
    tx *= s;
    shy *= s;
    sy *= s;
    ty *= s;
    return this;
  }

  /// Add non-uniform scaling
  TransAffine scale(double x, double y) {
    sx *= x;
    shx *= x;
    tx *= x;
    shy *= y;
    sy *= y;
    ty *= y;
    return this;
  }

  // -------------------------------------------------------------------------
  // Matrix multiplication
  // -------------------------------------------------------------------------

  /// Multiply this matrix by another: this = this * m
  TransAffine multiply(TransAffine m) {
    final t0 = sx * m.sx + shy * m.shx;
    final t2 = shx * m.sx + sy * m.shx;
    final t4 = tx * m.sx + ty * m.shx + m.tx;
    shy = sx * m.shy + shy * m.sy;
    sy = shx * m.shy + sy * m.sy;
    ty = tx * m.shy + ty * m.sy + m.ty;
    sx = t0;
    shx = t2;
    tx = t4;
    return this;
  }

  /// Premultiply: this = m * this
  TransAffine premultiply(TransAffine m) {
    final t = TransAffine.from(m);
    return copyFrom(t.multiply(this));
  }

  /// Multiply by inverse of another matrix
  TransAffine multiplyInv(TransAffine m) {
    final t = TransAffine.from(m);
    t.invert();
    return multiply(t);
  }

  /// Premultiply by inverse
  TransAffine premultiplyInv(TransAffine m) {
    final t = TransAffine.from(m);
    t.invert();
    return copyFrom(t.multiply(this));
  }

  // -------------------------------------------------------------------------
  // Inversion
  // -------------------------------------------------------------------------

  /// Invert the matrix
  TransAffine invert() {
    final d = determinantReciprocal;
    final t0 = sy * d;
    sy = sx * d;
    shy = -shy * d;
    shx = -shx * d;
    final t4 = -tx * t0 - ty * shx;
    ty = -tx * shy - ty * sy;
    sx = t0;
    tx = t4;
    return this;
  }

  /// Return inverted copy
  TransAffine inverted() {
    return TransAffine.from(this)..invert();
  }

  // -------------------------------------------------------------------------
  // Mirroring
  // -------------------------------------------------------------------------

  /// Mirror around X axis
  TransAffine flipX() {
    sx = -sx;
    shy = -shy;
    tx = -tx;
    return this;
  }

  /// Mirror around Y axis
  TransAffine flipY() {
    shx = -shx;
    sy = -sy;
    ty = -ty;
    return this;
  }

  // -------------------------------------------------------------------------
  // Store/Load
  // -------------------------------------------------------------------------

  /// Store matrix to array [sx, shy, shx, sy, tx, ty]
  List<double> toArray() {
    return [sx, shy, shx, sy, tx, ty];
  }

  /// Load matrix from array
  TransAffine loadFrom(List<double> m) {
    sx = m[0];
    shy = m[1];
    shx = m[2];
    sy = m[3];
    tx = m[4];
    ty = m[5];
    return this;
  }

  /// Copy from another matrix
  TransAffine copyFrom(TransAffine m) {
    sx = m.sx;
    shy = m.shy;
    shx = m.shx;
    sy = m.sy;
    tx = m.tx;
    ty = m.ty;
    return this;
  }

  // -------------------------------------------------------------------------
  // Transformation operations
  // -------------------------------------------------------------------------

  /// Transform point (x, y)
  ({double x, double y}) transform(double x, double y) {
    return (
      x: x * sx + y * shx + tx,
      y: x * shy + y * sy + ty,
    );
  }

  /// Transform point in place
  void transformXY(List<double> xy) {
    final x = xy[0];
    final y = xy[1];
    xy[0] = x * sx + y * shx + tx;
    xy[1] = x * shy + y * sy + ty;
  }

  /// Transform 2x2 only (no translation)
  ({double x, double y}) transform2x2(double x, double y) {
    return (
      x: x * sx + y * shx,
      y: x * shy + y * sy,
    );
  }

  /// Inverse transformation
  ({double x, double y}) inverseTransform(double x, double y) {
    final d = determinantReciprocal;
    final a = (x - tx) * d;
    final b = (y - ty) * d;
    return (
      x: a * sy - b * shx,
      y: b * sx - a * shy,
    );
  }

  // -------------------------------------------------------------------------
  // Matrix properties
  // -------------------------------------------------------------------------

  /// Calculate determinant
  double get determinant => sx * sy - shy * shx;

  /// Calculate reciprocal of determinant
  double get determinantReciprocal => 1.0 / (sx * sy - shy * shx);

  /// Get average scale factor
  double get averageScale {
    final x = 0.707106781 * sx + 0.707106781 * shx;
    final y = 0.707106781 * shy + 0.707106781 * sy;
    return math.sqrt(x * x + y * y);
  }

  /// Check if matrix is valid (not degenerate)
  bool isValid([double epsilon = affineEpsilon]) {
    return determinant.abs() > epsilon;
  }

  /// Check if this is identity matrix
  bool isIdentity([double epsilon = affineEpsilon]) {
    return (sx - 1.0).abs() < epsilon &&
           shy.abs() < epsilon &&
           shx.abs() < epsilon &&
           (sy - 1.0).abs() < epsilon &&
           tx.abs() < epsilon &&
           ty.abs() < epsilon;
  }

  /// Check equality with another matrix
  bool isEqual(TransAffine m, [double epsilon = affineEpsilon]) {
    return (sx - m.sx).abs() < epsilon &&
           (shy - m.shy).abs() < epsilon &&
           (shx - m.shx).abs() < epsilon &&
           (sy - m.sy).abs() < epsilon &&
           (tx - m.tx).abs() < epsilon &&
           (ty - m.ty).abs() < epsilon;
  }

  /// Get rotation angle
  double get rotation => math.atan2(shy, sx);

  /// Get translation
  ({double dx, double dy}) get translation => (dx: tx, dy: ty);

  /// Get scaling factors
  ({double x, double y}) get scaling {
    double x1 = 0.0, y1 = 0.0;
    final p = transform(0, 0);
    final q = transform(1, 1);
    return (x: q.x - p.x, y: q.y - p.y);
  }

  /// Get absolute scaling factors
  ({double x, double y}) get scalingAbs {
    return (
      x: math.sqrt(sx * sx + shx * shx),
      y: math.sqrt(shy * shy + sy * sy),
    );
  }

  // -------------------------------------------------------------------------
  // Operators
  // -------------------------------------------------------------------------

  /// Multiply matrices
  TransAffine operator *(TransAffine m) {
    return TransAffine.from(this)..multiply(m);
  }

  /// Divide by matrix (multiply by inverse)
  TransAffine operator /(TransAffine m) {
    return TransAffine.from(this)..multiplyInv(m);
  }

  @override
  bool operator ==(Object other) {
    return other is TransAffine && isEqual(other);
  }

  @override
  int get hashCode => Object.hash(sx, shy, shx, sy, tx, ty);

  @override
  String toString() {
    return 'TransAffine(sx: $sx, shy: $shy, shx: $shx, sy: $sy, tx: $tx, ty: $ty)';
  }
}

// ============================================================================
// Specialized Transformations
// ============================================================================

/// Rotation transformation
class TransAffineRotation extends TransAffine {
  TransAffineRotation(double angle)
    : super.values(
        math.cos(angle), math.sin(angle),
        -math.sin(angle), math.cos(angle),
        0.0, 0.0,
      );
}

/// Scaling transformation
class TransAffineScaling extends TransAffine {
  TransAffineScaling(double x, double y)
    : super.values(x, 0.0, 0.0, y, 0.0, 0.0);

  TransAffineScaling.uniform(double s)
    : super.values(s, 0.0, 0.0, s, 0.0, 0.0);
}

/// Translation transformation
class TransAffineTranslation extends TransAffine {
  TransAffineTranslation(double x, double y)
    : super.values(1.0, 0.0, 0.0, 1.0, x, y);
}

/// Skewing (shear) transformation
class TransAffineSkewing extends TransAffine {
  TransAffineSkewing(double x, double y)
    : super.values(1.0, math.tan(y), math.tan(x), 1.0, 0.0, 0.0);
}

/// Line segment transformation
/// Rotate, Scale and Translate, associating 0...dist with line segment x1,y1,x2,y2
class TransAffineLineSegment extends TransAffine {
  TransAffineLineSegment(
    double x1, double y1,
    double x2, double y2,
    double dist,
  ) : super() {
    final dx = x2 - x1;
    final dy = y2 - y1;
    if (dist > 0.0) {
      multiply(TransAffineScaling.uniform(math.sqrt(dx * dx + dy * dy) / dist));
    }
    multiply(TransAffineRotation(math.atan2(dy, dx)));
    multiply(TransAffineTranslation(x1, y1));
  }
}

/// Reflection transformation across line through origin
class TransAffineReflectionUnit extends TransAffine {
  TransAffineReflectionUnit(double ux, double uy)
    : super.values(
        2.0 * ux * ux - 1.0,
        2.0 * ux * uy,
        2.0 * ux * uy,
        2.0 * uy * uy - 1.0,
        0.0, 0.0,
      );
}

/// Reflection transformation at angle or through vector
class TransAffineReflection extends TransAffineReflectionUnit {
  /// Reflect at angle
  TransAffineReflection.angle(double angle)
    : super(math.cos(angle), math.sin(angle));

  /// Reflect through vector
  TransAffineReflection.vector(double x, double y)
    : super(
        x / math.sqrt(x * x + y * y),
        y / math.sqrt(x * x + y * y),
      );
}
