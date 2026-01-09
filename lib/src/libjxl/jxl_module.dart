// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG XL decoding module for PDFium.
///
/// This module provides JPEG XL decoding functionality using a pure Dart implementation.
library;

import 'dart:typed_data';

import '../pdfium/fxcodec/scanlinedecoder.dart';
import 'jxl_decoder.dart';
import 'jxl_types.dart';

export 'jxl_decoder.dart';
export 'jxl_types.dart';
export 'jxl_bitreader.dart';

// ============================================================================
// JXL Module
// ============================================================================

/// JPEG XL decoding module for PDFium
class JxlModule {
  /// Creates a scanline decoder for JPEG XL data
  ///
  /// Returns null if the JPEG XL cannot be decoded.
  static ScanlineDecoder? createDecoder({
    required Uint8List srcSpan,
    required int width,
    required int height,
    required int nComps,
    required int bpc,
  }) {
    final result = decodeJxl(srcSpan);
    if (!result.isSuccess || result.value == null) {
      return null;
    }

    return JxlScanlineDecoder(
      image: result.value!,
      requestedWidth: width,
      requestedHeight: height,
      requestedComps: nComps,
    );
  }

  /// Decodes JPEG XL data directly
  static JxlResult<JxlImage> decode(Uint8List data) {
    return decodeJxl(data);
  }

  /// Checks if data is a valid JPEG XL
  static bool isValidJxl(Uint8List data) {
    return isJxl(data);
  }

  /// Gets the format type (codestream or container)
  static JxlFormat getFormat(Uint8List data) {
    return detectJxlFormat(data);
  }
}

// ============================================================================
// JXL Scanline Decoder
// ============================================================================

/// Scanline decoder wrapper for JPEG XL images
class JxlScanlineDecoder extends ScanlineDecoder {
  final JxlImage _image;

  Uint8List? _rgbData;
  int _currentLine = 0;
  int _srcOffset = 0;

  JxlScanlineDecoder({
    required JxlImage image,
    required int requestedWidth,
    required int requestedHeight,
    required int requestedComps,
  })  : _image = image,
        super(
          origWidth: image.width,
          origHeight: image.height,
          outputWidth: image.width,
          outputHeight: image.height,
          comps: requestedComps > 0 && requestedComps <= 4
              ? requestedComps
              : (image.hasAlpha ? 4 : (image.isGray ? 1 : 3)),
          bpc: 8,
          pitch: image.width *
              (requestedComps > 0 && requestedComps <= 4
                  ? requestedComps
                  : (image.hasAlpha ? 4 : (image.isGray ? 1 : 3))),
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
    if (numComps == 4 || _image.hasAlpha) {
      _rgbData ??= _image.toRgba();
    } else {
      _rgbData ??= _image.toRgb();
    }

    final lineWidth = _image.width;
    final srcComps = (_image.hasAlpha || numComps == 4) ? 4 : 3;
    final lineData = Uint8List(lineWidth * numComps);

    if (numComps == srcComps) {
      final srcOffset = _currentLine * lineWidth * srcComps;
      lineData.setRange(0, lineWidth * srcComps, _rgbData!, srcOffset);
    } else if (numComps == 1) {
      // Grayscale output
      if (_image.isGray) {
        // Direct copy from gray channel
        final srcOffset = _currentLine * lineWidth * srcComps;
        for (int x = 0; x < lineWidth; x++) {
          lineData[x] = _rgbData![srcOffset + x * srcComps];
        }
      } else {
        // Convert RGB to grayscale
        final srcOffset = _currentLine * lineWidth * srcComps;
        for (int x = 0; x < lineWidth; x++) {
          final r = _rgbData![srcOffset + x * srcComps + 0];
          final g = _rgbData![srcOffset + x * srcComps + 1];
          final b = _rgbData![srcOffset + x * srcComps + 2];
          lineData[x] = ((r * 77 + g * 151 + b * 28) >> 8);
        }
      }
    } else if (numComps == 3 && srcComps == 4) {
      // Strip alpha
      final srcOffset = _currentLine * lineWidth * 4;
      for (int x = 0; x < lineWidth; x++) {
        lineData[x * 3 + 0] = _rgbData![srcOffset + x * 4 + 0];
        lineData[x * 3 + 1] = _rgbData![srcOffset + x * 4 + 1];
        lineData[x * 3 + 2] = _rgbData![srcOffset + x * 4 + 2];
      }
    } else if (numComps == 4 && srcComps == 3) {
      // Add alpha
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
