// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Copyright (C) 2005 Tony Juricic (tonygeek@yahoo.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG Curves - Bezier curve approximation.
library;

import 'dart:math' as math;
import 'agg_basics.dart';
import 'agg_math.dart';

// ============================================================================
// Constants
// ============================================================================

const double _curveDistanceEpsilon = 1e-30;
const double _curveCollinearityEpsilon = 1e-30;
const double _curveAngleToleranceEpsilon = 0.01;
const int _curveRecursionLimit = 32;

// ============================================================================
// Curve approximation method
// ============================================================================

/// Curve approximation method
enum CurveApproximationMethod {
  /// Incremental method - fixed number of steps
  increment,
  /// Recursive division - adaptive subdivision
  division,
}

// ============================================================================
// Curve3 - Quadratic Bezier
// ============================================================================

/// Quadratic Bezier curve using incremental method.
/// 
/// Uses forward differencing to generate points.
class Curve3Inc {
  int _numSteps = 0;
  int _step = 0;
  double _scale = 1.0;
  double _startX = 0;
  double _startY = 0;
  double _endX = 0;
  double _endY = 0;
  double _fx = 0;
  double _fy = 0;
  double _dfx = 0;
  double _dfy = 0;
  double _ddfx = 0;
  double _ddfy = 0;
  double _savedFx = 0;
  double _savedFy = 0;
  double _savedDfx = 0;
  double _savedDfy = 0;

  Curve3Inc();

  /// Create with control points
  Curve3Inc.points(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
  ) {
    init(x1, y1, x2, y2, x3, y3);
  }

  /// Reset the curve
  void reset() {
    _numSteps = 0;
    _step = -1;
  }

  /// Initialize with control points
  void init(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
  ) {
    _startX = x1;
    _startY = y1;
    _endX = x3;
    _endY = y3;

    final dx1 = x2 - x1;
    final dy1 = y2 - y1;
    final dx2 = x3 - x2;
    final dy2 = y3 - y2;

    final len = math.sqrt(dx1 * dx1 + dy1 * dy1) + math.sqrt(dx2 * dx2 + dy2 * dy2);

    _numSteps = uround(len * 0.25 * _scale);
    if (_numSteps < 4) _numSteps = 4;

    final subdivideStep = 1.0 / _numSteps;
    final subdivideStep2 = subdivideStep * subdivideStep;

    final tmpx = (x1 - x2 * 2.0 + x3) * subdivideStep2;
    final tmpy = (y1 - y2 * 2.0 + y3) * subdivideStep2;

    _savedFx = _fx = x1;
    _savedFy = _fy = y1;

    _savedDfx = _dfx = tmpx + (x2 - x1) * (2.0 * subdivideStep);
    _savedDfy = _dfy = tmpy + (y2 - y1) * (2.0 * subdivideStep);

    _ddfx = tmpx * 2.0;
    _ddfy = tmpy * 2.0;

    _step = _numSteps;
  }

  /// Set approximation scale
  set approximationScale(double s) => _scale = s;
  
  /// Get approximation scale
  double get approximationScale => _scale;

  /// Rewind to beginning
  void rewind([int pathId = 0]) {
    if (_numSteps == 0) {
      _step = -1;
      return;
    }
    _step = _numSteps;
    _fx = _savedFx;
    _fy = _savedFy;
    _dfx = _savedDfx;
    _dfy = _savedDfy;
  }

  /// Get next vertex
  Vertex vertex() {
    if (_step < 0) return Vertex(0, 0, PathCmd.stop);
    
    if (_step == _numSteps) {
      _step--;
      return Vertex(_startX, _startY, PathCmd.moveTo);
    }
    
    if (_step == 0) {
      _step--;
      return Vertex(_endX, _endY, PathCmd.lineTo);
    }
    
    _fx += _dfx;
    _fy += _dfy;
    _dfx += _ddfx;
    _dfy += _ddfy;
    _step--;
    return Vertex(_fx, _fy, PathCmd.lineTo);
  }
}

/// Quadratic Bezier curve using recursive division.
/// 
/// Uses adaptive subdivision based on flatness criteria.
class Curve3Div {
  double _approximationScale = 1.0;
  double _distanceToleranceSquare = 0;
  double _angleTolerance = 0.0;
  int _count = 0;
  List<PointD> _points = [];

  Curve3Div();

  /// Create with control points
  Curve3Div.points(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
  ) {
    init(x1, y1, x2, y2, x3, y3);
  }

  /// Reset the curve
  void reset() {
    _points.clear();
    _count = 0;
  }

  /// Initialize with control points
  void init(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
  ) {
    _points.clear();
    _distanceToleranceSquare = 0.5 / _approximationScale;
    _distanceToleranceSquare *= _distanceToleranceSquare;
    _bezier(x1, y1, x2, y2, x3, y3);
    _count = 0;
  }

  /// Set approximation scale
  set approximationScale(double s) => _approximationScale = s;
  
  /// Get approximation scale
  double get approximationScale => _approximationScale;

  /// Set angle tolerance
  set angleTolerance(double a) => _angleTolerance = a;
  
  /// Get angle tolerance
  double get angleTolerance => _angleTolerance;

  /// Rewind to beginning
  void rewind([int pathId = 0]) {
    _count = 0;
  }

  /// Get next vertex
  Vertex vertex() {
    if (_count >= _points.length) return Vertex(0, 0, PathCmd.stop);
    
    final p = _points[_count++];
    return Vertex(p.x, p.y, _count == 1 ? PathCmd.moveTo : PathCmd.lineTo);
  }

  void _bezier(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
  ) {
    _points.add(PointD(x1, y1));
    _recursiveBezier(x1, y1, x2, y2, x3, y3, 0);
    _points.add(PointD(x3, y3));
  }

  void _recursiveBezier(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    int level,
  ) {
    if (level > _curveRecursionLimit) return;

    // Calculate all the mid-points of the line segments
    final x12 = (x1 + x2) / 2;
    final y12 = (y1 + y2) / 2;
    final x23 = (x2 + x3) / 2;
    final y23 = (y2 + y3) / 2;
    final x123 = (x12 + x23) / 2;
    final y123 = (y12 + y23) / 2;

    final dx = x3 - x1;
    final dy = y3 - y1;
    var d = ((x2 - x3) * dy - (y2 - y3) * dx).abs();

    if (d > _curveCollinearityEpsilon) {
      // Regular case
      if (d * d <= _distanceToleranceSquare * (dx * dx + dy * dy)) {
        // If the curvature doesn't exceed the distance_tolerance value
        // we tend to finish subdivisions.
        if (_angleTolerance < _curveAngleToleranceEpsilon) {
          _points.add(PointD(x123, y123));
          return;
        }

        // Angle & Cusp Condition
        var da = (math.atan2(y3 - y2, x3 - x2) - math.atan2(y2 - y1, x2 - x1)).abs();
        if (da >= math.pi) da = 2 * math.pi - da;

        if (da < _angleTolerance) {
          _points.add(PointD(x123, y123));
          return;
        }
      }
    } else {
      // Collinear case
      var da = dx * dx + dy * dy;
      if (da == 0) {
        d = calcSqDistance(x1, y1, x2, y2);
      } else {
        d = ((x2 - x1) * dx + (y2 - y1) * dy) / da;
        if (d > 0 && d < 1) {
          // Simple collinear case, 1---2---3
          // We can leave just two endpoints
          return;
        }
        if (d <= 0) {
          d = calcSqDistance(x2, y2, x1, y1);
        } else if (d >= 1) {
          d = calcSqDistance(x2, y2, x3, y3);
        } else {
          d = calcSqDistance(x2, y2, x1 + d * dx, y1 + d * dy);
        }
      }
      if (d < _distanceToleranceSquare) {
        _points.add(PointD(x2, y2));
        return;
      }
    }

    // Continue subdivision
    _recursiveBezier(x1, y1, x12, y12, x123, y123, level + 1);
    _recursiveBezier(x123, y123, x23, y23, x3, y3, level + 1);
  }
}

// ============================================================================
// Curve4 - Cubic Bezier
// ============================================================================

/// Cubic Bezier curve control points.
class Curve4Points {
  final List<double> cp = List.filled(8, 0);

  Curve4Points();

  /// Create with control points
  Curve4Points.points(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    init(x1, y1, x2, y2, x3, y3, x4, y4);
  }

  /// Initialize with control points
  void init(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    cp[0] = x1; cp[1] = y1;
    cp[2] = x2; cp[3] = y2;
    cp[4] = x3; cp[5] = y3;
    cp[6] = x4; cp[7] = y4;
  }

  double operator [](int i) => cp[i];
  void operator []=(int i, double v) => cp[i] = v;
}

/// Cubic Bezier curve using incremental method.
/// 
/// Uses forward differencing to generate points.
class Curve4Inc {
  int _numSteps = 0;
  int _step = 0;
  double _scale = 1.0;
  double _startX = 0;
  double _startY = 0;
  double _endX = 0;
  double _endY = 0;
  double _fx = 0;
  double _fy = 0;
  double _dfx = 0;
  double _dfy = 0;
  double _ddfx = 0;
  double _ddfy = 0;
  double _dddfx = 0;
  double _dddfy = 0;
  double _savedFx = 0;
  double _savedFy = 0;
  double _savedDfx = 0;
  double _savedDfy = 0;
  double _savedDdfx = 0;
  double _savedDdfy = 0;

  Curve4Inc();

  /// Create with control points
  Curve4Inc.points(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    init(x1, y1, x2, y2, x3, y3, x4, y4);
  }

  /// Create from Curve4Points
  Curve4Inc.fromPoints(Curve4Points cp) {
    init(cp[0], cp[1], cp[2], cp[3], cp[4], cp[5], cp[6], cp[7]);
  }

  /// Reset the curve
  void reset() {
    _numSteps = 0;
    _step = -1;
  }

  /// Initialize with control points
  void init(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    _startX = x1;
    _startY = y1;
    _endX = x4;
    _endY = y4;

    final dx1 = x2 - x1;
    final dy1 = y2 - y1;
    final dx2 = x3 - x2;
    final dy2 = y3 - y2;
    final dx3 = x4 - x3;
    final dy3 = y4 - y3;

    final len = (math.sqrt(dx1 * dx1 + dy1 * dy1) +
                 math.sqrt(dx2 * dx2 + dy2 * dy2) +
                 math.sqrt(dx3 * dx3 + dy3 * dy3)) * 0.25 * _scale;

    _numSteps = uround(len);
    if (_numSteps < 4) _numSteps = 4;

    final subdivideStep = 1.0 / _numSteps;
    final subdivideStep2 = subdivideStep * subdivideStep;
    final subdivideStep3 = subdivideStep * subdivideStep * subdivideStep;

    final pre1 = 3.0 * subdivideStep;
    final pre2 = 3.0 * subdivideStep2;
    final pre4 = 6.0 * subdivideStep2;
    final pre5 = 6.0 * subdivideStep3;

    final tmp1x = x1 - x2 * 2.0 + x3;
    final tmp1y = y1 - y2 * 2.0 + y3;

    final tmp2x = (x2 - x3) * 3.0 - x1 + x4;
    final tmp2y = (y2 - y3) * 3.0 - y1 + y4;

    _savedFx = _fx = x1;
    _savedFy = _fy = y1;

    _savedDfx = _dfx = (x2 - x1) * pre1 + tmp1x * pre2 + tmp2x * subdivideStep3;
    _savedDfy = _dfy = (y2 - y1) * pre1 + tmp1y * pre2 + tmp2y * subdivideStep3;

    _savedDdfx = _ddfx = tmp1x * pre4 + tmp2x * pre5;
    _savedDdfy = _ddfy = tmp1y * pre4 + tmp2y * pre5;

    _dddfx = tmp2x * pre5;
    _dddfy = tmp2y * pre5;

    _step = _numSteps;
  }

  /// Initialize from Curve4Points
  void initFromPoints(Curve4Points cp) {
    init(cp[0], cp[1], cp[2], cp[3], cp[4], cp[5], cp[6], cp[7]);
  }

  /// Set approximation scale
  set approximationScale(double s) => _scale = s;
  
  /// Get approximation scale
  double get approximationScale => _scale;

  /// Rewind to beginning
  void rewind([int pathId = 0]) {
    if (_numSteps == 0) {
      _step = -1;
      return;
    }
    _step = _numSteps;
    _fx = _savedFx;
    _fy = _savedFy;
    _dfx = _savedDfx;
    _dfy = _savedDfy;
    _ddfx = _savedDdfx;
    _ddfy = _savedDdfy;
  }

  /// Get next vertex
  Vertex vertex() {
    if (_step < 0) return Vertex(0, 0, PathCmd.stop);

    if (_step == _numSteps) {
      _step--;
      return Vertex(_startX, _startY, PathCmd.moveTo);
    }

    if (_step == 0) {
      _step--;
      return Vertex(_endX, _endY, PathCmd.lineTo);
    }

    _fx += _dfx;
    _fy += _dfy;
    _dfx += _ddfx;
    _dfy += _ddfy;
    _ddfx += _dddfx;
    _ddfy += _dddfy;

    _step--;
    return Vertex(_fx, _fy, PathCmd.lineTo);
  }
}

/// Cubic Bezier curve using recursive division.
/// 
/// Uses adaptive subdivision based on flatness and angle criteria.
class Curve4Div {
  double _approximationScale = 1.0;
  double _distanceToleranceSquare = 0;
  double _angleTolerance = 0.0;
  double _cuspLimit = 0.0;
  int _count = 0;
  List<PointD> _points = [];

  Curve4Div();

  /// Create with control points
  Curve4Div.points(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    init(x1, y1, x2, y2, x3, y3, x4, y4);
  }

  /// Create from Curve4Points
  Curve4Div.fromPoints(Curve4Points cp) {
    init(cp[0], cp[1], cp[2], cp[3], cp[4], cp[5], cp[6], cp[7]);
  }

  /// Reset the curve
  void reset() {
    _points.clear();
    _count = 0;
  }

  /// Initialize with control points
  void init(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    _points.clear();
    _distanceToleranceSquare = 0.5 / _approximationScale;
    _distanceToleranceSquare *= _distanceToleranceSquare;
    _bezier(x1, y1, x2, y2, x3, y3, x4, y4);
    _count = 0;
  }

  /// Initialize from Curve4Points
  void initFromPoints(Curve4Points cp) {
    init(cp[0], cp[1], cp[2], cp[3], cp[4], cp[5], cp[6], cp[7]);
  }

  /// Set approximation scale
  set approximationScale(double s) => _approximationScale = s;
  
  /// Get approximation scale
  double get approximationScale => _approximationScale;

  /// Set angle tolerance
  set angleTolerance(double a) => _angleTolerance = a;
  
  /// Get angle tolerance
  double get angleTolerance => _angleTolerance;

  /// Set cusp limit
  set cuspLimit(double v) {
    _cuspLimit = (v == 0.0) ? 0.0 : math.pi - v;
  }

  /// Get cusp limit
  double get cuspLimit => (_cuspLimit == 0.0) ? 0.0 : math.pi - _cuspLimit;

  /// Rewind to beginning
  void rewind([int pathId = 0]) {
    _count = 0;
  }

  /// Get next vertex
  Vertex vertex() {
    if (_count >= _points.length) return Vertex(0, 0, PathCmd.stop);
    
    final p = _points[_count++];
    return Vertex(p.x, p.y, _count == 1 ? PathCmd.moveTo : PathCmd.lineTo);
  }

  void _bezier(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    _points.add(PointD(x1, y1));
    _recursiveBezier(x1, y1, x2, y2, x3, y3, x4, y4, 0);
    _points.add(PointD(x4, y4));
  }

  void _recursiveBezier(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
    int level,
  ) {
    if (level > _curveRecursionLimit) return;

    // Calculate all the mid-points of the line segments
    final x12 = (x1 + x2) / 2;
    final y12 = (y1 + y2) / 2;
    final x23 = (x2 + x3) / 2;
    final y23 = (y2 + y3) / 2;
    final x34 = (x3 + x4) / 2;
    final y34 = (y3 + y4) / 2;
    final x123 = (x12 + x23) / 2;
    final y123 = (y12 + y23) / 2;
    final x234 = (x23 + x34) / 2;
    final y234 = (y23 + y34) / 2;
    final x1234 = (x123 + x234) / 2;
    final y1234 = (y123 + y234) / 2;

    // Try to approximate the full cubic curve by a single straight line
    final dx = x4 - x1;
    final dy = y4 - y1;

    var d2 = ((x2 - x4) * dy - (y2 - y4) * dx).abs();
    var d3 = ((x3 - x4) * dy - (y3 - y4) * dx).abs();
    double da1, da2, k;

    final caseIdx = ((d2 > _curveCollinearityEpsilon ? 1 : 0) << 1) +
                    (d3 > _curveCollinearityEpsilon ? 1 : 0);

    switch (caseIdx) {
      case 0:
        // All collinear OR p1==p4
        k = dx * dx + dy * dy;
        if (k == 0) {
          d2 = calcSqDistance(x1, y1, x2, y2);
          d3 = calcSqDistance(x4, y4, x3, y3);
        } else {
          k = 1 / k;
          da1 = x2 - x1;
          da2 = y2 - y1;
          d2 = k * (da1 * dx + da2 * dy);
          da1 = x3 - x1;
          da2 = y3 - y1;
          d3 = k * (da1 * dx + da2 * dy);
          if (d2 > 0 && d2 < 1 && d3 > 0 && d3 < 1) {
            // Simple collinear case, 1---2---3---4
            // We can leave just two endpoints
            return;
          }
          if (d2 <= 0) {
            d2 = calcSqDistance(x2, y2, x1, y1);
          } else if (d2 >= 1) {
            d2 = calcSqDistance(x2, y2, x4, y4);
          } else {
            d2 = calcSqDistance(x2, y2, x1 + d2 * dx, y1 + d2 * dy);
          }

          if (d3 <= 0) {
            d3 = calcSqDistance(x3, y3, x1, y1);
          } else if (d3 >= 1) {
            d3 = calcSqDistance(x3, y3, x4, y4);
          } else {
            d3 = calcSqDistance(x3, y3, x1 + d3 * dx, y1 + d3 * dy);
          }
        }
        if (d2 > d3) {
          if (d2 < _distanceToleranceSquare) {
            _points.add(PointD(x2, y2));
            return;
          }
        } else {
          if (d3 < _distanceToleranceSquare) {
            _points.add(PointD(x3, y3));
            return;
          }
        }
        break;

      case 1:
        // p1,p2,p4 are collinear, p3 is significant
        if (d3 * d3 <= _distanceToleranceSquare * (dx * dx + dy * dy)) {
          if (_angleTolerance < _curveAngleToleranceEpsilon) {
            _points.add(PointD(x23, y23));
            return;
          }

          // Angle Condition
          da1 = (math.atan2(y4 - y3, x4 - x3) - math.atan2(y3 - y2, x3 - x2)).abs();
          if (da1 >= math.pi) da1 = 2 * math.pi - da1;

          if (da1 < _angleTolerance) {
            _points.add(PointD(x2, y2));
            _points.add(PointD(x3, y3));
            return;
          }

          if (_cuspLimit != 0.0) {
            if (da1 > _cuspLimit) {
              _points.add(PointD(x3, y3));
              return;
            }
          }
        }
        break;

      case 2:
        // p1,p3,p4 are collinear, p2 is significant
        if (d2 * d2 <= _distanceToleranceSquare * (dx * dx + dy * dy)) {
          if (_angleTolerance < _curveAngleToleranceEpsilon) {
            _points.add(PointD(x23, y23));
            return;
          }

          // Angle Condition
          da1 = (math.atan2(y3 - y2, x3 - x2) - math.atan2(y2 - y1, x2 - x1)).abs();
          if (da1 >= math.pi) da1 = 2 * math.pi - da1;

          if (da1 < _angleTolerance) {
            _points.add(PointD(x2, y2));
            _points.add(PointD(x3, y3));
            return;
          }

          if (_cuspLimit != 0.0) {
            if (da1 > _cuspLimit) {
              _points.add(PointD(x2, y2));
              return;
            }
          }
        }
        break;

      case 3:
        // Regular case
        if ((d2 + d3) * (d2 + d3) <= _distanceToleranceSquare * (dx * dx + dy * dy)) {
          // If the curvature doesn't exceed the distance_tolerance value
          // we tend to finish subdivisions.
          if (_angleTolerance < _curveAngleToleranceEpsilon) {
            _points.add(PointD(x23, y23));
            return;
          }

          // Angle & Cusp Condition
          k = math.atan2(y3 - y2, x3 - x2);
          da1 = (k - math.atan2(y2 - y1, x2 - x1)).abs();
          da2 = (math.atan2(y4 - y3, x4 - x3) - k).abs();
          if (da1 >= math.pi) da1 = 2 * math.pi - da1;
          if (da2 >= math.pi) da2 = 2 * math.pi - da2;

          if (da1 + da2 < _angleTolerance) {
            // Finally we can stop the recursion
            _points.add(PointD(x23, y23));
            return;
          }

          if (_cuspLimit != 0.0) {
            if (da1 > _cuspLimit) {
              _points.add(PointD(x2, y2));
              return;
            }

            if (da2 > _cuspLimit) {
              _points.add(PointD(x3, y3));
              return;
            }
          }
        }
        break;
    }

    // Continue subdivision
    _recursiveBezier(x1, y1, x12, y12, x123, y123, x1234, y1234, level + 1);
    _recursiveBezier(x1234, y1234, x234, y234, x34, y34, x4, y4, level + 1);
  }
}

// ============================================================================
// Curve3 - Combined quadratic bezier
// ============================================================================

/// Quadratic Bezier curve with selectable approximation method.
class Curve3 {
  final Curve3Inc _curveInc = Curve3Inc();
  final Curve3Div _curveDiv = Curve3Div();
  CurveApproximationMethod _approximationMethod = CurveApproximationMethod.division;

  Curve3();

  /// Create with control points
  Curve3.points(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
  ) {
    init(x1, y1, x2, y2, x3, y3);
  }

  /// Reset the curve
  void reset() {
    _curveInc.reset();
    _curveDiv.reset();
  }

  /// Initialize with control points
  void init(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
  ) {
    if (_approximationMethod == CurveApproximationMethod.increment) {
      _curveInc.init(x1, y1, x2, y2, x3, y3);
    } else {
      _curveDiv.init(x1, y1, x2, y2, x3, y3);
    }
  }

  /// Set approximation method
  set approximationMethod(CurveApproximationMethod v) => _approximationMethod = v;
  
  /// Get approximation method
  CurveApproximationMethod get approximationMethod => _approximationMethod;

  /// Set approximation scale
  set approximationScale(double s) {
    _curveInc.approximationScale = s;
    _curveDiv.approximationScale = s;
  }

  /// Get approximation scale
  double get approximationScale => _curveInc.approximationScale;

  /// Set angle tolerance
  set angleTolerance(double a) => _curveDiv.angleTolerance = a;
  
  /// Get angle tolerance
  double get angleTolerance => _curveDiv.angleTolerance;

  /// Rewind to beginning
  void rewind([int pathId = 0]) {
    if (_approximationMethod == CurveApproximationMethod.increment) {
      _curveInc.rewind(pathId);
    } else {
      _curveDiv.rewind(pathId);
    }
  }

  /// Get next vertex
  Vertex vertex() {
    if (_approximationMethod == CurveApproximationMethod.increment) {
      return _curveInc.vertex();
    }
    return _curveDiv.vertex();
  }
}

// ============================================================================
// Curve4 - Combined cubic bezier
// ============================================================================

/// Cubic Bezier curve with selectable approximation method.
class Curve4 {
  final Curve4Inc _curveInc = Curve4Inc();
  final Curve4Div _curveDiv = Curve4Div();
  CurveApproximationMethod _approximationMethod = CurveApproximationMethod.division;

  Curve4();

  /// Create with control points
  Curve4.points(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    init(x1, y1, x2, y2, x3, y3, x4, y4);
  }

  /// Create from Curve4Points
  Curve4.fromPoints(Curve4Points cp) {
    init(cp[0], cp[1], cp[2], cp[3], cp[4], cp[5], cp[6], cp[7]);
  }

  /// Reset the curve
  void reset() {
    _curveInc.reset();
    _curveDiv.reset();
  }

  /// Initialize with control points
  void init(
    double x1, double y1,
    double x2, double y2,
    double x3, double y3,
    double x4, double y4,
  ) {
    if (_approximationMethod == CurveApproximationMethod.increment) {
      _curveInc.init(x1, y1, x2, y2, x3, y3, x4, y4);
    } else {
      _curveDiv.init(x1, y1, x2, y2, x3, y3, x4, y4);
    }
  }

  /// Initialize from Curve4Points
  void initFromPoints(Curve4Points cp) {
    init(cp[0], cp[1], cp[2], cp[3], cp[4], cp[5], cp[6], cp[7]);
  }

  /// Set approximation method
  set approximationMethod(CurveApproximationMethod v) => _approximationMethod = v;
  
  /// Get approximation method
  CurveApproximationMethod get approximationMethod => _approximationMethod;

  /// Set approximation scale
  set approximationScale(double s) {
    _curveInc.approximationScale = s;
    _curveDiv.approximationScale = s;
  }

  /// Get approximation scale
  double get approximationScale => _curveInc.approximationScale;

  /// Set angle tolerance
  set angleTolerance(double v) => _curveDiv.angleTolerance = v;
  
  /// Get angle tolerance
  double get angleTolerance => _curveDiv.angleTolerance;

  /// Set cusp limit
  set cuspLimit(double v) => _curveDiv.cuspLimit = v;
  
  /// Get cusp limit
  double get cuspLimit => _curveDiv.cuspLimit;

  /// Rewind to beginning
  void rewind([int pathId = 0]) {
    if (_approximationMethod == CurveApproximationMethod.increment) {
      _curveInc.rewind(pathId);
    } else {
      _curveDiv.rewind(pathId);
    }
  }

  /// Get next vertex
  Vertex vertex() {
    if (_approximationMethod == CurveApproximationMethod.increment) {
      return _curveInc.vertex();
    }
    return _curveDiv.vertex();
  }
}

// ============================================================================
// Curve conversion utilities
// ============================================================================

/// Convert Catmull-Rom spline to Bezier curve
Curve4Points catromToBezier(
  double x1, double y1,
  double x2, double y2,
  double x3, double y3,
  double x4, double y4,
) {
  // Trans. matrix Catmull-Rom to Bezier
  //
  //  0       1       0       0
  //  -1/6    1       1/6     0
  //  0       1/6     1       -1/6
  //  0       0       1       0
  //
  return Curve4Points.points(
    x2,
    y2,
    (-x1 + 6 * x2 + x3) / 6,
    (-y1 + 6 * y2 + y3) / 6,
    (x2 + 6 * x3 - x4) / 6,
    (y2 + 6 * y3 - y4) / 6,
    x3,
    y3,
  );
}

/// Convert uniform B-spline to Bezier curve
Curve4Points ubsplineToBezier(
  double x1, double y1,
  double x2, double y2,
  double x3, double y3,
  double x4, double y4,
) {
  // Trans. matrix Uniform BSpline to Bezier
  //
  //  1/6     4/6     1/6     0
  //  0       4/6     2/6     0
  //  0       2/6     4/6     0
  //  0       1/6     4/6     1/6
  //
  return Curve4Points.points(
    (x1 + 4 * x2 + x3) / 6,
    (y1 + 4 * y2 + y3) / 6,
    (4 * x2 + 2 * x3) / 6,
    (4 * y2 + 2 * y3) / 6,
    (2 * x2 + 4 * x3) / 6,
    (2 * y2 + 4 * y3) / 6,
    (x2 + 4 * x3 + x4) / 6,
    (y2 + 4 * y3 + y4) / 6,
  );
}

/// Convert Hermite spline to Bezier curve
Curve4Points hermiteToBezier(
  double x1, double y1,
  double x2, double y2,
  double x3, double y3,
  double x4, double y4,
) {
  // Trans. matrix Hermite to Bezier
  //
  //  1       0       0       0
  //  1       0       1/3     0
  //  0       1       0       -1/3
  //  0       1       0       0
  //
  return Curve4Points.points(
    x1,
    y1,
    (3 * x1 + x3) / 3,
    (3 * y1 + y3) / 3,
    (3 * x2 - x4) / 3,
    (3 * y2 - y4) / 3,
    x2,
    y2,
  );
}
