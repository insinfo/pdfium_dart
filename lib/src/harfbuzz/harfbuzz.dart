// HarfBuzz - A text shaping library
// Copyright © 2007,2008,2009 Red Hat, Inc.
// Copyright © 2011,2012 Google, Inc.
// Ported to Dart
//
// Permission is hereby granted, without written agreement and without
// license or royalty fees, to use, copy, modify, and distribute this
// software and its documentation for any purpose.

/// HarfBuzz - Text shaping library for Dart.
///
/// HarfBuzz is a text shaping engine. It converts sequences of
/// Unicode codepoints into properly positioned glyphs, handling
/// complex text layout for scripts like Arabic, Devanagari, and
/// other OpenType features.
///
/// Example usage:
/// ```dart
/// import 'package:pdfium_dart/src/harfbuzz/harfbuzz.dart';
///
/// // Create font
/// final face = HbFace.empty();
/// face.upem = 1000;
/// face.glyphCount = 100;
/// final font = HbFont.fromFace(face);
///
/// // Create buffer with text
/// final buffer = HbBuffer();
/// buffer.addUtf8('Hello');
///
/// // Shape the text
/// hbShape(font, buffer);
///
/// // Get results
/// for (var i = 0; i < buffer.length; i++) {
///   final info = buffer.getGlyphInfo(i);
///   final pos = buffer.getGlyphPosition(i);
///   print('Glyph ${info.codepoint} at advance ${pos.xAdvance}');
/// }
/// ```
library;

// Core types and constants
export 'harfbuzz_types.dart';

// Buffer for text and glyphs
export 'harfbuzz_buffer.dart';

// Font and face abstraction
export 'harfbuzz_font.dart';

// Text shaping engine
export 'harfbuzz_shaper.dart';
