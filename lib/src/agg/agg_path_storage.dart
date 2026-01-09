// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG Path Storage - stores vertices with path commands.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'agg_basics.dart';
import 'agg_math.dart';
import 'agg_trans_affine.dart';

// ============================================================================
// PathVertex - A vertex with coordinates and command
// ============================================================================

/// A single path vertex with coordinates and command
class PathVertex {
  double x;
  double y;
  int cmd;

  PathVertex([this.x = 0.0, this.y = 0.0, this.cmd = PathCmd.stop]);

  PathVertex.from(PathVertex other)
    : x = other.x, y = other.y, cmd = other.cmd;

  @override
  String toString() => 'PathVertex($x, $y, cmd: $cmd)';
}

// ============================================================================
// PathStorage - Main path storage class
// ============================================================================

/// Storage for vector path data with vertices and commands.
///
/// A path consists of a number of contours separated with "move_to" commands.
/// The path storage can keep and maintain more than one path.
/// To navigate to the beginning of a particular path, use rewind(pathId).
class PathStorage {
  final List<double> _coords = [];
  final List<int> _cmds = [];
  int _iterator = 0;

  // Cached last control point for smooth curves
  double? _lastCtrlX;
  double? _lastCtrlY;

  PathStorage();

  /// Create a copy of another path storage
  PathStorage.from(PathStorage other) {
    _coords.addAll(other._coords);
    _cmds.addAll(other._cmds);
  }

  /// Remove all vertices
  void removeAll() {
    _coords.clear();
    _cmds.clear();
    _iterator = 0;
    _lastCtrlX = null;
    _lastCtrlY = null;
  }

  /// Free all memory
  void freeAll() => removeAll();

  // ===========================================================================
  // Path construction methods
  // ===========================================================================

  /// Start a new path, returns the path ID
  int startNewPath() {
    if (_cmds.isNotEmpty && !isStop(_cmds.last)) {
      _cmds.add(PathCmd.stop);
      _coords.addAll([0.0, 0.0]);
    }
    return totalVertices;
  }

  /// Move to absolute position
  void moveTo(double x, double y) {
    _addVertex(x, y, PathCmd.moveTo);
  }

  /// Move to relative position
  void moveRel(double dx, double dy) {
    final (x, y) = _relToAbs(dx, dy);
    moveTo(x, y);
  }

  /// Line to absolute position
  void lineTo(double x, double y) {
    _addVertex(x, y, PathCmd.lineTo);
  }

  /// Line to relative position
  void lineRel(double dx, double dy) {
    final (x, y) = _relToAbs(dx, dy);
    lineTo(x, y);
  }

  /// Horizontal line to absolute X
  void hlineTo(double x) {
    lineTo(x, lastY);
  }

  /// Horizontal line relative
  void hlineRel(double dx) {
    lineRel(dx, 0);
  }

  /// Vertical line to absolute Y
  void vlineTo(double y) {
    lineTo(lastX, y);
  }

  /// Vertical line relative
  void vlineRel(double dy) {
    lineRel(0, dy);
  }

  /// Add quadratic Bezier curve (curve3) with control point
  void curve3(double xCtrl, double yCtrl, double xTo, double yTo) {
    _addVertex(xCtrl, yCtrl, PathCmd.curve3);
    _addVertex(xTo, yTo, PathCmd.curve3);
    _lastCtrlX = xCtrl;
    _lastCtrlY = yCtrl;
  }

  /// Add quadratic Bezier curve relative
  void curve3Rel(double dxCtrl, double dyCtrl, double dxTo, double dyTo) {
    final (x1, y1) = _relToAbs(dxCtrl, dyCtrl);
    final (x2, y2) = _relToAbs(dxTo + dxCtrl, dyTo + dyCtrl);
    curve3(x1, y1, x2 - dxCtrl, y2 - dyCtrl);
  }

  /// Add smooth quadratic Bezier curve (control point is reflection of previous)
  void curve3Smooth(double xTo, double yTo) {
    double xCtrl, yCtrl;
    if (_lastCtrlX != null && _lastCtrlY != null) {
      xCtrl = 2 * lastX - _lastCtrlX!;
      yCtrl = 2 * lastY - _lastCtrlY!;
    } else {
      xCtrl = lastX;
      yCtrl = lastY;
    }
    curve3(xCtrl, yCtrl, xTo, yTo);
  }

  /// Add smooth quadratic Bezier curve relative
  void curve3SmoothRel(double dxTo, double dyTo) {
    final (xTo, yTo) = _relToAbs(dxTo, dyTo);
    curve3Smooth(xTo, yTo);
  }

  /// Add cubic Bezier curve (curve4) with two control points
  void curve4(
    double xCtrl1, double yCtrl1,
    double xCtrl2, double yCtrl2,
    double xTo, double yTo,
  ) {
    _addVertex(xCtrl1, yCtrl1, PathCmd.curve4);
    _addVertex(xCtrl2, yCtrl2, PathCmd.curve4);
    _addVertex(xTo, yTo, PathCmd.curve4);
    _lastCtrlX = xCtrl2;
    _lastCtrlY = yCtrl2;
  }

  /// Add cubic Bezier curve relative
  void curve4Rel(
    double dxCtrl1, double dyCtrl1,
    double dxCtrl2, double dyCtrl2,
    double dxTo, double dyTo,
  ) {
    final (x1, y1) = _relToAbs(dxCtrl1, dyCtrl1);
    final (x2, y2) = _relToAbs(dxCtrl2, dyCtrl2);
    final (x3, y3) = _relToAbs(dxTo, dyTo);
    curve4(x1, y1, x2, y2, x3, y3);
  }

  /// Add smooth cubic Bezier curve (first control point is reflection of previous)
  void curve4Smooth(double xCtrl2, double yCtrl2, double xTo, double yTo) {
    double xCtrl1, yCtrl1;
    if (_lastCtrlX != null && _lastCtrlY != null) {
      xCtrl1 = 2 * lastX - _lastCtrlX!;
      yCtrl1 = 2 * lastY - _lastCtrlY!;
    } else {
      xCtrl1 = lastX;
      yCtrl1 = lastY;
    }
    curve4(xCtrl1, yCtrl1, xCtrl2, yCtrl2, xTo, yTo);
  }

  /// Add smooth cubic Bezier curve relative
  void curve4SmoothRel(double dxCtrl2, double dyCtrl2, double dxTo, double dyTo) {
    final (x1, y1) = _relToAbs(dxCtrl2, dyCtrl2);
    final (x2, y2) = _relToAbs(dxTo, dyTo);
    curve4Smooth(x1, y1, x2, y2);
  }

  /// End polygon with flags
  void endPoly([int flags = PathFlags.close]) {
    if (_cmds.isNotEmpty && isVertex(_cmds.last)) {
      _addVertex(0.0, 0.0, PathCmd.endPoly | flags);
    }
  }

  /// Close polygon
  void closePolygon([int flags = PathFlags.none]) {
    endPoly(PathFlags.close | flags);
  }

  /// Add arc (elliptical arc in SVG style)
  void arcTo(
    double rx, double ry,
    double angle,
    bool largeArcFlag,
    bool sweepFlag,
    double x, double y,
  ) {
    if (totalVertices == 0) {
      moveTo(x, y);
      return;
    }

    const epsilon = 1e-10;
    if ((lastX - x).abs() < epsilon && (lastY - y).abs() < epsilon) {
      return;
    }

    if (rx < epsilon || ry < epsilon) {
      lineTo(x, y);
      return;
    }

    // SVG arc to center parameterization
    final x1 = lastX;
    final y1 = lastY;
    final x2 = x;
    final y2 = y;

    final cosAngle = math.cos(angle);
    final sinAngle = math.sin(angle);

    // Step 1: Compute (x1', y1')
    final dx = (x1 - x2) / 2;
    final dy = (y1 - y2) / 2;
    final x1p = cosAngle * dx + sinAngle * dy;
    final y1p = -sinAngle * dx + cosAngle * dy;

    // Correct radii
    var rxSq = rx * rx;
    var rySq = ry * ry;
    final x1pSq = x1p * x1p;
    final y1pSq = y1p * y1p;

    // Check that radii are large enough
    final lambda = x1pSq / rxSq + y1pSq / rySq;
    if (lambda > 1) {
      final lambdaSqrt = math.sqrt(lambda);
      rx *= lambdaSqrt;
      ry *= lambdaSqrt;
      rxSq = rx * rx;
      rySq = ry * ry;
    }

    // Step 2: Compute (cx', cy')
    var sq = (rxSq * rySq - rxSq * y1pSq - rySq * x1pSq) /
             (rxSq * y1pSq + rySq * x1pSq);
    if (sq < 0) sq = 0;
    final coef = (largeArcFlag == sweepFlag ? -1 : 1) * math.sqrt(sq);
    final cxp = coef * rx * y1p / ry;
    final cyp = -coef * ry * x1p / rx;

    // Step 3: Compute (cx, cy) from (cx', cy')
    final cx = cosAngle * cxp - sinAngle * cyp + (x1 + x2) / 2;
    final cy = sinAngle * cxp + cosAngle * cyp + (y1 + y2) / 2;

    // Step 4: Compute angles
    double angleVector(double ux, double uy, double vx, double vy) {
      final n = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
      var c = (ux * vx + uy * vy) / n;
      if (c < -1) c = -1;
      if (c > 1) c = 1;
      final a = math.acos(c);
      return (ux * vy - uy * vx < 0) ? -a : a;
    }

    final theta1 = angleVector(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
    var dTheta = angleVector(
      (x1p - cxp) / rx, (y1p - cyp) / ry,
      (-x1p - cxp) / rx, (-y1p - cyp) / ry,
    );

    if (!sweepFlag && dTheta > 0) {
      dTheta -= 2 * aggPi;
    } else if (sweepFlag && dTheta < 0) {
      dTheta += 2 * aggPi;
    }

    // Approximate arc with Bezier curves
    _arcToBezier(cx, cy, rx, ry, theta1, dTheta, angle);
  }

  /// Add arc relative
  void arcRel(
    double rx, double ry,
    double angle,
    bool largeArcFlag,
    bool sweepFlag,
    double dx, double dy,
  ) {
    final (x, y) = _relToAbs(dx, dy);
    arcTo(rx, ry, angle, largeArcFlag, sweepFlag, x, y);
  }

  /// Approximate arc with cubic Bezier curves
  void _arcToBezier(
    double cx, double cy,
    double rx, double ry,
    double startAngle, double sweepAngle,
    double rotation,
  ) {
    final n = (sweepAngle.abs() / (aggPi / 2)).ceil();
    final dAngle = sweepAngle / n;

    final cosRot = math.cos(rotation);
    final sinRot = math.sin(rotation);

    for (int i = 0; i < n; i++) {
      final a1 = startAngle + i * dAngle;
      final a2 = a1 + dAngle;

      final k = 4 / 3 * math.tan(dAngle / 4);

      final cos1 = math.cos(a1);
      final sin1 = math.sin(a1);
      final cos2 = math.cos(a2);
      final sin2 = math.sin(a2);

      // Start point
      final x1 = rx * cos1;
      final y1 = ry * sin1;

      // End point
      final x4 = rx * cos2;
      final y4 = ry * sin2;

      // Control point 1
      final x2 = x1 - k * rx * sin1;
      final y2 = y1 + k * ry * cos1;

      // Control point 2
      final x3 = x4 + k * rx * sin2;
      final y3 = y4 - k * ry * cos2;

      // Rotate and translate
      final px2 = cx + cosRot * x2 - sinRot * y2;
      final py2 = cy + sinRot * x2 + cosRot * y2;
      final px3 = cx + cosRot * x3 - sinRot * y3;
      final py3 = cy + sinRot * x3 + cosRot * y3;
      final px4 = cx + cosRot * x4 - sinRot * y4;
      final py4 = cy + sinRot * x4 + cosRot * y4;

      curve4(px2, py2, px3, py3, px4, py4);
    }
  }

  // ===========================================================================
  // Shape helpers
  // ===========================================================================

  /// Add rectangle
  void addRect(double x1, double y1, double x2, double y2) {
    moveTo(x1, y1);
    lineTo(x2, y1);
    lineTo(x2, y2);
    lineTo(x1, y2);
    closePolygon();
  }

  /// Add rounded rectangle
  void addRoundedRect(
    double x1, double y1, double x2, double y2,
    double rx, double ry,
  ) {
    if (rx < 0.001 || ry < 0.001) {
      addRect(x1, y1, x2, y2);
      return;
    }

    final dx = rx.abs();
    final dy = ry.abs();

    moveTo(x1 + dx, y1);
    lineTo(x2 - dx, y1);
    arcTo(dx, dy, 0, false, true, x2, y1 + dy);
    lineTo(x2, y2 - dy);
    arcTo(dx, dy, 0, false, true, x2 - dx, y2);
    lineTo(x1 + dx, y2);
    arcTo(dx, dy, 0, false, true, x1, y2 - dy);
    lineTo(x1, y1 + dy);
    arcTo(dx, dy, 0, false, true, x1 + dx, y1);
    closePolygon();
  }

  /// Add ellipse
  void addEllipse(double cx, double cy, double rx, double ry, [int numSteps = 64]) {
    final da = 2 * aggPi / numSteps;
    for (int i = 0; i < numSteps; i++) {
      final angle = i * da;
      final x = cx + rx * math.cos(angle);
      final y = cy + ry * math.sin(angle);
      if (i == 0) {
        moveTo(x, y);
      } else {
        lineTo(x, y);
      }
    }
    closePolygon();
  }

  /// Add circle
  void addCircle(double cx, double cy, double r, [int numSteps = 64]) {
    addEllipse(cx, cy, r, r, numSteps);
  }

  // ===========================================================================
  // Accessors
  // ===========================================================================

  /// Get total number of vertices
  int get totalVertices => _cmds.length;

  /// Get last X coordinate
  double get lastX {
    if (_coords.length >= 2) {
      return _coords[_coords.length - 2];
    }
    return 0.0;
  }

  /// Get last Y coordinate
  double get lastY {
    if (_coords.isNotEmpty) {
      return _coords.last;
    }
    return 0.0;
  }

  /// Get last command
  int get lastCommand {
    if (_cmds.isNotEmpty) {
      return _cmds.last;
    }
    return PathCmd.stop;
  }

  /// Get vertex at index
  PathVertex getVertex(int idx) {
    if (idx >= 0 && idx < _cmds.length) {
      return PathVertex(
        _coords[idx * 2],
        _coords[idx * 2 + 1],
        _cmds[idx],
      );
    }
    return PathVertex();
  }

  /// Get vertex coordinates
  ({double x, double y, int cmd}) vertex(int idx) {
    if (idx >= 0 && idx < _cmds.length) {
      return (
        x: _coords[idx * 2],
        y: _coords[idx * 2 + 1],
        cmd: _cmds[idx],
      );
    }
    return (x: 0.0, y: 0.0, cmd: PathCmd.stop);
  }

  /// Get command at index
  int command(int idx) {
    if (idx >= 0 && idx < _cmds.length) {
      return _cmds[idx];
    }
    return PathCmd.stop;
  }

  /// Modify vertex at index
  void modifyVertex(int idx, double x, double y, [int? cmd]) {
    if (idx >= 0 && idx < _cmds.length) {
      _coords[idx * 2] = x;
      _coords[idx * 2 + 1] = y;
      if (cmd != null) {
        _cmds[idx] = cmd;
      }
    }
  }

  /// Modify command at index
  void modifyCommand(int idx, int cmd) {
    if (idx >= 0 && idx < _cmds.length) {
      _cmds[idx] = cmd;
    }
  }

  // ===========================================================================
  // Vertex Source interface
  // ===========================================================================

  /// Rewind to beginning of path
  void rewind([int pathId = 0]) {
    _iterator = pathId;
  }

  /// Get next vertex
  ({double x, double y, int cmd}) nextVertex() {
    if (_iterator < _cmds.length) {
      final idx = _iterator++;
      return (
        x: _coords[idx * 2],
        y: _coords[idx * 2 + 1],
        cmd: _cmds[idx],
      );
    }
    return (x: 0.0, y: 0.0, cmd: PathCmd.stop);
  }

  // ===========================================================================
  // Transformation
  // ===========================================================================

  /// Transform all vertices with affine matrix
  void transform(TransAffine matrix, [int pathId = 0]) {
    for (int i = pathId; i < _cmds.length; i++) {
      if (isVertex(_cmds[i])) {
        final p = matrix.transform(_coords[i * 2], _coords[i * 2 + 1]);
        _coords[i * 2] = p.x;
        _coords[i * 2 + 1] = p.y;
      }
    }
  }

  /// Transform all paths
  void transformAllPaths(TransAffine matrix) {
    transform(matrix, 0);
  }

  /// Translate path
  void translate(double dx, double dy, [int pathId = 0]) {
    for (int i = pathId; i < _cmds.length; i++) {
      if (isVertex(_cmds[i])) {
        _coords[i * 2] += dx;
        _coords[i * 2 + 1] += dy;
      }
    }
  }

  /// Translate all paths
  void translateAllPaths(double dx, double dy) {
    translate(dx, dy, 0);
  }

  /// Flip horizontally between x1 and x2
  void flipX(double x1, double x2) {
    for (int i = 0; i < _cmds.length; i++) {
      if (isVertex(_cmds[i])) {
        _coords[i * 2] = x2 - _coords[i * 2] + x1;
      }
    }
  }

  /// Flip vertically between y1 and y2
  void flipY(double y1, double y2) {
    for (int i = 0; i < _cmds.length; i++) {
      if (isVertex(_cmds[i])) {
        _coords[i * 2 + 1] = y2 - _coords[i * 2 + 1] + y1;
      }
    }
  }

  // ===========================================================================
  // Polygon operations
  // ===========================================================================

  /// Invert polygon starting at given vertex
  void invertPolygon(int start) {
    int end = start;
    
    // Find end of polygon
    while (end < _cmds.length && !isEndPoly(_cmds[end])) {
      end++;
    }
    
    // Swap vertices
    int i = start;
    int j = end - 1;
    while (i < j) {
      // Swap coordinates
      final tempX = _coords[i * 2];
      final tempY = _coords[i * 2 + 1];
      _coords[i * 2] = _coords[j * 2];
      _coords[i * 2 + 1] = _coords[j * 2 + 1];
      _coords[j * 2] = tempX;
      _coords[j * 2 + 1] = tempY;
      
      // Swap commands (keeping move_to at start)
      final tempCmd = _cmds[i];
      _cmds[i] = _cmds[j];
      _cmds[j] = tempCmd;
      
      i++;
      j--;
    }
  }

  /// Get bounding box of path
  RectD getBoundingBox() {
    if (_cmds.isEmpty) {
      return RectD(0, 0, 0, 0);
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < _cmds.length; i++) {
      if (isVertex(_cmds[i])) {
        final x = _coords[i * 2];
        final y = _coords[i * 2 + 1];
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    if (minX == double.infinity) {
      return RectD(0, 0, 0, 0);
    }

    return RectD(minX, minY, maxX, maxY);
  }

  // ===========================================================================
  // Private methods
  // ===========================================================================

  void _addVertex(double x, double y, int cmd) {
    _coords.addAll([x, y]);
    _cmds.add(cmd);
  }

  (double, double) _relToAbs(double dx, double dy) {
    return (lastX + dx, lastY + dy);
  }

  @override
  String toString() {
    return 'PathStorage(vertices: $totalVertices)';
  }
}

// ============================================================================
// Line Adaptor
// ============================================================================

/// Simple line segment adaptor
class LineAdaptor {
  double x1, y1, x2, y2;
  int _state = 0;

  LineAdaptor([this.x1 = 0, this.y1 = 0, this.x2 = 0, this.y2 = 0]);

  void init(double x1, double y1, double x2, double y2) {
    this.x1 = x1;
    this.y1 = y1;
    this.x2 = x2;
    this.y2 = y2;
    _state = 0;
  }

  void rewind([int pathId = 0]) {
    _state = 0;
  }

  ({double x, double y, int cmd}) vertex() {
    switch (_state++) {
      case 0:
        return (x: x1, y: y1, cmd: PathCmd.moveTo);
      case 1:
        return (x: x2, y: y2, cmd: PathCmd.lineTo);
      default:
        return (x: 0.0, y: 0.0, cmd: PathCmd.stop);
    }
  }
}

// ============================================================================
// Polygon Adaptor
// ============================================================================

/// Adaptor for polygon data (list of points)
class PolygonAdaptor {
  List<double>? _data;
  int _numPoints = 0;
  bool _closed = false;
  int _index = 0;
  bool _stop = false;

  PolygonAdaptor();

  PolygonAdaptor.init(List<double> data, int numPoints, bool closed)
    : _data = data,
      _numPoints = numPoints,
      _closed = closed;

  void init(List<double> data, int numPoints, bool closed) {
    _data = data;
    _numPoints = numPoints;
    _closed = closed;
    _index = 0;
    _stop = false;
  }

  void rewind([int pathId = 0]) {
    _index = 0;
    _stop = false;
  }

  ({double x, double y, int cmd}) vertex() {
    if (_data == null) {
      return (x: 0.0, y: 0.0, cmd: PathCmd.stop);
    }

    if (_index < _numPoints) {
      final first = _index == 0;
      final x = _data![_index * 2];
      final y = _data![_index * 2 + 1];
      _index++;
      return (
        x: x,
        y: y,
        cmd: first ? PathCmd.moveTo : PathCmd.lineTo,
      );
    }

    if (_closed && !_stop) {
      _stop = true;
      return (x: 0.0, y: 0.0, cmd: PathCmd.endPoly | PathFlags.close);
    }

    return (x: 0.0, y: 0.0, cmd: PathCmd.stop);
  }
}
