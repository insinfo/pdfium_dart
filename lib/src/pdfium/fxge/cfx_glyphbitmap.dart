// Copyright 2019 The PDFium Authors
// Ported to Dart
//
// Glyph bitmap for cached rendered glyphs.

/// Glyph bitmap for cached rendered glyphs.
library;

import 'dart:typed_data';

/// A rendered glyph bitmap with position information.
class CfxGlyphBitmap {
  /// Left offset of the glyph bitmap relative to the origin.
  final int left;
  
  /// Top offset of the glyph bitmap relative to the baseline.
  final int top;
  
  /// Width of the bitmap in pixels.
  final int width;
  
  /// Height of the bitmap in pixels.
  final int rows;
  
  /// Pitch (bytes per row) of the bitmap.
  final int pitch;
  
  /// Grayscale pixel data (8-bit per pixel).
  final Uint8List buffer;

  CfxGlyphBitmap({
    required this.left,
    required this.top,
    required this.width,
    required this.rows,
    required this.pitch,
    required this.buffer,
  });

  /// Create an empty glyph bitmap.
  factory CfxGlyphBitmap.empty() {
    return CfxGlyphBitmap(
      left: 0,
      top: 0,
      width: 0,
      rows: 0,
      pitch: 0,
      buffer: Uint8List(0),
    );
  }

  /// Whether this bitmap is empty (has no pixels).
  bool get isEmpty => width <= 0 || rows <= 0 || buffer.isEmpty;

  /// Copy this bitmap.
  CfxGlyphBitmap copy() {
    return CfxGlyphBitmap(
      left: left,
      top: top,
      width: width,
      rows: rows,
      pitch: pitch,
      buffer: Uint8List.fromList(buffer),
    );
  }

  @override
  String toString() => 'CfxGlyphBitmap($width x $rows @ ($left, $top))';
}
