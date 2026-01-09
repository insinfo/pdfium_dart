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
  
  Uint8List? _rgbData;
  int _currentLine = 0;
  int _srcOffset = 0;

  PngScanlineDecoder({
    required PngImage image,
    required int requestedWidth,
    required int requestedHeight,
    required int requestedComps,
  })  : _image = image,
        super(
          origWidth: image.width,
          origHeight: image.height,
          outputWidth: image.width,
          outputHeight: image.height,
          comps: requestedComps > 0 && requestedComps <= 4 ? requestedComps : (image.hasAlpha ? 4 : 3),
          bpc: 8,
          pitch: image.width * (requestedComps > 0 && requestedComps <= 4 ? requestedComps : (image.hasAlpha ? 4 : 3)),
        );

  @override
  int getSrcOffset() => _srcOffset;

  @override
  Uint8List? getNextLine() {
    if (_currentLine >= _image.height) {
      return null;
    }

    final numComps = comps;

    // Generate data on demand
    if (numComps == 4) {
      _rgbData ??= _image.toRgba();
    } else {
      _rgbData ??= _image.toRgb();
    }

    final lineWidth = _image.width;
    final srcComps = numComps == 4 ? 4 : 3;
    final lineData = Uint8List(lineWidth * numComps);

    if (numComps == srcComps) {
      final srcOffset = _currentLine * lineWidth * srcComps;
      lineData.setRange(0, lineWidth * srcComps, _rgbData!, srcOffset);
    } else if (numComps == 1) {
      // Grayscale output
      final srcOffset = _currentLine * lineWidth * 3;
      for (int x = 0; x < lineWidth; x++) {
        final r = _rgbData![srcOffset + x * 3 + 0];
        final g = _rgbData![srcOffset + x * 3 + 1];
        final b = _rgbData![srcOffset + x * 3 + 2];
        lineData[x] = ((r * 77 + g * 151 + b * 28) >> 8);
      }
    } else if (numComps == 3 && srcComps == 4) {
      // Strip alpha
      final srcOffset = _currentLine * lineWidth * 4;
      for (int x = 0; x < lineWidth; x++) {
        lineData[x * 3 + 0] = _rgbData![srcOffset + x * 4 + 0];
        lineData[x * 3 + 1] = _rgbData![srcOffset + x * 4 + 1];
        lineData[x * 3 + 2] = _rgbData![srcOffset + x * 4 + 2];
      }
    }

    _currentLine++;
    _srcOffset = _currentLine * lineWidth * numComps;
    return lineData;
  }

  @override
  bool rewind() {
    _currentLine = 0;
    _srcOffset = 0;
    return true;
  }

  @override
  Uint8List? getScanline(int line) {
    if (line < 0 || line >= _image.height) {
      return null;
    }
    _currentLine = line;
    return getNextLine();
  }
}
