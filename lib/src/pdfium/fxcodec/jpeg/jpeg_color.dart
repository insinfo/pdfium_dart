// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG Color Conversion
/// 
/// Color space conversion routines for JPEG decoding.
library;

import 'dart:typed_data';

// ==========================================================
//   YCbCr to RGB Conversion
// ==========================================================

/// YCbCr to RGB conversion with fixed-point arithmetic
class JpegColorConvert {
  // Fixed-point constants for YCbCr->RGB
  static const int _fix_1_40200 = 359; // 1.40200 * 256
  static const int _fix_0_34414 = 88; // 0.34414 * 256
  static const int _fix_0_71414 = 183; // 0.71414 * 256
  static const int _fix_1_77200 = 454; // 1.77200 * 256

  /// Converts YCbCr to RGB
  static void ycbcrToRgb(
    Uint8List y,
    Uint8List cb,
    Uint8List cr,
    Uint8List rgb,
    int count,
  ) {
    for (int i = 0, j = 0; i < count; i++, j += 3) {
      final yVal = y[i];
      final cbVal = cb[i] - 128;
      final crVal = cr[i] - 128;

      // R = Y + 1.40200 * Cr
      // G = Y - 0.34414 * Cb - 0.71414 * Cr
      // B = Y + 1.77200 * Cb

      var r = yVal + ((_fix_1_40200 * crVal + 128) >> 8);
      var g = yVal - ((_fix_0_34414 * cbVal + _fix_0_71414 * crVal + 128) >> 8);
      var b = yVal + ((_fix_1_77200 * cbVal + 128) >> 8);

      rgb[j + 0] = _clamp(r);
      rgb[j + 1] = _clamp(g);
      rgb[j + 2] = _clamp(b);
    }
  }

  /// Converts YCbCr to RGBA
  static void ycbcrToRgba(
    Uint8List y,
    Uint8List cb,
    Uint8List cr,
    Uint8List rgba,
    int count,
  ) {
    for (int i = 0, j = 0; i < count; i++, j += 4) {
      final yVal = y[i];
      final cbVal = cb[i] - 128;
      final crVal = cr[i] - 128;

      var r = yVal + ((_fix_1_40200 * crVal + 128) >> 8);
      var g = yVal - ((_fix_0_34414 * cbVal + _fix_0_71414 * crVal + 128) >> 8);
      var b = yVal + ((_fix_1_77200 * cbVal + 128) >> 8);

      rgba[j + 0] = _clamp(r);
      rgba[j + 1] = _clamp(g);
      rgba[j + 2] = _clamp(b);
      rgba[j + 3] = 255;
    }
  }

  /// Converts YCbCr to BGR
  static void ycbcrToBgr(
    Uint8List y,
    Uint8List cb,
    Uint8List cr,
    Uint8List bgr,
    int count,
  ) {
    for (int i = 0, j = 0; i < count; i++, j += 3) {
      final yVal = y[i];
      final cbVal = cb[i] - 128;
      final crVal = cr[i] - 128;

      var r = yVal + ((_fix_1_40200 * crVal + 128) >> 8);
      var g = yVal - ((_fix_0_34414 * cbVal + _fix_0_71414 * crVal + 128) >> 8);
      var b = yVal + ((_fix_1_77200 * cbVal + 128) >> 8);

      bgr[j + 0] = _clamp(b);
      bgr[j + 1] = _clamp(g);
      bgr[j + 2] = _clamp(r);
    }
  }

  /// Converts grayscale to RGB
  static void grayscaleToRgb(
    Uint8List gray,
    Uint8List rgb,
    int count,
  ) {
    for (int i = 0, j = 0; i < count; i++, j += 3) {
      final g = gray[i];
      rgb[j + 0] = g;
      rgb[j + 1] = g;
      rgb[j + 2] = g;
    }
  }

  /// Converts grayscale to RGBA
  static void grayscaleToRgba(
    Uint8List gray,
    Uint8List rgba,
    int count,
  ) {
    for (int i = 0, j = 0; i < count; i++, j += 4) {
      final g = gray[i];
      rgba[j + 0] = g;
      rgba[j + 1] = g;
      rgba[j + 2] = g;
      rgba[j + 3] = 255;
    }
  }

  /// Converts CMYK to RGB
  static void cmykToRgb(
    Uint8List c,
    Uint8List m,
    Uint8List y,
    Uint8List k,
    Uint8List rgb,
    int count,
  ) {
    for (int i = 0, j = 0; i < count; i++, j += 3) {
      // Adobe CMYK is inverted
      final cVal = 255 - c[i];
      final mVal = 255 - m[i];
      final yVal = 255 - y[i];
      final kVal = 255 - k[i];

      // Simple CMY(K) to RGB
      rgb[j + 0] = _clamp((cVal * kVal) ~/ 255);
      rgb[j + 1] = _clamp((mVal * kVal) ~/ 255);
      rgb[j + 2] = _clamp((yVal * kVal) ~/ 255);
    }
  }

  /// Converts YCCK to RGB (through CMYK)
  static void ycckToRgb(
    Uint8List y,
    Uint8List cb,
    Uint8List cr,
    Uint8List k,
    Uint8List rgb,
    int count,
  ) {
    // First convert YCbCr to CMY
    final c = Uint8List(count);
    final m = Uint8List(count);
    final yy = Uint8List(count);

    for (int i = 0; i < count; i++) {
      final yVal = y[i];
      final cbVal = cb[i] - 128;
      final crVal = cr[i] - 128;

      // YCbCr to RGB, then invert for CMY
      var r = yVal + ((_fix_1_40200 * crVal + 128) >> 8);
      var g = yVal - ((_fix_0_34414 * cbVal + _fix_0_71414 * crVal + 128) >> 8);
      var b = yVal + ((_fix_1_77200 * cbVal + 128) >> 8);

      c[i] = 255 - _clamp(r);
      m[i] = 255 - _clamp(g);
      yy[i] = 255 - _clamp(b);
    }

    // Then CMY(K) to RGB
    cmykToRgb(c, m, yy, k, rgb, count);
  }

  static int _clamp(int x) {
    if (x < 0) return 0;
    if (x > 255) return 255;
    return x;
  }
}

// ==========================================================
//   Upsampling
// ==========================================================

/// Upsampling for chroma components
class JpegUpsample {
  /// Simple 2x horizontal upsampling (replication)
  static void horizontal2x(
    Uint8List input,
    int inputWidth,
    Uint8List output,
    int outputWidth,
    int height,
  ) {
    for (int y = 0; y < height; y++) {
      final inRow = y * inputWidth;
      final outRow = y * outputWidth;
      for (int x = 0; x < inputWidth; x++) {
        final val = input[inRow + x];
        output[outRow + x * 2] = val;
        output[outRow + x * 2 + 1] = val;
      }
    }
  }

  /// Simple 2x vertical upsampling (replication)
  static void vertical2x(
    Uint8List input,
    int width,
    int inputHeight,
    Uint8List output,
    int outputHeight,
  ) {
    for (int y = 0; y < inputHeight; y++) {
      final inRow = y * width;
      final outRow1 = y * 2 * width;
      final outRow2 = (y * 2 + 1) * width;
      for (int x = 0; x < width; x++) {
        final val = input[inRow + x];
        output[outRow1 + x] = val;
        output[outRow2 + x] = val;
      }
    }
  }

  /// 2x2 upsampling (both directions)
  static void upsample2x2(
    Uint8List input,
    int inputWidth,
    int inputHeight,
    Uint8List output,
    int outputWidth,
    int outputHeight,
  ) {
    for (int y = 0; y < inputHeight; y++) {
      final inRow = y * inputWidth;
      final outRow1 = y * 2 * outputWidth;
      final outRow2 = (y * 2 + 1) * outputWidth;
      for (int x = 0; x < inputWidth; x++) {
        final val = input[inRow + x];
        final ox = x * 2;
        output[outRow1 + ox] = val;
        output[outRow1 + ox + 1] = val;
        output[outRow2 + ox] = val;
        output[outRow2 + ox + 1] = val;
      }
    }
  }

  /// Bilinear 2x horizontal upsampling
  static void horizontal2xBilinear(
    Uint8List input,
    int inputWidth,
    Uint8List output,
    int outputWidth,
    int height,
  ) {
    for (int y = 0; y < height; y++) {
      final inRow = y * inputWidth;
      final outRow = y * outputWidth;

      for (int x = 0; x < inputWidth; x++) {
        final curr = input[inRow + x];
        final next = (x + 1 < inputWidth) ? input[inRow + x + 1] : curr;

        output[outRow + x * 2] = curr;
        output[outRow + x * 2 + 1] = ((curr + next + 1) >> 1);
      }
    }
  }

  /// Bilinear 2x vertical upsampling
  static void vertical2xBilinear(
    Uint8List input,
    int width,
    int inputHeight,
    Uint8List output,
    int outputHeight,
  ) {
    for (int y = 0; y < inputHeight; y++) {
      final inRow = y * width;
      final nextRow = (y + 1 < inputHeight) ? (y + 1) * width : inRow;
      final outRow1 = y * 2 * width;
      final outRow2 = (y * 2 + 1) * width;

      for (int x = 0; x < width; x++) {
        final curr = input[inRow + x];
        final next = input[nextRow + x];

        output[outRow1 + x] = curr;
        output[outRow2 + x] = ((curr + next + 1) >> 1);
      }
    }
  }
}
