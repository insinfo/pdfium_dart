// Copyright 2017 The PDFium Authors
// Ported to Dart
//
// CFX_Font - Font class that wraps FreeType face.

/// CFX_Font - Font class that wraps FreeType face.
library;

import 'dart:typed_data';
import 'dart:math' as math;

import '../fxcrt/fx_coordinates.dart';
import '../../freetype/freetype.dart';
import 'cfx_glyphcache.dart';
import 'cfx_glyphbitmap.dart';

// ============================================================================
// Font Type
// ============================================================================

/// Type of font.
enum CfxFontType {
  /// Unknown font type.
  unknown,
  /// CID TrueType font.
  cidTrueType,
  /// Type 1 font.
  type1,
  /// TrueType font.
  trueType,
  /// CFF font.
  cff,
}

// ============================================================================
// Substitution Font
// ============================================================================

/// Font substitution parameters.
class CfxSubstFont {
  /// Font weight (0-900, 400 = normal, 700 = bold).
  int weight;
  
  /// Italic angle in degrees.
  int italicAngle;
  
  /// Whether the font is meant to be italic.
  bool isItalic;
  
  /// Character set.
  int charset;
  
  /// Pitch and family flags.
  int pitchFamily;

  CfxSubstFont({
    this.weight = 400,
    this.italicAngle = 0,
    this.isItalic = false,
    this.charset = 0,
    this.pitchFamily = 0,
  });
}

// ============================================================================
// Character Set Constants
// ============================================================================

/// Character set identifiers.
class FxCharset {
  static const int ansi = 0;
  static const int defaultCharset = 1;
  static const int symbol = 2;
  static const int shiftJIS = 128;
  static const int hangul = 129;
  static const int gb2312 = 134;
  static const int chineseBig5 = 136;
  static const int greek = 161;
  static const int turkish = 162;
  static const int hebrew = 177;
  static const int arabic = 178;
  static const int baltic = 186;
  static const int cyrillic = 204;
  static const int thai = 222;
  static const int eastEurope = 238;
  static const int oem = 255;
}

// ============================================================================
// CFX_Font
// ============================================================================

/// Font class that wraps FreeType face and provides glyph rendering.
class CfxFont {
  /// The untitled font name placeholder.
  static const String untitledFontName = 'Untitled';
  
  /// Default ANSI font name.
  static const String defaultAnsiFontName = 'Helvetica';
  
  /// Universal default font name.
  static const String universalDefaultFontName = 'Arial';

  /// FreeType face.
  FtFace? _face;
  
  /// Glyph cache.
  CfxGlyphCache? _glyphCache;
  
  /// Substitution font parameters.
  CfxSubstFont? _substFont;
  
  /// Font data buffer.
  Uint8List? _fontData;
  
  /// Font type.
  CfxFontType _fontType = CfxFontType.unknown;
  
  /// Object tag for identification.
  int _objectTag = 0;
  
  /// Is vertical text.
  bool _vertical = false;

  CfxFont();

  /// Get the FreeType face.
  FtFace? get face => _face;
  
  /// Check if face is loaded.
  bool get hasFace => _face != null;
  
  /// Get substitution font.
  CfxSubstFont? get substFont => _substFont;
  
  /// Get font type.
  CfxFontType get fontType => _fontType;
  
  /// Set font type.
  set fontType(CfxFontType value) => _fontType = value;
  
  /// Get object tag.
  int get objectTag => _objectTag;
  
  /// Get font data.
  Uint8List? get fontData => _fontData;
  
  /// Is vertical.
  bool get isVertical => _vertical;

  /// Load embedded font from data.
  bool loadEmbedded(Uint8List data, {bool forceVertical = false, int objectTag = 0}) {
    _fontData = Uint8List.fromList(data);
    _objectTag = objectTag;
    _vertical = forceVertical;
    
    // Create face from data
    _face = _parseFontData(data);
    
    if (_face == null) {
      return false;
    }
    
    // Create glyph cache
    _glyphCache = CfxGlyphCache(_face);
    
    return true;
  }

  /// Load font with substitution parameters.
  void loadSubst({
    required String faceName,
    bool isTrueType = true,
    int flags = 0,
    int weight = 400,
    int italicAngle = 0,
    int codePage = 0,
    bool isVertical = false,
  }) {
    _substFont = CfxSubstFont(
      weight: weight,
      italicAngle: italicAngle,
      isItalic: italicAngle != 0,
    );
    _vertical = isVertical;
    
    // Create a minimal face with the given parameters
    _face = FtFace(
      familyName: faceName,
      styleName: weight >= 700 ? 'Bold' : 'Regular',
      unitsPerEM: 1000,
      numGlyphs: 256,
      faceFlags: FtFaceFlags.scalable | FtFaceFlags.horizontal,
      styleFlags: (weight >= 700 ? FtStyleFlags.bold : 0) |
                  (italicAngle != 0 ? FtStyleFlags.italic : 0),
      ascender: 800,
      descender: -200,
      height: 1000,
    );
    
    _glyphCache = CfxGlyphCache(_face);
  }

  /// Get glyph bitmap for rendering.
  CfxGlyphBitmap? loadGlyphBitmap({
    required int glyphIndex,
    bool bFontStyle = true,
    required FxMatrix matrix,
    required int destWidth,
    required FontAntiAliasingMode antiAlias,
    CfxTextRenderOptions? textOptions,
  }) {
    return _glyphCache?.loadGlyphBitmap(
      glyphIndex: glyphIndex,
      bFontStyle: bFontStyle,
      matrix: matrix,
      destWidth: destWidth,
      antiAlias: antiAlias,
      weight: _substFont?.weight ?? 0,
      italicAngle: _substFont?.italicAngle ?? 0,
      vertical: _vertical,
    );
  }

  /// Load glyph path (outline).
  FtOutline? loadGlyphPath(int glyphIndex, int destWidth) {
    return _glyphCache?.loadGlyphPath(
      glyphIndex: glyphIndex,
      destWidth: destWidth,
      weight: _substFont?.weight ?? 0,
      angle: _substFont?.italicAngle ?? 0,
      vertical: _vertical,
    );
  }

  /// Get glyph width.
  int getGlyphWidth(int glyphIndex) {
    if (_face == null) return 0;
    
    return _glyphCache?.getGlyphWidth(
      glyphIndex: glyphIndex,
      destWidth: 0,
      weight: 0,
    ) ?? 0;
  }

  /// Get glyph width with adjustments.
  int getGlyphWidthAdjusted(int glyphIndex, int destWidth, int weight) {
    return _glyphCache?.getGlyphWidth(
      glyphIndex: glyphIndex,
      destWidth: destWidth,
      weight: weight,
    ) ?? 0;
  }

  /// Get font ascent.
  int get ascent => _face?.ascender ?? 0;

  /// Get font descent.
  int get descent => _face?.descender ?? 0;

  /// Check if italic.
  bool get isItalic => _face?.isItalic ?? (_substFont?.isItalic ?? false);

  /// Check if bold.
  bool get isBold => _face?.isBold ?? ((_substFont?.weight ?? 0) >= 700);

  /// Check if fixed width.
  bool get isFixedWidth => _face?.isFixedWidth ?? false;

  /// Get PostScript name.
  String get psName {
    if (_face?.familyName != null) {
      final family = _face!.familyName!;
      final style = _face!.styleName ?? '';
      if (style.isNotEmpty && style != 'Regular') {
        return '$family-$style'.replaceAll(' ', '');
      }
      return family.replaceAll(' ', '');
    }
    return untitledFontName;
  }

  /// Get family name.
  String get familyName => _face?.familyName ?? untitledFontName;

  /// Get base font name.
  String get baseFontName {
    if (_face?.familyName == null) return untitledFontName;
    return _face!.familyName!;
  }

  /// Check if TrueType font.
  bool get isTTFont => _face?.isSfnt ?? false;

  /// Get raw bounding box.
  FxRectInt? get rawBBox {
    if (_face == null) return null;
    final bbox = _face!.bbox;
    return FxRectInt(bbox.xMin, bbox.yMin, bbox.xMax, bbox.yMax);
  }

  /// Get bounding box adjusted for font units.
  FxRectInt? getBBox() {
    if (_face == null) return null;
    final bbox = _face!.bbox;
    final upem = _face!.unitsPerEM;
    if (upem == 0) return rawBBox;
    
    return FxRectInt(
      (bbox.xMin * 1000) ~/ upem,
      (bbox.yMin * 1000) ~/ upem,
      (bbox.xMax * 1000) ~/ upem,
      (bbox.yMax * 1000) ~/ upem,
    );
  }

  /// Get glyph bounding box.
  FxRectInt? getGlyphBBox(int glyphIndex) {
    if (_face == null) return null;
    
    // Get from glyph metrics
    final metrics = _face!.glyph.metrics;
    return FxRectInt(
      metrics.horiBearingX,
      metrics.horiBearingY - metrics.height,
      metrics.horiBearingX + metrics.width,
      metrics.horiBearingY,
    );
  }

  /// Get italic angle from substitution font.
  int get substFontItalicAngle => _substFont?.italicAngle ?? 0;

  /// Create glyph cache if needed.
  CfxGlyphCache getOrCreateGlyphCache() {
    _glyphCache ??= CfxGlyphCache(_face);
    return _glyphCache!;
  }

  /// Clear glyph cache.
  void clearGlyphCache() {
    _glyphCache?.clear();
  }

  // Parse font data to create FtFace
  FtFace? _parseFontData(Uint8List data) {
    // Detect font format from magic bytes
    if (data.length < 4) return null;
    
    // Check for TrueType/OpenType
    if (data[0] == 0x00 && data[1] == 0x01 && 
        data[2] == 0x00 && data[3] == 0x00) {
      // TrueType
      return _parseTrueTypeFont(data);
    }
    
    if (data[0] == 0x4F && data[1] == 0x54 && 
        data[2] == 0x54 && data[3] == 0x4F) {
      // OpenType with CFF
      return _parseOpenTypeFont(data);
    }
    
    if (data[0] == 0x74 && data[1] == 0x72 && 
        data[2] == 0x75 && data[3] == 0x65) {
      // TrueType ('true')
      return _parseTrueTypeFont(data);
    }
    
    if (data[0] == 0x74 && data[1] == 0x79 && 
        data[2] == 0x70 && data[3] == 0x31) {
      // Type 1 ('typ1')
      return _parseType1Font(data);
    }
    
    // Check for Type 1 PFB
    if (data[0] == 0x80 && data[1] == 0x01) {
      return _parseType1Font(data);
    }
    
    // Check for Type 1 ASCII
    if (data[0] == 0x25 && data[1] == 0x21) { // '%!'
      return _parseType1Font(data);
    }
    
    // TrueType collection
    if (data[0] == 0x74 && data[1] == 0x74 && 
        data[2] == 0x63 && data[3] == 0x66) {
      return _parseTrueTypeCollection(data);
    }
    
    // Default: assume TrueType-like
    return _parseTrueTypeFont(data);
  }

  FtFace? _parseTrueTypeFont(Uint8List data) {
    _fontType = CfxFontType.trueType;
    
    // Parse head table for metrics
    final tables = _parseSfntTables(data);
    
    String? familyName;
    String? styleName;
    int unitsPerEM = 1000;
    int ascender = 800;
    int descender = -200;
    int numGlyphs = 0;
    FtBBox bbox = FtBBox();
    
    // Parse 'head' table
    final headData = tables['head'];
    if (headData != null && headData.length >= 54) {
      unitsPerEM = (headData[18] << 8) | headData[19];
      bbox = FtBBox(
        xMin: _readInt16(headData, 36),
        yMin: _readInt16(headData, 38),
        xMax: _readInt16(headData, 40),
        yMax: _readInt16(headData, 42),
      );
    }
    
    // Parse 'hhea' table
    final hheaData = tables['hhea'];
    if (hheaData != null && hheaData.length >= 36) {
      ascender = _readInt16(hheaData, 4);
      descender = _readInt16(hheaData, 6);
    }
    
    // Parse 'maxp' table
    final maxpData = tables['maxp'];
    if (maxpData != null && maxpData.length >= 6) {
      numGlyphs = (maxpData[4] << 8) | maxpData[5];
    }
    
    // Parse 'name' table
    final nameData = tables['name'];
    if (nameData != null) {
      final names = _parseNameTable(nameData);
      familyName = names['family'];
      styleName = names['style'];
    }
    
    int faceFlags = FtFaceFlags.scalable | FtFaceFlags.horizontal | FtFaceFlags.sfnt;
    int styleFlags = 0;
    
    // Check style from name
    if (styleName != null) {
      if (styleName.toLowerCase().contains('bold')) {
        styleFlags |= FtStyleFlags.bold;
      }
      if (styleName.toLowerCase().contains('italic') ||
          styleName.toLowerCase().contains('oblique')) {
        styleFlags |= FtStyleFlags.italic;
      }
    }
    
    // Check for kerning table
    if (tables.containsKey('kern')) {
      faceFlags |= FtFaceFlags.kerning;
    }
    
    return FtFace(
      familyName: familyName ?? 'Unknown',
      styleName: styleName ?? 'Regular',
      unitsPerEM: unitsPerEM > 0 ? unitsPerEM : 1000,
      numGlyphs: numGlyphs,
      ascender: ascender,
      descender: descender,
      height: ascender - descender,
      bbox: bbox,
      faceFlags: faceFlags,
      styleFlags: styleFlags,
      numCharmaps: 1,
      charmaps: [FtCharMap(encoding: FtEncoding.unicode)],
    );
  }

  FtFace? _parseOpenTypeFont(Uint8List data) {
    _fontType = CfxFontType.cff;
    return _parseTrueTypeFont(data);
  }

  FtFace? _parseType1Font(Uint8List data) {
    _fontType = CfxFontType.type1;
    
    // Basic Type 1 parsing - extract font name and metrics
    String? fontName;
    int unitsPerEM = 1000;
    
    // Look for /FontName in data
    final str = String.fromCharCodes(data.take(math.min(4096, data.length)));
    final fontNameMatch = RegExp(r'/FontName\s+/(\S+)').firstMatch(str);
    if (fontNameMatch != null) {
      fontName = fontNameMatch.group(1);
    }
    
    return FtFace(
      familyName: fontName ?? 'Unknown',
      styleName: 'Regular',
      unitsPerEM: unitsPerEM,
      numGlyphs: 256,
      ascender: 800,
      descender: -200,
      height: 1000,
      faceFlags: FtFaceFlags.scalable | FtFaceFlags.horizontal,
    );
  }

  FtFace? _parseTrueTypeCollection(Uint8List data) {
    // Parse first font in collection
    if (data.length < 12) return null;
    
    final numFonts = _readUint32(data, 8);
    if (numFonts == 0) return null;
    
    final offset = _readUint32(data, 12);
    if (offset >= data.length) return null;
    
    // Parse font at offset
    return _parseTrueTypeFont(Uint8List.sublistView(data, offset));
  }

  Map<String, Uint8List> _parseSfntTables(Uint8List data) {
    final tables = <String, Uint8List>{};
    
    if (data.length < 12) return tables;
    
    final numTables = (data[4] << 8) | data[5];
    int offset = 12;
    
    for (int i = 0; i < numTables && offset + 16 <= data.length; i++) {
      final tag = String.fromCharCodes(data.sublist(offset, offset + 4));
      final tableOffset = _readUint32(data, offset + 8);
      final tableLength = _readUint32(data, offset + 12);
      
      if (tableOffset + tableLength <= data.length) {
        tables[tag] = Uint8List.sublistView(data, tableOffset, tableOffset + tableLength);
      }
      
      offset += 16;
    }
    
    return tables;
  }

  Map<String, String> _parseNameTable(Uint8List data) {
    final result = <String, String>{};
    
    if (data.length < 6) return result;
    
    final count = (data[2] << 8) | data[3];
    final storageOffset = (data[4] << 8) | data[5];
    
    int offset = 6;
    for (int i = 0; i < count && offset + 12 <= data.length; i++) {
      final platformId = (data[offset] << 8) | data[offset + 1];
      final encodingId = (data[offset + 2] << 8) | data[offset + 3];
      // final languageId = (data[offset + 4] << 8) | data[offset + 5];
      final nameId = (data[offset + 6] << 8) | data[offset + 7];
      final length = (data[offset + 8] << 8) | data[offset + 9];
      final stringOffset = (data[offset + 10] << 8) | data[offset + 11];
      
      final strStart = storageOffset + stringOffset;
      if (strStart + length <= data.length) {
        final nameBytes = data.sublist(strStart, strStart + length);
        String? name;
        
        // Decode based on platform/encoding
        if (platformId == 3 && (encodingId == 1 || encodingId == 10)) {
          // Windows Unicode
          final codeUnits = <int>[];
          for (int j = 0; j < nameBytes.length - 1; j += 2) {
            codeUnits.add((nameBytes[j] << 8) | nameBytes[j + 1]);
          }
          name = String.fromCharCodes(codeUnits);
        } else if (platformId == 1 && encodingId == 0) {
          // Mac Roman
          name = String.fromCharCodes(nameBytes);
        } else {
          // Try as ASCII
          name = String.fromCharCodes(nameBytes.where((b) => b >= 32 && b < 127));
        }
        
        if (name != null && name.isNotEmpty) {
          switch (nameId) {
            case 1: // Family
              result['family'] ??= name;
              break;
            case 2: // Style
              result['style'] ??= name;
              break;
            case 4: // Full name
              result['full'] ??= name;
              break;
            case 6: // PostScript name
              result['postscript'] ??= name;
              break;
          }
        }
      }
      
      offset += 12;
    }
    
    return result;
  }

  int _readInt16(Uint8List data, int offset) {
    final value = (data[offset] << 8) | data[offset + 1];
    return value >= 0x8000 ? value - 0x10000 : value;
  }

  int _readUint32(Uint8List data, int offset) {
    return (data[offset] << 24) | 
           (data[offset + 1] << 16) | 
           (data[offset + 2] << 8) | 
           data[offset + 3];
  }

  /// Get default font name for charset.
  static String getDefaultFontNameByCharset(int charset) {
    switch (charset) {
      case FxCharset.shiftJIS:
        return 'MS Gothic';
      case FxCharset.hangul:
        return 'Batang';
      case FxCharset.gb2312:
        return 'SimSun';
      case FxCharset.chineseBig5:
        return 'MingLiU';
      case FxCharset.greek:
        return 'Arial';
      case FxCharset.turkish:
        return 'Arial';
      case FxCharset.hebrew:
        return 'Arial';
      case FxCharset.arabic:
        return 'Arial';
      case FxCharset.cyrillic:
        return 'Arial';
      case FxCharset.thai:
        return 'Tahoma';
      default:
        return defaultAnsiFontName;
    }
  }
}

// ============================================================================
// Text Character Position
// ============================================================================

/// Position information for a character in text rendering.
class TextCharPos {
  /// Unicode code point.
  int unicode;
  
  /// Glyph index in the font.
  int glyphIndex;
  
  /// Font for this character.
  CfxFont? font;
  
  /// Position in the font matrix coordinate system.
  FxPoint origin;
  
  /// Character width (horizontal advance).
  double fontCharWidth;
  
  /// Is vertical text.
  bool isVertical;
  
  /// Adjustment to position.
  FxPoint adjust;

  TextCharPos({
    this.unicode = 0,
    this.glyphIndex = 0,
    this.font,
    this.origin = const FxPoint(0, 0),
    this.fontCharWidth = 0,
    this.isVertical = false,
    this.adjust = const FxPoint(0, 0),
  });
}
