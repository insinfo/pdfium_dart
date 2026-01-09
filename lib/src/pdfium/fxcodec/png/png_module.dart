// Copyright 2016 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// PNG decoding module
/// 
/// This module provides PNG decoding functionality using a pure Dart implementation.
library;

import 'dart:typed_data';

import '../scanlinedecoder.dart';
import 'png_decoder.dart';
import 'png_types.dart';

export 'png_decoder.dart';
export 'png_types.dart';
export 'png_filter.dart';

// ============================================================================
// PNG Module
// ============================================================================

/// PNG decoding module for PDFium
class PngModule {
  /// Creates a scanline decoder for PNG data
  /// 
  /// Returns null if the PNG cannot be decoded.
  static ScanlineDecoder? createDecoder({
    required Uint8List srcSpan,
    required int width,
    required int height,
    required int nComps,
    required int bpc,
  }) {
    final result = decodePng(srcSpan);
    if (!result.isSuccess || result.value == null) {
      return null;
    }

    return PngScanlineDecoder(
      image: result.value!,
      requestedWidth: width,
      requestedHeight: height,
      requestedComps: nComps,
    );
  }

  /// Decodes PNG data directly
  static PngResult<PngImage> decode(Uint8List data) {
    return decodePng(data);
  }

  /// Checks if data is a valid PNG
  static bool isValidPng(Uint8List data) {
    return isPng(data);
  }
}

// ============================================================================
// PNG Scanline Decoder
// ============================================================================

/// Scanline decoder wrapper for PNG images
class PngScanlineDecoder extends ScanlineDecoder {
  final PngImage _image;
  final int _requestedWidth;
  final int _requestedHeight;
  final int _requestedComps;
  
  Uint8List? _rgbData;
  int _currentLine = 0;

  PngScanlineDecoder({
    required PngImage image,
    required int requestedWidth,
    required int requestedHeight,
    required int requestedComps,
  })  : _image = image,
        _requestedWidth = requestedWidth,
        _requestedHeight = requestedHeight,
        _requestedComps = requestedComps;

  @override
  int get width => _image.width;

  @override
  int get height => _image.height;

  @override
  int get components {
    if (_requestedComps > 0 && _requestedComps <= 4) {
      return _requestedComps;
    }
    return _image.hasAlpha ? 4 : 3;
  }

  @override
  int get bitsPerComponent => 8;

  @override
  Uint8List? getNextScanline() {
    if (_currentLine >= _image.height) {
      return null;
    }

    final comps = components;

    // Generate data on demand
    if (comps == 4) {
      _rgbData ??= _image.toRgba();
    } else {
      _rgbData ??= _image.toRgb();
    }

    final lineWidth = _image.width;
    final srcComps = comps == 4 ? 4 : 3;
    final lineData = Uint8List(lineWidth * comps);

    if (comps == srcComps) {
      final srcOffset = _currentLine * lineWidth * srcComps;
      lineData.setRange(0, lineWidth * srcComps, _rgbData!, srcOffset);
    } else if (comps == 1) {
      // Grayscale output
      final srcOffset = _currentLine * lineWidth * 3;
      for (int x = 0; x < lineWidth; x++) {
        final r = _rgbData![srcOffset + x * 3 + 0];
        final g = _rgbData![srcOffset + x * 3 + 1];
        final b = _rgbData![srcOffset + x * 3 + 2];
        lineData[x] = ((r * 77 + g * 151 + b * 28) >> 8);
      }
    } else if (comps == 3 && srcComps == 4) {
      // Strip alpha
      final srcOffset = _currentLine * lineWidth * 4;
      for (int x = 0; x < lineWidth; x++) {
        lineData[x * 3 + 0] = _rgbData![srcOffset + x * 4 + 0];
        lineData[x * 3 + 1] = _rgbData![srcOffset + x * 4 + 1];
        lineData[x * 3 + 2] = _rgbData![srcOffset + x * 4 + 2];
      }
    }

    _currentLine++;
    return lineData;
  }

  @override
  void rewind() {
    _currentLine = 0;
  }

  @override
  bool skipToScanline(int line) {
    if (line < 0 || line >= _image.height) {
      return false;
    }
    _currentLine = line;
    return true;
  }

  @override
  Uint8List? getScanline(int line) {
    if (!skipToScanline(line)) {
      return null;
    }
    return getNextScanline();
  }
}
