// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// PNG Filter operations
/// 
/// Implements PNG filtering and unfiltering for scanlines.
library;

import 'dart:typed_data';

import 'png_types.dart';

// ==========================================================
//   PNG Filter Operations
// ==========================================================

/// PNG filter/unfilter operations
class PngFilters {
  /// Unfilters a scanline
  /// 
  /// [filterType] - The filter type byte (0-4)
  /// [current] - Current scanline (modified in place)
  /// [previous] - Previous scanline (or null for first row)
  /// [bytesPerPixel] - Number of bytes per pixel
  static void unfilterRow(
    int filterType,
    Uint8List current,
    Uint8List? previous,
    int bytesPerPixel,
  ) {
    switch (filterType) {
      case PngFilter.none:
        // No filter
        break;

      case PngFilter.sub:
        _unfilterSub(current, bytesPerPixel);
        break;

      case PngFilter.up:
        _unfilterUp(current, previous);
        break;

      case PngFilter.average:
        _unfilterAverage(current, previous, bytesPerPixel);
        break;

      case PngFilter.paeth:
        _unfilterPaeth(current, previous, bytesPerPixel);
        break;
    }
  }

  /// Sub filter: Raw(x) = Sub(x) + Raw(x-bpp)
  static void _unfilterSub(Uint8List current, int bpp) {
    for (int i = bpp; i < current.length; i++) {
      current[i] = (current[i] + current[i - bpp]) & 0xFF;
    }
  }

  /// Up filter: Raw(x) = Up(x) + Prior(x)
  static void _unfilterUp(Uint8List current, Uint8List? previous) {
    if (previous == null) return;
    for (int i = 0; i < current.length; i++) {
      current[i] = (current[i] + previous[i]) & 0xFF;
    }
  }

  /// Average filter: Raw(x) = Average(x) + floor((Raw(x-bpp)+Prior(x))/2)
  static void _unfilterAverage(Uint8List current, Uint8List? previous, int bpp) {
    for (int i = 0; i < current.length; i++) {
      final a = i >= bpp ? current[i - bpp] : 0;
      final b = previous != null ? previous[i] : 0;
      current[i] = (current[i] + ((a + b) >> 1)) & 0xFF;
    }
  }

  /// Paeth filter: Raw(x) = Paeth(x) + PaethPredictor(Raw(x-bpp), Prior(x), Prior(x-bpp))
  static void _unfilterPaeth(Uint8List current, Uint8List? previous, int bpp) {
    for (int i = 0; i < current.length; i++) {
      final a = i >= bpp ? current[i - bpp] : 0;
      final b = previous != null ? previous[i] : 0;
      final c = (previous != null && i >= bpp) ? previous[i - bpp] : 0;
      current[i] = (current[i] + _paethPredictor(a, b, c)) & 0xFF;
    }
  }

  /// Paeth predictor function
  static int _paethPredictor(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) {
      return a;
    } else if (pb <= pc) {
      return b;
    } else {
      return c;
    }
  }
}
