// Copyright 2016 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG decoding module
/// 
/// This module provides JPEG decoding functionality using a pure Dart implementation.
library;

import 'dart:typed_data';

import '../scanlinedecoder.dart';
import 'jpeg_decoder.dart';
import 'jpeg_types.dart';

export 'jpeg_decoder.dart';
export 'jpeg_types.dart';
export 'jpeg_color.dart';
export 'jpeg_idct.dart';
export 'jpeg_bitreader.dart';

// ============================================================================
// JPEG Module
// ============================================================================

/// JPEG decoding module for PDFium
class JpegModule {
  /// Creates a scanline decoder for JPEG data
  /// 
  /// Returns null if the JPEG cannot be decoded.
  static ScanlineDecoder? createDecoder({
    required Uint8List srcSpan,
    required int width,
    required int height,
    required int nComps,
    required bool colorTransform,
  }) {
    final result = decodeJpeg(srcSpan);
    if (!result.isSuccess || result.value == null) {
      return null;
    }

    return JpegScanlineDecoder(
      image: result.value!,
      requestedWidth: width,
      requestedHeight: height,
      requestedComps: nComps,
    );
  }

  /// Decodes JPEG data directly
  static JpegResult<JpegImage> decode(Uint8List data) {
    return decodeJpeg(data);
  }

  /// Checks if data is a valid JPEG
  static bool isValidJpeg(Uint8List data) {
    return isJpeg(data);
  }
}

// ============================================================================
// JPEG Scanline Decoder
// ============================================================================

/// Scanline decoder wrapper for JPEG images
class JpegScanlineDecoder extends ScanlineDecoder {
  final JpegImage _image;
  
  Uint8List? _rgbData;
  int _currentLine = 0;
  int _srcOffset = 0;

  JpegScanlineDecoder({
    required JpegImage image,
    required int requestedWidth,
    required int requestedHeight,
    required int requestedComps,
  })  : _image = image,
        super(
          origWidth: image.width,
          origHeight: image.height,
          outputWidth: image.width,
          outputHeight: image.height,
          comps: requestedComps > 0 && requestedComps <= 4 ? requestedComps : image.numComponents,
          bpc: 8,
          pitch: image.width * (requestedComps > 0 && requestedComps <= 4 ? requestedComps : image.numComponents),
        );

  @override
  int getSrcOffset() => _srcOffset;

  @override
  Uint8List? getNextLine() {
    if (_currentLine >= _image.height) {
      return null;
    }

    // Ensure RGB data is generated
    _rgbData ??= _image.toRgb();

    final lineWidth = _image.width;
    final numComps = comps;
    final lineData = Uint8List(lineWidth * numComps);

    if (numComps == 3) {
      // RGB output
      final srcOffset = _currentLine * lineWidth * 3;
      lineData.setRange(0, lineWidth * 3, _rgbData!, srcOffset);
    } else if (numComps == 1) {
      // Grayscale output
      if (_image.numComponents == 1) {
        final srcOffset = _currentLine * lineWidth;
        lineData.setRange(0, lineWidth, _image.components[0], srcOffset);
      } else {
        // Convert RGB to grayscale
        final srcOffset = _currentLine * lineWidth * 3;
        for (int x = 0; x < lineWidth; x++) {
          final r = _rgbData![srcOffset + x * 3 + 0];
          final g = _rgbData![srcOffset + x * 3 + 1];
          final b = _rgbData![srcOffset + x * 3 + 2];
          lineData[x] = ((r * 77 + g * 151 + b * 28) >> 8);
        }
      }
    } else if (numComps == 4) {
      // RGBA output
      final srcOffset = _currentLine * lineWidth * 3;
      for (int x = 0; x < lineWidth; x++) {
        lineData[x * 4 + 0] = _rgbData![srcOffset + x * 3 + 0];
        lineData[x * 4 + 1] = _rgbData![srcOffset + x * 3 + 1];
        lineData[x * 4 + 2] = _rgbData![srcOffset + x * 3 + 2];
        lineData[x * 4 + 3] = 255;
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
