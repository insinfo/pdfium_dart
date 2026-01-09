// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG Inverse DCT (IDCT)
/// 
/// Port of jidctint.c from libjpeg - Integer IDCT implementation.
library;

import 'dart:typed_data';

import 'jpeg_types.dart';

// ==========================================================
//   IDCT Constants
// ==========================================================

// Constants for scaled integer IDCT
const int _fix_0_298631336 = 2446;
const int _fix_0_390180644 = 3196;
const int _fix_0_541196100 = 4433;
const int _fix_0_765366865 = 6270;
const int _fix_0_899976223 = 7373;
const int _fix_1_175875602 = 9633;
const int _fix_1_501321110 = 12299;
const int _fix_1_847759065 = 15137;
const int _fix_1_961570560 = 16069;
const int _fix_2_053119869 = 16819;
const int _fix_2_562915447 = 20995;
const int _fix_3_072711026 = 25172;

const int _constBits = 13;
const int _passBits = 2;

/// Right-shift with rounding
int _descale(int x, int n) {
  return (x + (1 << (n - 1))) >> n;
}

// ==========================================================
//   Integer IDCT
// ==========================================================

/// Integer IDCT implementation
class JpegIdct {
  /// Performs 8x8 IDCT on coefficients
  /// 
  /// [coef] - 64 DCT coefficients in zigzag order
  /// [quantTable] - Quantization table in natural order
  /// [output] - Output buffer (8x8 = 64 samples)
  /// [outputStride] - Stride of output buffer
  static void idct8x8(
    Int16List coef,
    List<int> quantTable,
    Uint8List output,
    int outputOffset,
    int outputStride,
  ) {
    // Working buffer
    final workspace = Int32List(64);

    // Dequantize and convert from zigzag to natural order
    final dequant = Int32List(64);
    for (int i = 0; i < 64; i++) {
      final natural = jpegZigzag[i];
      dequant[natural] = coef[i] * quantTable[natural];
    }

    // Pass 1: process columns
    for (int col = 0; col < 8; col++) {
      _idctCol(dequant, col, workspace);
    }

    // Pass 2: process rows
    for (int row = 0; row < 8; row++) {
      _idctRow(workspace, row, output, outputOffset + row * outputStride);
    }
  }

  /// IDCT column pass
  static void _idctCol(Int32List input, int col, Int32List workspace) {
    // Get column values
    final d0 = input[col + 8 * 0];
    final d1 = input[col + 8 * 1];
    final d2 = input[col + 8 * 2];
    final d3 = input[col + 8 * 3];
    final d4 = input[col + 8 * 4];
    final d5 = input[col + 8 * 5];
    final d6 = input[col + 8 * 6];
    final d7 = input[col + 8 * 7];

    // Check for all-zero AC coefficients
    if ((d1 | d2 | d3 | d4 | d5 | d6 | d7) == 0) {
      final dc = d0 << _passBits;
      for (int i = 0; i < 8; i++) {
        workspace[col + 8 * i] = dc;
      }
      return;
    }

    // Even part
    var z2 = d2;
    var z3 = d6;

    var z1 = (z2 + z3) * _fix_0_541196100;
    var tmp2 = z1 + z3 * (-_fix_1_847759065);
    var tmp3 = z1 + z2 * _fix_0_765366865;

    z2 = d0;
    z3 = d4;

    var tmp0 = (z2 + z3) << _constBits;
    var tmp1 = (z2 - z3) << _constBits;

    var tmp10 = tmp0 + tmp3;
    var tmp13 = tmp0 - tmp3;
    var tmp11 = tmp1 + tmp2;
    var tmp12 = tmp1 - tmp2;

    // Odd part
    tmp0 = d7;
    tmp1 = d5;
    tmp2 = d3;
    tmp3 = d1;

    z1 = tmp0 + tmp3;
    z2 = tmp1 + tmp2;
    z3 = tmp0 + tmp2;
    var z4 = tmp1 + tmp3;
    var z5 = (z3 + z4) * _fix_1_175875602;

    tmp0 = tmp0 * _fix_0_298631336;
    tmp1 = tmp1 * _fix_2_053119869;
    tmp2 = tmp2 * _fix_3_072711026;
    tmp3 = tmp3 * _fix_1_501321110;
    z1 = z1 * (-_fix_0_899976223);
    z2 = z2 * (-_fix_2_562915447);
    z3 = z3 * (-_fix_1_961570560);
    z4 = z4 * (-_fix_0_390180644);

    z3 += z5;
    z4 += z5;

    tmp0 += z1 + z3;
    tmp1 += z2 + z4;
    tmp2 += z2 + z3;
    tmp3 += z1 + z4;

    // Final output stage
    workspace[col + 8 * 0] = _descale(tmp10 + tmp3, _constBits - _passBits);
    workspace[col + 8 * 7] = _descale(tmp10 - tmp3, _constBits - _passBits);
    workspace[col + 8 * 1] = _descale(tmp11 + tmp2, _constBits - _passBits);
    workspace[col + 8 * 6] = _descale(tmp11 - tmp2, _constBits - _passBits);
    workspace[col + 8 * 2] = _descale(tmp12 + tmp1, _constBits - _passBits);
    workspace[col + 8 * 5] = _descale(tmp12 - tmp1, _constBits - _passBits);
    workspace[col + 8 * 3] = _descale(tmp13 + tmp0, _constBits - _passBits);
    workspace[col + 8 * 4] = _descale(tmp13 - tmp0, _constBits - _passBits);
  }

  /// IDCT row pass
  static void _idctRow(Int32List workspace, int row, Uint8List output, int outOffset) {
    final rowOffset = row * 8;

    // Get row values
    final d0 = workspace[rowOffset + 0];
    final d1 = workspace[rowOffset + 1];
    final d2 = workspace[rowOffset + 2];
    final d3 = workspace[rowOffset + 3];
    final d4 = workspace[rowOffset + 4];
    final d5 = workspace[rowOffset + 5];
    final d6 = workspace[rowOffset + 6];
    final d7 = workspace[rowOffset + 7];

    // Check for all-zero AC coefficients
    if ((d1 | d2 | d3 | d4 | d5 | d6 | d7) == 0) {
      final dc = _clamp(_descale(d0, _constBits + _passBits + 3) + 128);
      for (int i = 0; i < 8; i++) {
        output[outOffset + i] = dc;
      }
      return;
    }

    // Even part
    var z2 = d2;
    var z3 = d6;

    var z1 = (z2 + z3) * _fix_0_541196100;
    var tmp2 = z1 + z3 * (-_fix_1_847759065);
    var tmp3 = z1 + z2 * _fix_0_765366865;

    z2 = d0 + (1 << (_passBits + 2));
    z3 = d4;

    var tmp0 = (z2 + z3) << _constBits;
    var tmp1 = (z2 - z3) << _constBits;

    var tmp10 = tmp0 + tmp3;
    var tmp13 = tmp0 - tmp3;
    var tmp11 = tmp1 + tmp2;
    var tmp12 = tmp1 - tmp2;

    // Odd part
    tmp0 = d7;
    tmp1 = d5;
    tmp2 = d3;
    tmp3 = d1;

    z1 = tmp0 + tmp3;
    z2 = tmp1 + tmp2;
    z3 = tmp0 + tmp2;
    var z4 = tmp1 + tmp3;
    var z5 = (z3 + z4) * _fix_1_175875602;

    tmp0 = tmp0 * _fix_0_298631336;
    tmp1 = tmp1 * _fix_2_053119869;
    tmp2 = tmp2 * _fix_3_072711026;
    tmp3 = tmp3 * _fix_1_501321110;
    z1 = z1 * (-_fix_0_899976223);
    z2 = z2 * (-_fix_2_562915447);
    z3 = z3 * (-_fix_1_961570560);
    z4 = z4 * (-_fix_0_390180644);

    z3 += z5;
    z4 += z5;

    tmp0 += z1 + z3;
    tmp1 += z2 + z4;
    tmp2 += z2 + z3;
    tmp3 += z1 + z4;

    // Final output stage - clamp to 0..255
    output[outOffset + 0] = _clamp(_descale(tmp10 + tmp3, _constBits + _passBits + 3 + _constBits) + 128);
    output[outOffset + 7] = _clamp(_descale(tmp10 - tmp3, _constBits + _passBits + 3 + _constBits) + 128);
    output[outOffset + 1] = _clamp(_descale(tmp11 + tmp2, _constBits + _passBits + 3 + _constBits) + 128);
    output[outOffset + 6] = _clamp(_descale(tmp11 - tmp2, _constBits + _passBits + 3 + _constBits) + 128);
    output[outOffset + 2] = _clamp(_descale(tmp12 + tmp1, _constBits + _passBits + 3 + _constBits) + 128);
    output[outOffset + 5] = _clamp(_descale(tmp12 - tmp1, _constBits + _passBits + 3 + _constBits) + 128);
    output[outOffset + 3] = _clamp(_descale(tmp13 + tmp0, _constBits + _passBits + 3 + _constBits) + 128);
    output[outOffset + 4] = _clamp(_descale(tmp13 - tmp0, _constBits + _passBits + 3 + _constBits) + 128);
  }

  /// Clamps value to 0..255
  static int _clamp(int x) {
    if (x < 0) return 0;
    if (x > 255) return 255;
    return x;
  }
}

// ==========================================================
//   Fast Integer IDCT
// ==========================================================

/// Fast integer IDCT (less accurate but faster)
class JpegIdctFast {
  /// Performs fast 8x8 IDCT
  static void idct8x8(
    Int16List coef,
    List<int> quantTable,
    Uint8List output,
    int outputOffset,
    int outputStride,
  ) {
    // Working buffer
    final workspace = Int32List(64);

    // Dequantize and convert from zigzag
    for (int i = 0; i < 64; i++) {
      final natural = jpegZigzag[i];
      workspace[natural] = coef[i] * quantTable[natural];
    }

    // Transform columns
    for (int col = 0; col < 8; col++) {
      _idctColFast(workspace, col);
    }

    // Transform rows and output
    for (int row = 0; row < 8; row++) {
      _idctRowFast(workspace, row, output, outputOffset + row * outputStride);
    }
  }

  static void _idctColFast(Int32List data, int col) {
    var d0 = data[col + 0];
    var d1 = data[col + 8];
    var d2 = data[col + 16];
    var d3 = data[col + 24];
    var d4 = data[col + 32];
    var d5 = data[col + 40];
    var d6 = data[col + 48];
    var d7 = data[col + 56];

    if ((d1 | d2 | d3 | d4 | d5 | d6 | d7) == 0) {
      final dc = d0 << 2;
      data[col + 0] = dc;
      data[col + 8] = dc;
      data[col + 16] = dc;
      data[col + 24] = dc;
      data[col + 32] = dc;
      data[col + 40] = dc;
      data[col + 48] = dc;
      data[col + 56] = dc;
      return;
    }

    // Stage 1
    var tmp0 = d0 + d4;
    var tmp1 = d0 - d4;
    var tmp2 = d2 - d6;
    var tmp3 = d2 + d6;

    // Stage 2
    var tmp4 = tmp0 + tmp3;
    var tmp7 = tmp0 - tmp3;
    var t = ((tmp2 * 181) >> 8) - tmp3;
    var tmp5 = tmp1 + t;
    var tmp6 = tmp1 - t;

    // Stage 3
    tmp0 = d1 + d7;
    tmp1 = d5 + d3;
    tmp2 = d1 - d7;
    tmp3 = d5 - d3;

    // Stage 4
    var z = ((tmp0 - tmp1) * 181) >> 8;
    t = tmp0 + tmp1;
    tmp0 = t;
    tmp1 = z;

    z = ((tmp2 + tmp3) * 181) >> 8;
    t = tmp2 + z;
    var tmp2b = (tmp2 - z);
    tmp2 = t;
    tmp3 = tmp2b;

    // Output
    data[col + 0] = (tmp4 + tmp0) << 2;
    data[col + 56] = (tmp4 - tmp0) << 2;
    data[col + 8] = (tmp5 + tmp2) << 2;
    data[col + 48] = (tmp5 - tmp2) << 2;
    data[col + 16] = (tmp6 + tmp3) << 2;
    data[col + 40] = (tmp6 - tmp3) << 2;
    data[col + 24] = (tmp7 + tmp1) << 2;
    data[col + 32] = (tmp7 - tmp1) << 2;
  }

  static void _idctRowFast(Int32List data, int row, Uint8List output, int outOffset) {
    final offset = row * 8;

    var d0 = data[offset + 0];
    var d1 = data[offset + 1];
    var d2 = data[offset + 2];
    var d3 = data[offset + 3];
    var d4 = data[offset + 4];
    var d5 = data[offset + 5];
    var d6 = data[offset + 6];
    var d7 = data[offset + 7];

    if ((d1 | d2 | d3 | d4 | d5 | d6 | d7) == 0) {
      final dc = _clamp((d0 >> 5) + 128);
      output[outOffset + 0] = dc;
      output[outOffset + 1] = dc;
      output[outOffset + 2] = dc;
      output[outOffset + 3] = dc;
      output[outOffset + 4] = dc;
      output[outOffset + 5] = dc;
      output[outOffset + 6] = dc;
      output[outOffset + 7] = dc;
      return;
    }

    // Same as column but with output clamping
    var tmp0 = d0 + d4;
    var tmp1 = d0 - d4;
    var tmp2 = d2 - d6;
    var tmp3 = d2 + d6;

    var tmp4 = tmp0 + tmp3;
    var tmp7 = tmp0 - tmp3;
    var t = ((tmp2 * 181) >> 8) - tmp3;
    var tmp5 = tmp1 + t;
    var tmp6 = tmp1 - t;

    tmp0 = d1 + d7;
    tmp1 = d5 + d3;
    tmp2 = d1 - d7;
    tmp3 = d5 - d3;

    var z = ((tmp0 - tmp1) * 181) >> 8;
    t = tmp0 + tmp1;
    tmp0 = t;
    tmp1 = z;

    z = ((tmp2 + tmp3) * 181) >> 8;
    t = tmp2 + z;
    var tmp2b = tmp2 - z;
    tmp2 = t;
    tmp3 = tmp2b;

    output[outOffset + 0] = _clamp(((tmp4 + tmp0) >> 5) + 128);
    output[outOffset + 7] = _clamp(((tmp4 - tmp0) >> 5) + 128);
    output[outOffset + 1] = _clamp(((tmp5 + tmp2) >> 5) + 128);
    output[outOffset + 6] = _clamp(((tmp5 - tmp2) >> 5) + 128);
    output[outOffset + 2] = _clamp(((tmp6 + tmp3) >> 5) + 128);
    output[outOffset + 5] = _clamp(((tmp6 - tmp3) >> 5) + 128);
    output[outOffset + 3] = _clamp(((tmp7 + tmp1) >> 5) + 128);
    output[outOffset + 4] = _clamp(((tmp7 - tmp1) >> 5) + 128);
  }

  static int _clamp(int x) {
    if (x < 0) return 0;
    if (x > 255) return 255;
    return x;
  }
}
