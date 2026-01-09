// FreeType 2 - A high-quality font engine
// Copyright (C) 1996-2025 by David Turner, Robert Wilhelm, and Werner Lemberg.
// Ported to Dart
//
// This file is part of the FreeType project, and may only be used,
// modified, and distributed under the terms of the FreeType project
// license.

/// FreeType basic data types.
library;

import 'dart:typed_data';

// ============================================================================
// Basic Types
// ============================================================================

/// FreeType error code. 0 means success.
typedef FtError = int;

/// Signed position coordinate (can be integer font units or fixed-point).
typedef FtPos = int;

/// 16.16 fixed-point number for scaling and matrix values.
typedef FtFixed = int;

/// 26.6 fixed-point number for pixel coordinates.
typedef FtF26Dot6 = int;

/// 2.14 fixed-point number for unit vectors.
typedef FtF2Dot14 = int;

/// Font word - signed 16-bit distance in font units.
typedef FtFWord = int;

/// Unsigned font word - unsigned 16-bit distance in font units.
typedef FtUFWord = int;

/// 32-bit tag (as used in SFNT format).
typedef FtTag = int;

// ============================================================================
// Fixed-Point Conversion Functions
// ============================================================================

/// Convert integer to 16.16 fixed-point.
int ftIntToFixed(int i) => i << 16;

/// Convert 16.16 fixed-point to integer (truncate).
int ftFixedToInt(int f) => f >> 16;

/// Convert 16.16 fixed-point to integer (round).
int ftFixedRound(int f) => (f + 0x8000) >> 16;

/// Convert double to 16.16 fixed-point.
int ftDoubleToFixed(double d) => (d * 65536.0).round();

/// Convert 16.16 fixed-point to double.
double ftFixedToDouble(int f) => f / 65536.0;

/// Convert integer to 26.6 fixed-point.
int ftIntTo26Dot6(int i) => i << 6;

/// Convert 26.6 fixed-point to integer (truncate).
int ft26Dot6ToInt(int f) => f >> 6;

/// Convert 26.6 fixed-point to integer (round).
int ft26Dot6Round(int f) => (f + 32) >> 6;

/// Convert double to 26.6 fixed-point.
int ftDoubleTo26Dot6(double d) => (d * 64.0).round();

/// Convert 26.6 fixed-point to double.
double ft26Dot6ToDouble(int f) => f / 64.0;

/// Multiply two 16.16 fixed-point numbers.
int ftMulFix(int a, int b) => ((a.toDouble() * b.toDouble()) / 65536.0).round();

/// Divide two 16.16 fixed-point numbers.
int ftDivFix(int a, int b) => ((a.toDouble() * 65536.0) / b.toDouble()).round();

// ============================================================================
// Tag Utilities
// ============================================================================

/// Create a 32-bit tag from four characters.
int ftMakeTag(int c1, int c2, int c3, int c4) {
  return ((c1 & 0xFF) << 24) | ((c2 & 0xFF) << 16) | ((c3 & 0xFF) << 8) | (c4 & 0xFF);
}

/// Create a 32-bit tag from a 4-character string.
int ftMakeTagFromString(String s) {
  if (s.length < 4) {
    s = s.padRight(4, ' ');
  }
  return ftMakeTag(
    s.codeUnitAt(0),
    s.codeUnitAt(1),
    s.codeUnitAt(2),
    s.codeUnitAt(3),
  );
}

/// Convert tag to string.
String ftTagToString(int tag) {
  return String.fromCharCodes([
    (tag >> 24) & 0xFF,
    (tag >> 16) & 0xFF,
    (tag >> 8) & 0xFF,
    tag & 0xFF,
  ]);
}

// ============================================================================
// Vector
// ============================================================================

/// 2D vector with FT_Pos coordinates.
class FtVector {
  FtPos x;
  FtPos y;

  FtVector([this.x = 0, this.y = 0]);

  FtVector.copy(FtVector other) : x = other.x, y = other.y;
  
  FtVector copy() => FtVector(x, y);

  @override
  String toString() => 'FtVector($x, $y)';
}

// ============================================================================
// Unit Vector (2.14 fixed-point)
// ============================================================================

/// 2D unit vector with 2.14 fixed-point coordinates.
class FtUnitVector {
  FtF2Dot14 x;
  FtF2Dot14 y;

  FtUnitVector([this.x = 0, this.y = 0]);

  @override
  String toString() => 'FtUnitVector($x, $y)';
}

// ============================================================================
// Bounding Box
// ============================================================================

/// Bounding box with FT_Pos coordinates.
class FtBBox {
  FtPos xMin;
  FtPos yMin;
  FtPos xMax;
  FtPos yMax;

  FtBBox({this.xMin = 0, this.yMin = 0, this.xMax = 0, this.yMax = 0});

  FtBBox.copy(FtBBox other)
      : xMin = other.xMin,
        yMin = other.yMin,
        xMax = other.xMax,
        yMax = other.yMax;

  /// Width of the bounding box.
  int get width => xMax - xMin;

  /// Height of the bounding box.
  int get height => yMax - yMin;

  /// Check if the bounding box is empty.
  bool get isEmpty => xMin > xMax || yMin > yMax;

  @override
  String toString() => 'FtBBox($xMin, $yMin, $xMax, $yMax)';
}

// ============================================================================
// Matrix (2x2 transformation)
// ============================================================================

/// 2x2 matrix with 16.16 fixed-point coefficients.
/// 
/// Used for transformations:
/// ```
/// x' = x * xx + y * xy
/// y' = x * yx + y * yy
/// ```
class FtMatrix {
  FtFixed xx;
  FtFixed xy;
  FtFixed yx;
  FtFixed yy;

  FtMatrix([
    this.xx = 0x10000, // 1.0 in 16.16
    this.xy = 0,
    this.yx = 0,
    this.yy = 0x10000, // 1.0 in 16.16
  ]);

  FtMatrix.copy(FtMatrix other)
      : xx = other.xx,
        xy = other.xy,
        yx = other.yx,
        yy = other.yy;

  /// Identity matrix.
  factory FtMatrix.identity() => FtMatrix(0x10000, 0, 0, 0x10000);

  /// Transform a vector by this matrix.
  FtVector transform(FtVector v) {
    return FtVector(
      ftMulFix(v.x, xx) + ftMulFix(v.y, xy),
      ftMulFix(v.x, yx) + ftMulFix(v.y, yy),
    );
  }

  /// Multiply this matrix by another.
  FtMatrix multiply(FtMatrix other) {
    return FtMatrix(
      ftMulFix(xx, other.xx) + ftMulFix(xy, other.yx),
      ftMulFix(xx, other.xy) + ftMulFix(xy, other.yy),
      ftMulFix(yx, other.xx) + ftMulFix(yy, other.yx),
      ftMulFix(yx, other.xy) + ftMulFix(yy, other.yy),
    );
  }

  /// Invert this matrix.
  FtMatrix? invert() {
    final det = ftMulFix(xx, yy) - ftMulFix(xy, yx);
    if (det == 0) return null;
    
    return FtMatrix(
      ftDivFix(yy, det),
      ftDivFix(-xy, det),
      ftDivFix(-yx, det),
      ftDivFix(xx, det),
    );
  }

  @override
  String toString() => 'FtMatrix($xx, $xy, $yx, $yy)';
}

// ============================================================================
// Pixel Mode
// ============================================================================

/// Pixel format for bitmaps.
enum FtPixelMode {
  /// Reserved.
  none,
  /// Monochrome, 1 bit per pixel.
  mono,
  /// 8-bit grayscale.
  gray,
  /// 2-bit grayscale.
  gray2,
  /// 4-bit grayscale.
  gray4,
  /// LCD sub-pixel, horizontal.
  lcd,
  /// LCD sub-pixel, vertical.
  lcdV,
  /// 32-bit BGRA color.
  bgra,
}

// ============================================================================
// Bitmap
// ============================================================================

/// Bitmap image descriptor.
class FtBitmap {
  /// Number of rows.
  int rows;
  
  /// Number of pixels per row.
  int width;
  
  /// Pitch (bytes per row, can be negative for bottom-up).
  int pitch;
  
  /// Pixel buffer.
  Uint8List? buffer;
  
  /// Number of gray levels (for gray mode).
  int numGrays;
  
  /// Pixel mode.
  FtPixelMode pixelMode;

  FtBitmap({
    this.rows = 0,
    this.width = 0,
    this.pitch = 0,
    this.buffer,
    this.numGrays = 256,
    this.pixelMode = FtPixelMode.gray,
  });

  FtBitmap copy() {
    return FtBitmap(
        rows: rows,
        width: width,
        pitch: pitch,
        buffer: buffer != null ? Uint8List.fromList(buffer!) : null,
        numGrays: numGrays,
        pixelMode: pixelMode);
  }

  /// Create an empty bitmap with the given dimensions.
  factory FtBitmap.create(int width, int height, FtPixelMode mode) {
    int pitch;
    int numGrays = 256;
    
    switch (mode) {
      case FtPixelMode.mono:
        pitch = (width + 7) ~/ 8;
        numGrays = 2;
        break;
      case FtPixelMode.gray2:
        pitch = (width + 3) ~/ 4;
        numGrays = 4;
        break;
      case FtPixelMode.gray4:
        pitch = (width + 1) ~/ 2;
        numGrays = 16;
        break;
      case FtPixelMode.lcd:
        pitch = width * 3;
        break;
      case FtPixelMode.lcdV:
        pitch = width;
        // height = height * 3;
        break;
      case FtPixelMode.bgra:
        pitch = width * 4;
        break;
      default:
        pitch = width;
        break;
    }
    
    final buffer = Uint8List(pitch * height);
    
    return FtBitmap(
      rows: height,
      width: width,
      pitch: pitch,
      buffer: buffer,
      numGrays: numGrays,
      pixelMode: mode,
    );
  }

  /// Check if the bitmap is empty.
  bool get isEmpty => rows == 0 || width == 0 || buffer == null;

  /// Get a pixel value at the given position.
  int getPixel(int x, int y) {
    if (buffer == null || x < 0 || x >= width || y < 0 || y >= rows) {
      return 0;
    }
    
    final rowStart = y * pitch.abs();
    
    switch (pixelMode) {
      case FtPixelMode.mono:
        final byteOffset = x ~/ 8;
        final bitOffset = 7 - (x % 8);
        return (buffer![rowStart + byteOffset] >> bitOffset) & 1;
        
      case FtPixelMode.gray:
        return buffer![rowStart + x];
        
      case FtPixelMode.gray2:
        final byteOffset = x ~/ 4;
        final shift = 6 - (x % 4) * 2;
        return (buffer![rowStart + byteOffset] >> shift) & 3;
        
      case FtPixelMode.gray4:
        final byteOffset = x ~/ 2;
        final shift = (x % 2 == 0) ? 4 : 0;
        return (buffer![rowStart + byteOffset] >> shift) & 0xF;
        
      case FtPixelMode.bgra:
        final offset = rowStart + x * 4;
        return (buffer![offset + 3] << 24) |
               (buffer![offset + 2] << 16) |
               (buffer![offset + 1] << 8) |
               buffer![offset];
        
      default:
        return 0;
    }
  }

  /// Set a pixel value at the given position.
  void setPixel(int x, int y, int value) {
    if (buffer == null || x < 0 || x >= width || y < 0 || y >= rows) {
      return;
    }
    
    final rowStart = y * pitch.abs();
    
    switch (pixelMode) {
      case FtPixelMode.mono:
        final byteOffset = x ~/ 8;
        final bitOffset = 7 - (x % 8);
        if (value != 0) {
          buffer![rowStart + byteOffset] |= (1 << bitOffset);
        } else {
          buffer![rowStart + byteOffset] &= ~(1 << bitOffset);
        }
        break;
        
      case FtPixelMode.gray:
        buffer![rowStart + x] = value & 0xFF;
        break;
        
      case FtPixelMode.gray2:
        final byteOffset = x ~/ 4;
        final shift = 6 - (x % 4) * 2;
        buffer![rowStart + byteOffset] &= ~(3 << shift);
        buffer![rowStart + byteOffset] |= (value & 3) << shift;
        break;
        
      case FtPixelMode.gray4:
        final byteOffset = x ~/ 2;
        final shift = (x % 2 == 0) ? 4 : 0;
        buffer![rowStart + byteOffset] &= ~(0xF << shift);
        buffer![rowStart + byteOffset] |= (value & 0xF) << shift;
        break;
        
      case FtPixelMode.bgra:
        final offset = rowStart + x * 4;
        buffer![offset] = value & 0xFF;
        buffer![offset + 1] = (value >> 8) & 0xFF;
        buffer![offset + 2] = (value >> 16) & 0xFF;
        buffer![offset + 3] = (value >> 24) & 0xFF;
        break;
        
      default:
        break;
    }
  }

  /// Clear the bitmap to zero.
  void clear() {
    if (buffer != null) {
      buffer!.fillRange(0, buffer!.length, 0);
    }
  }

  @override
  String toString() => 'FtBitmap(${width}x$rows, $pixelMode)';
}

// ============================================================================
// Glyph Format
// ============================================================================

/// Format of glyph image.
enum FtGlyphFormat {
  /// Reserved.
  none,
  /// Composite glyph.
  composite,
  /// Bitmap image.
  bitmap,
  /// Outline representation.
  outline,
  /// Stroked outline.
  plotter,
  /// SVG document.
  svg,
}

/// Get glyph format tag.
int ftGlyphFormatTag(FtGlyphFormat format) {
  switch (format) {
    case FtGlyphFormat.none:
      return 0;
    case FtGlyphFormat.composite:
      return ftMakeTagFromString('comp');
    case FtGlyphFormat.bitmap:
      return ftMakeTagFromString('bits');
    case FtGlyphFormat.outline:
      return ftMakeTagFromString('outl');
    case FtGlyphFormat.plotter:
      return ftMakeTagFromString('plot');
    case FtGlyphFormat.svg:
      return ftMakeTagFromString('SVG ');
  }
}

// ============================================================================
// Error Codes
// ============================================================================

/// Common FreeType error codes.
class FtErrors {
  static const int ok = 0;
  static const int cannotOpenResource = 0x01;
  static const int unknownFileFormat = 0x02;
  static const int invalidFileFormat = 0x03;
  static const int invalidVersion = 0x04;
  static const int lowerModuleVersion = 0x05;
  static const int invalidArgument = 0x06;
  static const int unimplementedFeature = 0x07;
  static const int invalidTable = 0x08;
  static const int invalidOffset = 0x09;
  static const int arrayTooLarge = 0x0A;
  static const int missingModule = 0x0B;
  static const int missingProperty = 0x0C;
  
  // Glyph/character errors
  static const int invalidGlyphIndex = 0x10;
  static const int invalidCharacterCode = 0x11;
  static const int invalidGlyphFormat = 0x12;
  static const int cannotRenderGlyph = 0x13;
  static const int invalidOutline = 0x14;
  static const int invalidComposite = 0x15;
  static const int tooManyHints = 0x16;
  static const int invalidPixelSize = 0x17;
  static const int invalidSvgDocument = 0x18;
  
  // Handle errors
  static const int invalidHandle = 0x20;
  static const int invalidLibraryHandle = 0x21;
  static const int invalidDriverHandle = 0x22;
  static const int invalidFaceHandle = 0x23;
  static const int invalidSizeHandle = 0x24;
  static const int invalidSlotHandle = 0x25;
  static const int invalidCharMapHandle = 0x26;
  static const int invalidCacheHandle = 0x27;
  static const int invalidStreamHandle = 0x28;
  
  // Memory errors
  static const int outOfMemory = 0x40;
  static const int unlistedObject = 0x41;
  
  // Stream errors
  static const int cannotOpenStream = 0x51;
  static const int invalidStreamSeek = 0x52;
  static const int invalidStreamSkip = 0x53;
  static const int invalidStreamRead = 0x54;
  static const int invalidStreamOperation = 0x55;
  static const int invalidFrameOperation = 0x56;
  static const int nestedFrameAccess = 0x57;
  static const int invalidFrameRead = 0x58;
}
