// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Discrete Wavelet Transform (DWT) implementation.
/// 
/// Port of dwt.c from OpenJPEG library.
/// Implements forward and inverse DWT with filters:
/// - 5-3 (reversible, lossless)
/// - 9-7 (irreversible, lossy)
library;

import 'dart:math' as math;
import 'dart:typed_data';

// ==========================================================
//   Constants
// ==========================================================

/// DWT Gain values for 5-3 filter
const List<int> _dwt53Gains = [0, 1, 1, 2];

/// DWT Gain values for 9-7 filter  
const List<int> _dwt97Gains = [0, 1, 1, 2];

/// Norm values for 5-3 DWT (precomputed)
const List<List<double>> _dwt53Norms = [
  [1.0, 1.5, 1.5, 2.0],
  [1.0, 1.3217, 1.3217, 1.75],
  [1.0, 1.1949, 1.1949, 1.4289],
  [1.0, 1.1394, 1.1394, 1.2984],
  [1.0, 1.1128, 1.1128, 1.2387],
  [1.0, 1.0995, 1.0995, 1.2088],
  [1.0, 1.0929, 1.0929, 1.1940],
  [1.0, 1.0896, 1.0896, 1.1867],
  [1.0, 1.0880, 1.0880, 1.1830],
  [1.0, 1.0871, 1.0871, 1.1812],
];

/// Norm values for 9-7 DWT (precomputed)
const List<List<double>> _dwt97Norms = [
  [1.0, 1.9659, 1.9659, 3.8634],
  [1.0, 1.2512, 1.2512, 1.5660],
  [1.0, 1.1256, 1.1256, 1.2672],
  [1.0, 1.0628, 1.0628, 1.1295],
  [1.0, 1.0314, 1.0314, 1.0637],
  [1.0, 1.0157, 1.0157, 1.0316],
  [1.0, 1.0079, 1.0079, 1.0157],
  [1.0, 1.0039, 1.0039, 1.0079],
  [1.0, 1.0020, 1.0020, 1.0039],
  [1.0, 1.0010, 1.0010, 1.0020],
];

/// 9-7 filter coefficients
const double _alpha = -1.586134342;
const double _beta = -0.05298011854;
const double _gamma = 0.8829110762;
const double _delta = 0.4435068522;
const double _k = 1.230174105;
const double _invK = 0.8128930661; // 1/K

// ==========================================================
//   Subband Orientation
// ==========================================================

/// Subband orientation
enum SubbandOrientation {
  /// LL band (low-low)
  ll(0),
  
  /// HL band (high-low)
  hl(1),
  
  /// LH band (low-high)
  lh(2),
  
  /// HH band (high-high)
  hh(3);

  const SubbandOrientation(this.value);
  final int value;
}

// ==========================================================
//   DWT Resolution Level
// ==========================================================

/// Resolution level for DWT
class DwtResolution {
  /// X0 coordinate
  int x0;
  
  /// Y0 coordinate
  int y0;
  
  /// X1 coordinate
  int x1;
  
  /// Y1 coordinate
  int y1;
  
  /// Subbands (HL, LH, HH for decomposition levels, LL for level 0)
  List<DwtSubband> subbands;

  DwtResolution({
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    List<DwtSubband>? subbands,
  }) : subbands = subbands ?? [];

  int get width => x1 - x0;
  int get height => y1 - y0;
}

/// Subband information
class DwtSubband {
  /// X0 coordinate
  int x0;
  
  /// Y0 coordinate
  int y0;
  
  /// X1 coordinate
  int x1;
  
  /// Y1 coordinate
  int y1;
  
  /// Band orientation
  SubbandOrientation orientation;
  
  /// Step size for quantization
  double stepSize;
  
  /// Number of significant bits for coding
  int numbps;

  DwtSubband({
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.orientation = SubbandOrientation.ll,
    this.stepSize = 1.0,
    this.numbps = 0,
  });

  int get width => x1 - x0;
  int get height => y1 - y0;
}

// ==========================================================
//   DWT Implementation
// ==========================================================

/// Discrete Wavelet Transform
class Dwt {
  Dwt._();

  /// Gets the norm for 5-3 DWT
  static double getNorm53(int level, int orient) {
    if (level < _dwt53Norms.length) {
      return _dwt53Norms[level][orient];
    }
    return 1.0;
  }

  /// Gets the norm for 9-7 DWT
  static double getNorm97(int level, int orient) {
    if (level < _dwt97Norms.length) {
      return _dwt97Norms[level][orient];
    }
    return 1.0;
  }

  /// Gets the DWT gain for a band
  static int getGain(bool reversible, int orient) {
    return reversible ? _dwt53Gains[orient] : _dwt97Gains[orient];
  }

  /// Calculates step sizes for quantization
  static void calcExplicitStepsizes(
    int numResolutions,
    int precision,
    bool reversible,
    List<double> stepsizes,
  ) {
    final numBands = 3 * numResolutions - 2;
    
    for (var bandno = 0; bandno < numBands; bandno++) {
      int resno, orient;
      
      if (bandno == 0) {
        resno = 0;
        orient = 0;
      } else {
        resno = (bandno - 1) ~/ 3 + 1;
        orient = (bandno - 1) % 3 + 1;
      }

      final level = numResolutions - 1 - resno;
      final norm = reversible ? getNorm53(level, orient) : getNorm97(level, orient);
      final gain = getGain(reversible, orient);
      
      // Calculate step size
      stepsizes[bandno] = (1.0 / (norm * (1 << (precision + gain))));
    }
  }

  /// Forward 5-3 DWT (1D, in-place)
  static void forward53_1d(Int32List data, int start, int length) {
    if (length < 2) return;

    final half = (length + 1) ~/ 2;
    final temp = Int32List(length);

    // Lifting steps
    // Predict: d[n] = d[n] - floor((s[n] + s[n+1]) / 2)
    for (var i = 0; i < length - 1; i += 2) {
      final s0 = data[start + i];
      final s1 = data[start + i + 1];
      temp[i ~/ 2] = s0;
      temp[half + i ~/ 2] = s1 - ((s0 + (i + 2 < length ? data[start + i + 2] : s0)) >> 1);
    }
    if (length.isOdd) {
      temp[half - 1] = data[start + length - 1];
    }

    // Update: s[n] = s[n] + floor((d[n-1] + d[n] + 2) / 4)
    for (var i = 0; i < half; i++) {
      final dPrev = i > 0 ? temp[half + i - 1] : temp[half];
      final d = i < length ~/ 2 ? temp[half + i] : (length > 1 ? temp[half + length ~/ 2 - 1] : 0);
      temp[i] = temp[i] + ((dPrev + d + 2) >> 2);
    }

    // Copy back
    for (var i = 0; i < length; i++) {
      data[start + i] = temp[i];
    }
  }

  /// Inverse 5-3 DWT (1D, in-place)
  static void inverse53_1d(Int32List data, int start, int length) {
    if (length < 2) return;

    final half = (length + 1) ~/ 2;
    final temp = Int32List(length);

    // Copy lowpass and highpass
    for (var i = 0; i < length; i++) {
      temp[i] = data[start + i];
    }

    // Inverse update: s[n] = s[n] - floor((d[n-1] + d[n] + 2) / 4)
    for (var i = 0; i < half; i++) {
      final dPrev = i > 0 ? temp[half + i - 1] : temp[half];
      final d = i < length ~/ 2 ? temp[half + i] : (length > 1 ? temp[half + length ~/ 2 - 1] : 0);
      temp[i] = temp[i] - ((dPrev + d + 2) >> 2);
    }

    // Inverse predict: d[n] = d[n] + floor((s[n] + s[n+1]) / 2)
    // And interleave
    for (var i = 0; i < half; i++) {
      data[start + i * 2] = temp[i];
      if (i * 2 + 1 < length) {
        final s0 = temp[i];
        final s1 = (i + 1 < half) ? temp[i + 1] : temp[i];
        data[start + i * 2 + 1] = temp[half + i] + ((s0 + s1) >> 1);
      }
    }
  }

  /// Forward 9-7 DWT (1D, in-place)
  static void forward97_1d(Float64List data, int start, int length) {
    if (length < 2) return;

    // Extend signal for boundary handling
    final extended = Float64List(length + 8);
    for (var i = 0; i < length; i++) {
      extended[i + 4] = data[start + i];
    }
    // Symmetric extension
    for (var i = 0; i < 4; i++) {
      extended[3 - i] = extended[5 + i];
      extended[length + 4 + i] = extended[length + 2 - i];
    }

    // Lifting steps
    // Step 1: alpha
    for (var i = 4; i < length + 4; i += 2) {
      extended[i + 1] += _alpha * (extended[i] + extended[i + 2]);
    }
    // Step 2: beta
    for (var i = 4; i < length + 4; i += 2) {
      extended[i] += _beta * (extended[i - 1] + extended[i + 1]);
    }
    // Step 3: gamma
    for (var i = 4; i < length + 4; i += 2) {
      extended[i + 1] += _gamma * (extended[i] + extended[i + 2]);
    }
    // Step 4: delta
    for (var i = 4; i < length + 4; i += 2) {
      extended[i] += _delta * (extended[i - 1] + extended[i + 1]);
    }
    // Step 5: scaling
    for (var i = 4; i < length + 4; i += 2) {
      extended[i] *= _invK;
      extended[i + 1] *= _k;
    }

    // Rearrange into lowpass and highpass
    final half = (length + 1) ~/ 2;
    for (var i = 0; i < half; i++) {
      data[start + i] = extended[4 + i * 2];
    }
    for (var i = 0; i < length ~/ 2; i++) {
      data[start + half + i] = extended[5 + i * 2];
    }
  }

  /// Inverse 9-7 DWT (1D, in-place)
  static void inverse97_1d(Float64List data, int start, int length) {
    if (length < 2) return;

    final half = (length + 1) ~/ 2;
    final temp = Float64List(length + 8);

    // Deinterleave
    for (var i = 0; i < half; i++) {
      temp[4 + i * 2] = data[start + i];
    }
    for (var i = 0; i < length ~/ 2; i++) {
      temp[5 + i * 2] = data[start + half + i];
    }

    // Symmetric extension
    for (var i = 0; i < 4; i++) {
      temp[3 - i] = temp[5 + i];
      temp[length + 4 + i] = temp[length + 2 - i];
    }

    // Inverse lifting steps
    // Step 5: inverse scaling
    for (var i = 4; i < length + 4; i += 2) {
      temp[i] *= _k;
      if (i + 1 < length + 4) temp[i + 1] *= _invK;
    }
    // Step 4: inverse delta
    for (var i = 4; i < length + 4; i += 2) {
      temp[i] -= _delta * (temp[i - 1] + temp[i + 1]);
    }
    // Step 3: inverse gamma
    for (var i = 4; i < length + 4; i += 2) {
      if (i + 1 < length + 4) {
        temp[i + 1] -= _gamma * (temp[i] + temp[i + 2]);
      }
    }
    // Step 2: inverse beta
    for (var i = 4; i < length + 4; i += 2) {
      temp[i] -= _beta * (temp[i - 1] + temp[i + 1]);
    }
    // Step 1: inverse alpha
    for (var i = 4; i < length + 4; i += 2) {
      if (i + 1 < length + 4) {
        temp[i + 1] -= _alpha * (temp[i] + temp[i + 2]);
      }
    }

    // Copy back
    for (var i = 0; i < length; i++) {
      data[start + i] = temp[i + 4];
    }
  }

  /// Performs 2D inverse 5-3 DWT on tile component data
  static bool decode53(
    Int32List data,
    int width,
    int height,
    int numResolutions,
  ) {
    if (numResolutions == 0) return true;

    // Working buffers
    final rowBuffer = Int32List(width);
    final colBuffer = Int32List(height);

    // Process each resolution level from lowest to highest
    for (var res = 1; res < numResolutions; res++) {
      final resWidth = _ceilDivPow2(width, numResolutions - 1 - res);
      final resHeight = _ceilDivPow2(height, numResolutions - 1 - res);

      if (resWidth < 2 && resHeight < 2) continue;

      // Vertical inverse DWT
      if (resHeight >= 2) {
        for (var x = 0; x < resWidth; x++) {
          // Extract column
          for (var y = 0; y < resHeight; y++) {
            colBuffer[y] = data[y * width + x];
          }
          // Apply inverse DWT
          inverse53_1d(colBuffer, 0, resHeight);
          // Put back
          for (var y = 0; y < resHeight; y++) {
            data[y * width + x] = colBuffer[y];
          }
        }
      }

      // Horizontal inverse DWT
      if (resWidth >= 2) {
        for (var y = 0; y < resHeight; y++) {
          // Extract row
          for (var x = 0; x < resWidth; x++) {
            rowBuffer[x] = data[y * width + x];
          }
          // Apply inverse DWT
          inverse53_1d(rowBuffer, 0, resWidth);
          // Put back
          for (var x = 0; x < resWidth; x++) {
            data[y * width + x] = rowBuffer[x];
          }
        }
      }
    }

    return true;
  }

  /// Performs 2D inverse 9-7 DWT on tile component data
  static bool decode97(
    Float64List data,
    int width,
    int height,
    int numResolutions,
  ) {
    if (numResolutions == 0) return true;

    // Working buffers
    final rowBuffer = Float64List(width);
    final colBuffer = Float64List(height);

    // Process each resolution level from lowest to highest
    for (var res = 1; res < numResolutions; res++) {
      final resWidth = _ceilDivPow2(width, numResolutions - 1 - res);
      final resHeight = _ceilDivPow2(height, numResolutions - 1 - res);

      if (resWidth < 2 && resHeight < 2) continue;

      // Vertical inverse DWT
      if (resHeight >= 2) {
        for (var x = 0; x < resWidth; x++) {
          // Extract column
          for (var y = 0; y < resHeight; y++) {
            colBuffer[y] = data[y * width + x];
          }
          // Apply inverse DWT
          inverse97_1d(colBuffer, 0, resHeight);
          // Put back
          for (var y = 0; y < resHeight; y++) {
            data[y * width + x] = colBuffer[y];
          }
        }
      }

      // Horizontal inverse DWT
      if (resWidth >= 2) {
        for (var y = 0; y < resHeight; y++) {
          // Extract row
          for (var x = 0; x < resWidth; x++) {
            rowBuffer[x] = data[y * width + x];
          }
          // Apply inverse DWT
          inverse97_1d(rowBuffer, 0, resWidth);
          // Put back
          for (var x = 0; x < resWidth; x++) {
            data[y * width + x] = rowBuffer[x];
          }
        }
      }
    }

    return true;
  }

  /// Performs 2D forward 5-3 DWT on tile component data  
  static bool encode53(
    Int32List data,
    int width,
    int height,
    int numResolutions,
  ) {
    if (numResolutions == 0) return true;

    final rowBuffer = Int32List(width);
    final colBuffer = Int32List(height);

    // Process each resolution level from highest to lowest
    for (var res = numResolutions - 1; res >= 1; res--) {
      final resWidth = _ceilDivPow2(width, numResolutions - 1 - res);
      final resHeight = _ceilDivPow2(height, numResolutions - 1 - res);

      if (resWidth < 2 && resHeight < 2) continue;

      // Horizontal forward DWT
      if (resWidth >= 2) {
        for (var y = 0; y < resHeight; y++) {
          for (var x = 0; x < resWidth; x++) {
            rowBuffer[x] = data[y * width + x];
          }
          forward53_1d(rowBuffer, 0, resWidth);
          for (var x = 0; x < resWidth; x++) {
            data[y * width + x] = rowBuffer[x];
          }
        }
      }

      // Vertical forward DWT
      if (resHeight >= 2) {
        for (var x = 0; x < resWidth; x++) {
          for (var y = 0; y < resHeight; y++) {
            colBuffer[y] = data[y * width + x];
          }
          forward53_1d(colBuffer, 0, resHeight);
          for (var y = 0; y < resHeight; y++) {
            data[y * width + x] = colBuffer[y];
          }
        }
      }
    }

    return true;
  }

  /// Helper: ceiling division by power of 2
  static int _ceilDivPow2(int value, int power) {
    if (power <= 0) return value;
    final divisor = 1 << power;
    return (value + divisor - 1) >> power;
  }
}

// ==========================================================
//   MCT (Multi-Component Transform)
// ==========================================================

/// Multi-Component Transform for color conversion
class Mct {
  Mct._();

  /// Forward irreversible MCT (RGB to YCbCr)
  static void forwardIrreversible(
    Float64List c0,
    Float64List c1,
    Float64List c2,
    int length,
  ) {
    for (var i = 0; i < length; i++) {
      final r = c0[i];
      final g = c1[i];
      final b = c2[i];

      c0[i] = 0.299 * r + 0.587 * g + 0.114 * b;
      c1[i] = -0.16875 * r - 0.33126 * g + 0.5 * b;
      c2[i] = 0.5 * r - 0.41869 * g - 0.08131 * b;
    }
  }

  /// Inverse irreversible MCT (YCbCr to RGB)
  static void inverseIrreversible(
    Float64List c0,
    Float64List c1,
    Float64List c2,
    int length,
  ) {
    for (var i = 0; i < length; i++) {
      final y = c0[i];
      final cb = c1[i];
      final cr = c2[i];

      c0[i] = y + 1.402 * cr;
      c1[i] = y - 0.34413 * cb - 0.71414 * cr;
      c2[i] = y + 1.772 * cb;
    }
  }

  /// Forward reversible MCT (RCT)
  static void forwardReversible(
    Int32List c0,
    Int32List c1,
    Int32List c2,
    int length,
  ) {
    for (var i = 0; i < length; i++) {
      final r = c0[i];
      final g = c1[i];
      final b = c2[i];

      c1[i] = b - g;
      c2[i] = r - g;
      c0[i] = g + ((c1[i] + c2[i]) >> 2);
    }
  }

  /// Inverse reversible MCT (RCT)
  static void inverseReversible(
    Int32List c0,
    Int32List c1,
    Int32List c2,
    int length,
  ) {
    for (var i = 0; i < length; i++) {
      final y = c0[i];
      final u = c1[i];
      final v = c2[i];

      final g = y - ((u + v) >> 2);
      final r = v + g;
      final b = u + g;

      c0[i] = r;
      c1[i] = g;
      c2[i] = b;
    }
  }

  /// Gets MCT norm for irreversible transform
  static List<double> getNormsIrreversible() {
    return [1.732, 1.805, 1.573];
  }

  /// Gets MCT norm for reversible transform
  static List<double> getNormsReversible() {
    return [1.0, 1.0, 1.0];
  }
}
