// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG Rasterizer - Polygon rasterizer with anti-aliasing.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'agg_basics.dart';
import 'agg_math.dart';
import 'agg_scanline.dart';

// ============================================================================
// Cell for AA rasterization
// ============================================================================

/// A cell in the scanline rasterizer.
/// 
/// Each cell stores coverage and area information for a single pixel.
class CellAA {
  int x = 0;
  int y = 0;
  int cover = 0;
  int area = 0;

  CellAA();

  void set(int x, int y, int cover, int area) {
    this.x = x;
    this.y = y;
    this.cover = cover;
    this.area = area;
  }

  void reset() {
    x = y = cover = area = 0;
  }

  void addCover(int cover, int area) {
    this.cover += cover;
    this.area += area;
  }
}

// ============================================================================
// Rasterizer Cells AA - Cell container and sorter
// ============================================================================

/// Container for AA cells with sorting capability.
class RasterizerCellsAA {
  static const int cellBlockShift = 12;
  static const int cellBlockSize = 1 << cellBlockShift;
  static const int cellBlockMask = cellBlockSize - 1;
  static const int cellBlockLimit = 1024;

  List<List<CellAA>> _cells = [];
  List<int> _sortedY = [];
  Map<int, List<CellAA>> _sortedCells = {};
  
  CellAA _curCell = CellAA();
  int _numCells = 0;
  int _minX = 0x7FFFFFFF;
  int _minY = 0x7FFFFFFF;
  int _maxX = -0x7FFFFFFF;
  int _maxY = -0x7FFFFFFF;
  bool _sorted = false;

  RasterizerCellsAA();

  void reset() {
    _numCells = 0;
    _curCell.reset();
    _sorted = false;
    _minX = 0x7FFFFFFF;
    _minY = 0x7FFFFFFF;
    _maxX = -0x7FFFFFFF;
    _maxY = -0x7FFFFFFF;
    _cells.clear();
    _sortedY.clear();
    _sortedCells.clear();
  }

  /// Add a line segment from (x1,y1) to (x2,y2)
  void line(int x1, int y1, int x2, int y2) {
    const polySubpixelShift = PolySubpixelScale.shift;
    const polySubpixelMask = PolySubpixelScale.mask;

    int dx = x2 - x1;

    if (dx == 0) {
      // Vertical line - special case
      int cover = y2 - y1;
      if (cover != 0) {
        int cy1 = y1 >> polySubpixelShift;
        int cy2 = y2 >> polySubpixelShift;
        int fy1 = y1 & polySubpixelMask;
        int fy2 = y2 & polySubpixelMask;
        int cx = x1 >> polySubpixelShift;
        int fx = x1 & polySubpixelMask;
        
        int dy = y2 - y1; // Calculate dy early

        int first = PolySubpixelScale.scale;
        int incr = 1;

        if (dy < 0) {
          first = 0;
          incr = -1;
        }

        int delta = first - fy1;
        _curCell.addCover(delta, fx * delta);
        
        cy1 += incr;
        _setCurCell(cx, cy1);

        delta = first + first - PolySubpixelScale.scale;
        int area = fx * delta;
        
        while (cy1 != cy2) {
          _curCell.addCover(delta, area);
          cy1 += incr;
          _setCurCell(cx, cy1);
        }
        
        delta = fy2 - PolySubpixelScale.scale + first;
        _curCell.addCover(delta, fx * delta);
      }
      return;
    }

    int dy = y2 - y1;

    // Calculate the polygon subpixel coordinates
    int cx1 = x1 >> polySubpixelShift;
    int cy1 = y1 >> polySubpixelShift;
    int cx2 = x2 >> polySubpixelShift;
    int cy2 = y2 >> polySubpixelShift;

    int fx1 = x1 & polySubpixelMask;
    int fy1 = y1 & polySubpixelMask;
    int fx2 = x2 & polySubpixelMask;
    int fy2 = y2 & polySubpixelMask;

    _minX = math.min(_minX, math.min(cx1, cx2));
    _maxX = math.max(_maxX, math.max(cx1, cx2));

    _setCurCell(cx1, cy1);

    // Render the line using Bresenham-style stepping
    if (cy1 == cy2) {
      // Single scanline
      _renderHline(cy1, fx1, fy1, fx2, fy2);
    } else {
      // Multiple scanlines
      int first = PolySubpixelScale.scale;
      int incr = 1;

      if (dy < 0) {
        first = 0;
        incr = -1;
        dy = -dy;
      }

      // Render first partial scanline
      int delta = first - fy1;
      int p = fx1 + ((fx2 - fx1) * delta ~/ dy);
      _renderHline(cy1, fx1, fy1, p, first);
      cy1 += incr;
      _setCurCell(p >> polySubpixelShift, cy1);

      // Render middle full scanlines
      delta = first + first - PolySubpixelScale.scale;
      while (cy1 != cy2) {
        int xFrom = p;
        p = fx1 + ((fx2 - fx1) * (cy1 - (y1 >> polySubpixelShift)) * PolySubpixelScale.scale ~/ dy);
        _renderHline(cy1, xFrom, 0, p, PolySubpixelScale.scale);
        cy1 += incr;
        _setCurCell(p >> polySubpixelShift, cy1);
      }

      // Render last partial scanline
      _renderHline(cy1, p, PolySubpixelScale.scale - first, fx2, fy2);
    }
  }

  void _renderHline(int cy, int x1, int y1, int x2, int y2) {
    final polySubpixelShift = PolySubpixelScale.shift;
    final polySubpixelMask = PolySubpixelScale.mask;

    int cx1 = x1 >> polySubpixelShift;
    int cx2 = x2 >> polySubpixelShift;
    int fx1 = x1 & polySubpixelMask;
    int fx2 = x2 & polySubpixelMask;

    int cover = y2 - y1;

    if (cx1 == cx2) {
      // Single cell
      _curCell.addCover(cover, (fx1 + fx2) * cover ~/ 2);
      return;
    }

    // Multiple cells
    int p, delta, lift, mod, rem;

    // Render the first cell
    p = (PolySubpixelScale.scale - fx1) * cover;
    delta = p ~/ (x2 - x1);
    mod = p % (x2 - x1);
    
    _curCell.addCover(delta, (PolySubpixelScale.scale + fx1) * delta ~/ 2);
    cx1++;
    _setCurCell(cx1, cy);
    y1 += delta;

    if (cx1 != cx2) {
      p = PolySubpixelScale.scale * cover;
      lift = p ~/ (x2 - x1);
      rem = p % (x2 - x1);
      
      while (cx1 < cx2) {
        delta = lift;
        mod += rem;
        if (mod >= x2 - x1) {
          mod -= x2 - x1;
          delta++;
        }
        _curCell.addCover(delta, PolySubpixelScale.scale * delta ~/ 2);
        y1 += delta;
        cx1++;
        _setCurCell(cx1, cy);
      }
    }

    // Render the last cell
    delta = y2 - y1;
    _curCell.addCover(delta, fx2 * delta ~/ 2);
  }

  void _setCurCell(int x, int y) {
    if (_curCell.cover != 0 || _curCell.area != 0) {
      _addCurCell();
    }
    _curCell.x = x;
    _curCell.y = y;
    _curCell.cover = 0;
    _curCell.area = 0;
  }

  void _addCurCell() {
    if (_curCell.cover != 0 || _curCell.area != 0) {
      final cell = CellAA();
      cell.set(_curCell.x, _curCell.y, _curCell.cover, _curCell.area);
      
      // Add to cell list
      if (_cells.isEmpty || _cells.last.length >= cellBlockSize) {
        _cells.add([]);
      }
      _cells.last.add(cell);
      _numCells++;

      // Update bounds
      _minY = math.min(_minY, cell.y);
      _maxY = math.max(_maxY, cell.y);
    }
  }

  /// Sort cells by Y then X
  void sortCells() {
    if (_sorted) return;
    
    // Flush current cell
    _addCurCell();
    _curCell.reset();

    if (_numCells == 0) {
      _sorted = true;
      return;
    }

    // Collect all cells into a flat list
    final allCells = <CellAA>[];
    for (final block in _cells) {
      allCells.addAll(block);
    }

    // Sort by Y then X
    allCells.sort((a, b) {
      int cmp = a.y.compareTo(b.y);
      if (cmp != 0) return cmp;
      return a.x.compareTo(b.x);
    });

    // Group by Y
    _sortedCells.clear();
    for (final cell in allCells) {
      _sortedCells.putIfAbsent(cell.y, () => []).add(cell);
    }

    _sortedY = _sortedCells.keys.toList()..sort();
    _sorted = true;
  }

  bool get sorted => _sorted;
  int get totalCells => _numCells;
  int get minX => _minX;
  int get minY => _minY;
  int get maxX => _maxX;
  int get maxY => _maxY;

  /// Get number of cells in scanline y
  int scanlineNumCells(int y) {
    return _sortedCells[y]?.length ?? 0;
  }

  /// Get cells for scanline y
  List<CellAA>? scanlineCells(int y) {
    return _sortedCells[y];
  }
}

// ============================================================================
// Rasterizer Scanline AA - Main rasterizer class
// ============================================================================

/// Rasterizer status
enum _RasterizerStatus { initial, moveTo, lineTo, closed }

/// Polygon rasterizer with anti-aliasing.
/// 
/// This is the main class for converting vector paths to anti-aliased
/// scanlines for rendering.
/// 
/// Usage:
/// 1. Create rasterizer
/// 2. Set filling rule and clipping (optional)
/// 3. Add paths using moveTo/lineTo or addPath
/// 4. Call rewindScanlines() to prepare for rendering
/// 5. Iterate with sweepScanline() to render each scanline
class RasterizerScanlineAA {
  static const int aaShift = 8;
  static const int aaScale = 1 << aaShift;
  static const int aaMask = aaScale - 1;
  static const int aaScale2 = aaScale * 2;
  static const int aaMask2 = aaScale2 - 1;

  final RasterizerCellsAA _outline = RasterizerCellsAA();
  final Uint8List _gamma = Uint8List(aaScale);
  
  FillingRule _fillingRule = FillingRule.nonZero;
  bool _autoClose = true;
  int _startX = 0;
  int _startY = 0;
  _RasterizerStatus _status = _RasterizerStatus.initial;
  int _scanY = 0;

  // Clipping
  int? _clipX1, _clipY1, _clipX2, _clipY2;

  RasterizerScanlineAA() {
    // Initialize gamma to linear
    for (int i = 0; i < aaScale; i++) {
      _gamma[i] = i;
    }
  }

  /// Reset the rasterizer
  void reset() {
    _outline.reset();
    _status = _RasterizerStatus.initial;
  }

  /// Set filling rule (non-zero or even-odd)
  void setFillingRule(FillingRule rule) {
    _fillingRule = rule;
  }

  /// Set auto-close polygons
  void setAutoClose(bool flag) {
    _autoClose = flag;
  }

  /// Set gamma correction function
  void setGamma(double Function(double) gammaFunc) {
    for (int i = 0; i < aaScale; i++) {
      _gamma[i] = uround(gammaFunc(i / aaMask) * aaMask);
    }
  }

  /// Set clipping box
  void setClipBox(double x1, double y1, double x2, double y2) {
    _clipX1 = _upscale(x1);
    _clipY1 = _upscale(y1);
    _clipX2 = _upscale(x2);
    _clipY2 = _upscale(y2);
  }

  /// Reset clipping
  void resetClipping() {
    _clipX1 = _clipY1 = _clipX2 = _clipY2 = null;
  }

  /// Move to position (integer coordinates)
  void moveTo(int x, int y) {
    if (_outline.sorted) reset();
    if (_autoClose) closePolygon();
    _startX = _downscale(x);
    _startY = _downscale(y);
    _status = _RasterizerStatus.moveTo;
  }

  /// Line to position (integer coordinates)
  void lineTo(int x, int y) {
    _outline.line(_startX, _startY, _downscale(x), _downscale(y));
    _startX = _downscale(x);
    _startY = _downscale(y);
    _status = _RasterizerStatus.lineTo;
  }

  /// Move to position (double coordinates)
  void moveToD(double x, double y) {
    if (_outline.sorted) reset();
    if (_autoClose) closePolygon();
    _startX = _upscale(x);
    _startY = _upscale(y);
    _status = _RasterizerStatus.moveTo;
  }

  /// Line to position (double coordinates)
  void lineToD(double x, double y) {
    _outline.line(_startX, _startY, _upscale(x), _upscale(y));
    _startX = _upscale(x);
    _startY = _upscale(y);
    _status = _RasterizerStatus.lineTo;
  }

  /// Close the current polygon
  void closePolygon() {
    if (_status == _RasterizerStatus.lineTo) {
      _outline.line(_startX, _startY, _startX, _startY);
      _status = _RasterizerStatus.closed;
    }
  }

  /// Add a vertex
  void addVertex(double x, double y, int cmd) {
    if (isMoveTo(cmd)) {
      moveToD(x, y);
    } else if (isVertex(cmd)) {
      lineToD(x, y);
    } else if (isClose(cmd)) {
      closePolygon();
    }
  }

  /// Add path from PathStorage
  void addPath(dynamic pathStorage, [int pathId = 0]) {
    pathStorage.rewind(pathId);
    if (_outline.sorted) reset();
    
    for (;;) {
      final v = pathStorage.nextVertex();
      if (isStop(v.cmd)) break;
      addVertex(v.x, v.y, v.cmd);
    }
  }

  /// Add edge
  void edge(int x1, int y1, int x2, int y2) {
    if (_outline.sorted) reset();
    _outline.line(_downscale(x1), _downscale(y1), _downscale(x2), _downscale(y2));
    _status = _RasterizerStatus.moveTo;
  }

  /// Add edge (double coordinates)
  void edgeD(double x1, double y1, double x2, double y2) {
    if (_outline.sorted) reset();
    _outline.line(_upscale(x1), _upscale(y1), _upscale(x2), _upscale(y2));
    _status = _RasterizerStatus.moveTo;
  }

  // Coordinate conversion
  static int _upscale(double v) => (v * PolySubpixelScale.scale).round();
  static int _downscale(int v) => v << PolySubpixelScale.shift;

  /// Get min X coordinate
  int get minX => _outline.minX;
  /// Get min Y coordinate
  int get minY => _outline.minY;
  /// Get max X coordinate
  int get maxX => _outline.maxX;
  /// Get max Y coordinate  
  int get maxY => _outline.maxY;

  /// Sort cells
  void sort() {
    if (_autoClose) closePolygon();
    _outline.sortCells();
  }

  /// Rewind scanlines (prepare for rendering)
  bool rewindScanlines() {
    if (_autoClose) closePolygon();
    _outline.sortCells();
    if (_outline.totalCells == 0) {
      return false;
    }
    _scanY = _outline.minY;
    return true;
  }

  /// Navigate to a specific scanline
  bool navigateScanline(int y) {
    if (_autoClose) closePolygon();
    _outline.sortCells();
    if (_outline.totalCells == 0 || y < _outline.minY || y > _outline.maxY) {
      return false;
    }
    _scanY = y;
    return true;
  }

  /// Calculate alpha from area
  int calculateAlpha(int area) {
    int cover = area >> (PolySubpixelScale.shift * 2 + 1 - aaShift);

    if (cover < 0) cover = -cover;
    
    if (_fillingRule == FillingRule.evenOdd) {
      cover &= aaMask2;
      if (cover > aaScale) {
        cover = aaScale2 - cover;
      }
    }
    
    if (cover > aaMask) cover = aaMask;
    return _gamma[cover];
  }

  /// Sweep scanline - render next scanline
  bool sweepScanline(ScanlineU8 sl) {
    while (true) {
      if (_scanY > _outline.maxY) return false;
      
      sl.resetSpans();
      final cells = _outline.scanlineCells(_scanY);
      
      if (cells == null || cells.isEmpty) {
        _scanY++;
        continue;
      }

      int cover = 0;
      int i = 0;

      while (i < cells.length) {
        final curCell = cells[i];
        int x = curCell.x;
        int area = curCell.area;

        cover += curCell.cover;

        // Accumulate all cells with the same X
        i++;
        while (i < cells.length && cells[i].x == x) {
          area += cells[i].area;
          cover += cells[i].cover;
          i++;
        }

        if (area != 0) {
          final alpha = calculateAlpha((cover << (PolySubpixelScale.shift + 1)) - area);
          if (alpha > 0) {
            sl.addCell(x, alpha);
          }
          x++;
        }

        if (i < cells.length && cells[i].x > x) {
          final alpha = calculateAlpha(cover << (PolySubpixelScale.shift + 1));
          if (alpha > 0) {
            sl.addSpan(x, cells[i].x - x, alpha);
          }
        }
      }

      if (sl.numSpans > 0) break;
      _scanY++;
    }

    sl.finalize(_scanY);
    _scanY++;
    return true;
  }

  /// Hit test - check if point is inside rendered area
  bool hitTest(int tx, int ty) {
    if (!navigateScanline(ty)) return false;
    
    final cells = _outline.scanlineCells(ty);
    if (cells == null || cells.isEmpty) return false;

    int cover = 0;
    for (final cell in cells) {
      if (cell.x > tx) break;
      cover += cell.cover;
      if (cell.x == tx) {
        return calculateAlpha(cover << (PolySubpixelScale.shift + 1)) > 0;
      }
    }
    return false;
  }
}
