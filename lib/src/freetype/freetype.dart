// FreeType 2 - A high-quality font engine
// Copyright (C) 1996-2025 by David Turner, Robert Wilhelm, and Werner Lemberg.
// Ported to Dart
//
// This file is part of the FreeType project, and may only be used,
// modified, and distributed under the terms of the FreeType project
// license.

/// FreeType 2 Library - High-quality font engine for Dart.
///
/// This library provides functionality for:
/// - Loading fonts (TrueType, OpenType, Type 1, CFF)
/// - Accessing font metrics and glyph information
/// - Rendering glyphs to bitmaps
/// - Character to glyph mapping
/// - Font table access
///
/// Example usage:
/// ```dart
/// import 'package:pdfium_dart/src/freetype/freetype.dart';
///
/// // Create a face
/// final face = FtFace(
///   familyName: 'Arial',
///   styleName: 'Regular',
///   numGlyphs: 3000,
///   unitsPerEM: 2048,
/// );
///
/// // Work with outlines
/// final outline = FtOutline();
/// outline.addPoint(FtVector(x: 0, y: 0), FtCurveTag.on);
/// outline.addPoint(FtVector(x: 100 << 6, y: 0), FtCurveTag.on);
/// outline.addContour();
/// ```
library;

// Core types and constants
export 'freetype_types.dart';

// Outline representation and decomposition
export 'freetype_outline.dart';

// Face, size, glyph slot structures
export 'freetype_face.dart';

// Glyph management and rendering
export 'freetype_glyph.dart';

// Font table structures
export 'freetype_tables.dart';
