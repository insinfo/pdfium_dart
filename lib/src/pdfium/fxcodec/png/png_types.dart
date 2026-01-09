// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// PNG types and constants
/// 
/// Port of libpng data structures and constants.
library;

// ==========================================================
//   PNG Constants
// ==========================================================

/// PNG signature bytes
const List<int> pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

// ==========================================================
//   PNG Chunk Types
// ==========================================================

/// PNG chunk type codes
abstract class PngChunk {
  // Critical chunks
  static const int ihdr = 0x49484452; // IHDR - Image header
  static const int plte = 0x504C5445; // PLTE - Palette
  static const int idat = 0x49444154; // IDAT - Image data
  static const int iend = 0x49454E44; // IEND - Image end

  // Ancillary chunks
  static const int chrm = 0x6348524D; // cHRM - Primary chromaticities
  static const int gama = 0x67414D41; // gAMA - Image gamma
  static const int iccp = 0x69434350; // iCCP - ICC profile
  static const int sbit = 0x73424954; // sBIT - Significant bits
  static const int srgb = 0x73524742; // sRGB - Standard RGB color space
  static const int bkgd = 0x624B4744; // bKGD - Background color
  static const int hist = 0x68495354; // hIST - Image histogram
  static const int trns = 0x74524E53; // tRNS - Transparency
  static const int phys = 0x70485973; // pHYs - Physical dimensions
  static const int splt = 0x73504C54; // sPLT - Suggested palette
  static const int time = 0x74494D45; // tIME - Modification time
  static const int itxt = 0x69545874; // iTXt - International text
  static const int text = 0x74455874; // tEXt - Textual data
  static const int ztxt = 0x7A545874; // zTXt - Compressed text

  /// Converts chunk type to string
  static String typeToString(int type) {
    return String.fromCharCodes([
      (type >> 24) & 0xFF,
      (type >> 16) & 0xFF,
      (type >> 8) & 0xFF,
      type & 0xFF,
    ]);
  }

  /// Converts string to chunk type
  static int stringToType(String s) {
    if (s.length != 4) return 0;
    return (s.codeUnitAt(0) << 24) |
        (s.codeUnitAt(1) << 16) |
        (s.codeUnitAt(2) << 8) |
        s.codeUnitAt(3);
  }

  /// Checks if chunk is critical (uppercase first letter)
  static bool isCritical(int type) {
    return ((type >> 24) & 0x20) == 0;
  }

  /// Checks if chunk is public (uppercase second letter)
  static bool isPublic(int type) {
    return ((type >> 16) & 0x20) == 0;
  }

  /// Checks if chunk is safe to copy (lowercase fourth letter)
  static bool isSafeToCopy(int type) {
    return (type & 0x20) != 0;
  }
}

// ==========================================================
//   PNG Color Types
// ==========================================================

/// PNG color type enumeration
abstract class PngColorType {
  static const int grayscale = 0;
  static const int rgb = 2;
  static const int indexed = 3;
  static const int grayscaleAlpha = 4;
  static const int rgba = 6;

  /// Returns the number of channels for a color type
  static int numChannels(int colorType) {
    switch (colorType) {
      case grayscale:
        return 1;
      case rgb:
        return 3;
      case indexed:
        return 1;
      case grayscaleAlpha:
        return 2;
      case rgba:
        return 4;
      default:
        return 0;
    }
  }

  /// Checks if color type has alpha
  static bool hasAlpha(int colorType) {
    return colorType == grayscaleAlpha || colorType == rgba;
  }

  /// Checks if color type uses palette
  static bool usesPalette(int colorType) {
    return colorType == indexed;
  }
}

// ==========================================================
//   PNG Filter Types
// ==========================================================

/// PNG filter types
abstract class PngFilter {
  static const int none = 0;
  static const int sub = 1;
  static const int up = 2;
  static const int average = 3;
  static const int paeth = 4;
}

// ==========================================================
//   PNG Interlace Methods
// ==========================================================

/// PNG interlace methods
abstract class PngInterlace {
  static const int none = 0;
  static const int adam7 = 1;
}

// ==========================================================
//   PNG Compression Methods
// ==========================================================

/// PNG compression methods
abstract class PngCompression {
  static const int deflate = 0;
}

// ==========================================================
//   Adam7 Interlacing
// ==========================================================

/// Adam7 interlacing parameters
class Adam7Pass {
  final int xStart;
  final int yStart;
  final int xStep;
  final int yStep;

  const Adam7Pass(this.xStart, this.yStart, this.xStep, this.yStep);
}

/// Adam7 pass definitions
const List<Adam7Pass> adam7Passes = [
  Adam7Pass(0, 0, 8, 8), // Pass 1
  Adam7Pass(4, 0, 8, 8), // Pass 2
  Adam7Pass(0, 4, 4, 8), // Pass 3
  Adam7Pass(2, 0, 4, 4), // Pass 4
  Adam7Pass(0, 2, 2, 4), // Pass 5
  Adam7Pass(1, 0, 2, 2), // Pass 6
  Adam7Pass(0, 1, 1, 2), // Pass 7
];

/// Calculates the dimensions of an Adam7 pass
(int width, int height) adam7PassDimensions(int pass, int imageWidth, int imageHeight) {
  final p = adam7Passes[pass];
  final w = (imageWidth - p.xStart + p.xStep - 1) ~/ p.xStep;
  final h = (imageHeight - p.yStart + p.yStep - 1) ~/ p.yStep;
  return (w > 0 ? w : 0, h > 0 ? h : 0);
}

// ==========================================================
//   CRC32 Table
// ==========================================================

/// CRC32 lookup table for PNG
final List<int> _crc32Table = _makeCrc32Table();

List<int> _makeCrc32Table() {
  final table = List<int>.filled(256, 0);
  for (int n = 0; n < 256; n++) {
    int c = n;
    for (int k = 0; k < 8; k++) {
      if ((c & 1) != 0) {
        c = 0xEDB88320 ^ (c >> 1);
      } else {
        c = c >> 1;
      }
    }
    table[n] = c;
  }
  return table;
}

/// Calculates CRC32 for PNG chunk
int pngCrc32(List<int> data, [int crc = 0xFFFFFFFF]) {
  for (final byte in data) {
    crc = _crc32Table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}
