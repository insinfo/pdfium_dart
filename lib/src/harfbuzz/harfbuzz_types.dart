// HarfBuzz - A text shaping library
// Copyright © 2007,2008,2009 Red Hat, Inc.
// Copyright © 2011,2012 Google, Inc.
// Ported to Dart
//
// Permission is hereby granted, without written agreement and without
// license or royalty fees, to use, copy, modify, and distribute this
// software and its documentation for any purpose.

/// HarfBuzz common types and constants.
library;

// ============================================================================
// Basic Types
// ============================================================================

/// Boolean type.
typedef HbBool = bool;

/// Unicode codepoint or glyph ID.
typedef HbCodepoint = int;

/// Position value (typically in font units or 26.6 fixed-point).
typedef HbPosition = int;

/// Bitmask type.
typedef HbMask = int;

/// Invalid codepoint marker.
const int hbCodepointInvalid = 0xFFFFFFFF;

// ============================================================================
// Tags
// ============================================================================

/// Tag type (4-character identifier).
typedef HbTag = int;

/// Create a tag from four characters.
int hbTag(int c1, int c2, int c3, int c4) {
  return ((c1 & 0xFF) << 24) | ((c2 & 0xFF) << 16) | ((c3 & 0xFF) << 8) | (c4 & 0xFF);
}

/// Create a tag from a 4-character string.
int hbTagFromString(String str) {
  if (str.length < 4) {
    str = str.padRight(4, ' ');
  }
  return hbTag(
    str.codeUnitAt(0),
    str.codeUnitAt(1),
    str.codeUnitAt(2),
    str.codeUnitAt(3),
  );
}

/// Convert a tag to a string.
String hbTagToString(int tag) {
  return String.fromCharCodes([
    (tag >> 24) & 0xFF,
    (tag >> 16) & 0xFF,
    (tag >> 8) & 0xFF,
    tag & 0xFF,
  ]);
}

/// No tag.
final int hbTagNone = hbTag(0, 0, 0, 0);

/// Maximum tag value.
final int hbTagMax = hbTag(0xFF, 0xFF, 0xFF, 0xFF);

// ============================================================================
// Direction
// ============================================================================

/// Text direction.
enum HbDirection {
  /// Invalid/unset direction.
  invalid,
  /// Left to right.
  ltr,
  /// Right to left.
  rtl,
  /// Top to bottom.
  ttb,
  /// Bottom to top.
  btt,
}

/// Check if direction is valid.
bool hbDirectionIsValid(HbDirection dir) {
  return dir != HbDirection.invalid;
}

/// Check if direction is horizontal.
bool hbDirectionIsHorizontal(HbDirection dir) {
  return dir == HbDirection.ltr || dir == HbDirection.rtl;
}

/// Check if direction is vertical.
bool hbDirectionIsVertical(HbDirection dir) {
  return dir == HbDirection.ttb || dir == HbDirection.btt;
}

/// Check if direction is forward.
bool hbDirectionIsForward(HbDirection dir) {
  return dir == HbDirection.ltr || dir == HbDirection.ttb;
}

/// Check if direction is backward.
bool hbDirectionIsBackward(HbDirection dir) {
  return dir == HbDirection.rtl || dir == HbDirection.btt;
}

/// Reverse a direction.
HbDirection hbDirectionReverse(HbDirection dir) {
  switch (dir) {
    case HbDirection.ltr: return HbDirection.rtl;
    case HbDirection.rtl: return HbDirection.ltr;
    case HbDirection.ttb: return HbDirection.btt;
    case HbDirection.btt: return HbDirection.ttb;
    case HbDirection.invalid: return HbDirection.invalid;
  }
}

/// Parse direction from string.
HbDirection hbDirectionFromString(String str) {
  final s = str.toLowerCase().trim();
  switch (s) {
    case 'ltr':
    case 'l':
      return HbDirection.ltr;
    case 'rtl':
    case 'r':
      return HbDirection.rtl;
    case 'ttb':
    case 't':
      return HbDirection.ttb;
    case 'btt':
    case 'b':
      return HbDirection.btt;
    default:
      return HbDirection.invalid;
  }
}

/// Convert direction to string.
String hbDirectionToString(HbDirection dir) {
  switch (dir) {
    case HbDirection.ltr: return 'ltr';
    case HbDirection.rtl: return 'rtl';
    case HbDirection.ttb: return 'ttb';
    case HbDirection.btt: return 'btt';
    case HbDirection.invalid: return '';
  }
}

// ============================================================================
// Script
// ============================================================================

/// Script identifiers (ISO 15924).
enum HbScript {
  /// Common script.
  common,
  /// Inherited script.
  inherited,
  /// Unknown script.
  unknown,
  
  // Major scripts
  /// Arabic script.
  arabic,
  /// Armenian script.
  armenian,
  /// Bengali script.
  bengali,
  /// Cyrillic script.
  cyrillic,
  /// Devanagari script.
  devanagari,
  /// Georgian script.
  georgian,
  /// Greek script.
  greek,
  /// Gujarati script.
  gujarati,
  /// Gurmukhi script.
  gurmukhi,
  /// Hangul script (Korean).
  hangul,
  /// Han script (CJK ideographs).
  han,
  /// Hebrew script.
  hebrew,
  /// Hiragana script (Japanese).
  hiragana,
  /// Kannada script.
  kannada,
  /// Katakana script (Japanese).
  katakana,
  /// Lao script.
  lao,
  /// Latin script.
  latin,
  /// Malayalam script.
  malayalam,
  /// Oriya script.
  oriya,
  /// Tamil script.
  tamil,
  /// Telugu script.
  telugu,
  /// Thai script.
  thai,
  /// Tibetan script.
  tibetan,
  /// Bopomofo script.
  bopomofo,
  /// Braille script.
  braille,
  /// Canadian syllabics.
  canadianSyllabics,
  /// Cherokee script.
  cherokee,
  /// Ethiopic script.
  ethiopic,
  /// Khmer script.
  khmer,
  /// Mongolian script.
  mongolian,
  /// Myanmar script.
  myanmar,
  /// Ogham script.
  ogham,
  /// Runic script.
  runic,
  /// Sinhala script.
  sinhala,
  /// Syriac script.
  syriac,
  /// Thaana script.
  thaana,
  /// Yi script.
  yi,
  /// Invalid script.
  invalid,
}

/// Get ISO 15924 tag for a script.
int hbScriptToTag(HbScript script) {
  switch (script) {
    case HbScript.common: return hbTagFromString('Zyyy');
    case HbScript.inherited: return hbTagFromString('Zinh');
    case HbScript.unknown: return hbTagFromString('Zzzz');
    case HbScript.arabic: return hbTagFromString('Arab');
    case HbScript.armenian: return hbTagFromString('Armn');
    case HbScript.bengali: return hbTagFromString('Beng');
    case HbScript.cyrillic: return hbTagFromString('Cyrl');
    case HbScript.devanagari: return hbTagFromString('Deva');
    case HbScript.georgian: return hbTagFromString('Geor');
    case HbScript.greek: return hbTagFromString('Grek');
    case HbScript.gujarati: return hbTagFromString('Gujr');
    case HbScript.gurmukhi: return hbTagFromString('Guru');
    case HbScript.hangul: return hbTagFromString('Hang');
    case HbScript.han: return hbTagFromString('Hani');
    case HbScript.hebrew: return hbTagFromString('Hebr');
    case HbScript.hiragana: return hbTagFromString('Hira');
    case HbScript.kannada: return hbTagFromString('Knda');
    case HbScript.katakana: return hbTagFromString('Kana');
    case HbScript.lao: return hbTagFromString('Laoo');
    case HbScript.latin: return hbTagFromString('Latn');
    case HbScript.malayalam: return hbTagFromString('Mlym');
    case HbScript.oriya: return hbTagFromString('Orya');
    case HbScript.tamil: return hbTagFromString('Taml');
    case HbScript.telugu: return hbTagFromString('Telu');
    case HbScript.thai: return hbTagFromString('Thai');
    case HbScript.tibetan: return hbTagFromString('Tibt');
    case HbScript.bopomofo: return hbTagFromString('Bopo');
    case HbScript.braille: return hbTagFromString('Brai');
    case HbScript.canadianSyllabics: return hbTagFromString('Cans');
    case HbScript.cherokee: return hbTagFromString('Cher');
    case HbScript.ethiopic: return hbTagFromString('Ethi');
    case HbScript.khmer: return hbTagFromString('Khmr');
    case HbScript.mongolian: return hbTagFromString('Mong');
    case HbScript.myanmar: return hbTagFromString('Mymr');
    case HbScript.ogham: return hbTagFromString('Ogam');
    case HbScript.runic: return hbTagFromString('Runr');
    case HbScript.sinhala: return hbTagFromString('Sinh');
    case HbScript.syriac: return hbTagFromString('Syrc');
    case HbScript.thaana: return hbTagFromString('Thaa');
    case HbScript.yi: return hbTagFromString('Yiii');
    case HbScript.invalid: return hbTagNone;
  }
}

/// Get horizontal direction for a script.
HbDirection hbScriptGetHorizontalDirection(HbScript script) {
  switch (script) {
    case HbScript.arabic:
    case HbScript.hebrew:
    case HbScript.syriac:
    case HbScript.thaana:
      return HbDirection.rtl;
    case HbScript.mongolian:
      return HbDirection.ttb;
    default:
      return HbDirection.ltr;
  }
}

// ============================================================================
// Language
// ============================================================================

/// Language identifier (BCP 47).
class HbLanguage {
  /// The language tag string.
  final String tag;

  const HbLanguage._(this.tag);

  /// Invalid language.
  static const HbLanguage invalid = HbLanguage._('');

  /// Create language from string.
  factory HbLanguage.fromString(String str) {
    final normalized = str.toLowerCase().trim();
    if (normalized.isEmpty) return invalid;
    return HbLanguage._(normalized);
  }

  /// Check if language is valid.
  bool get isValid => tag.isNotEmpty;

  @override
  String toString() => tag;

  @override
  bool operator ==(Object other) =>
      other is HbLanguage && tag == other.tag;

  @override
  int get hashCode => tag.hashCode;
}

/// Default language.
HbLanguage hbLanguageGetDefault() {
  return HbLanguage.fromString('en');
}

// ============================================================================
// Feature
// ============================================================================

/// Global feature start position.
const int hbFeatureGlobalStart = 0;

/// Global feature end position.
const int hbFeatureGlobalEnd = 0xFFFFFFFF;

/// OpenType feature.
class HbFeature {
  /// Feature tag.
  final int tag;
  
  /// Feature value (0 = off, 1 = on, or alternates index).
  final int value;
  
  /// Start cluster (inclusive).
  final int start;
  
  /// End cluster (exclusive).
  final int end;

  const HbFeature({
    required this.tag,
    this.value = 1,
    this.start = hbFeatureGlobalStart,
    this.end = hbFeatureGlobalEnd,
  });

  /// Create feature from string (e.g., "kern", "+liga", "-calt", "aalt=2").
  factory HbFeature.fromString(String str) {
    var s = str.trim();
    var value = 1;
    
    // Check for +/- prefix
    if (s.startsWith('+')) {
      value = 1;
      s = s.substring(1);
    } else if (s.startsWith('-')) {
      value = 0;
      s = s.substring(1);
    }
    
    // Check for =value suffix
    final eqIndex = s.indexOf('=');
    if (eqIndex > 0) {
      value = int.tryParse(s.substring(eqIndex + 1)) ?? 1;
      s = s.substring(0, eqIndex);
    }
    
    // Parse tag
    final tag = hbTagFromString(s.padRight(4));
    
    return HbFeature(tag: tag, value: value);
  }

  /// Convert to string.
  String toFeatureString() {
    final tagStr = hbTagToString(tag);
    if (value == 0) return '-$tagStr';
    if (value == 1) return '+$tagStr';
    return '$tagStr=$value';
  }

  @override
  String toString() => 'HbFeature(${toFeatureString()})';
}

// ============================================================================
// Variation
// ============================================================================

/// Font variation axis.
class HbVariation {
  /// Axis tag.
  final int tag;
  
  /// Axis value.
  final double value;

  const HbVariation({
    required this.tag,
    required this.value,
  });

  /// Create variation from string (e.g., "wght=700").
  factory HbVariation.fromString(String str) {
    final parts = str.split('=');
    if (parts.length != 2) {
      return HbVariation(tag: hbTagNone, value: 0);
    }
    final tag = hbTagFromString(parts[0].trim().padRight(4));
    final value = double.tryParse(parts[1].trim()) ?? 0;
    return HbVariation(tag: tag, value: value);
  }

  /// Convert to string.
  String toVariationString() {
    return '${hbTagToString(tag)}=$value';
  }

  @override
  String toString() => 'HbVariation(${toVariationString()})';
}

// ============================================================================
// Color
// ============================================================================

/// RGBA color (8 bits per channel).
typedef HbColor = int;

/// Create a color from BGRA components.
int hbColor(int b, int g, int r, int a) {
  return ((b & 0xFF) << 24) | ((g & 0xFF) << 16) | ((r & 0xFF) << 8) | (a & 0xFF);
}

/// Get alpha component.
int hbColorGetAlpha(int color) => color & 0xFF;

/// Get red component.
int hbColorGetRed(int color) => (color >> 8) & 0xFF;

/// Get green component.
int hbColorGetGreen(int color) => (color >> 16) & 0xFF;

/// Get blue component.
int hbColorGetBlue(int color) => (color >> 24) & 0xFF;

// ============================================================================
// Glyph Extents
// ============================================================================

/// Glyph bounding box.
class HbGlyphExtents {
  /// Left bearing (x_bearing).
  HbPosition xBearing;
  
  /// Top bearing (y_bearing).
  HbPosition yBearing;
  
  /// Width.
  HbPosition width;
  
  /// Height (negative in upward-Y coordinate systems).
  HbPosition height;

  HbGlyphExtents({
    this.xBearing = 0,
    this.yBearing = 0,
    this.width = 0,
    this.height = 0,
  });

  @override
  String toString() => 
      'HbGlyphExtents($xBearing, $yBearing, $width, $height)';
}

// ============================================================================
// Common Feature Tags
// ============================================================================

/// Common OpenType feature tags.
class HbFeatureTags {
  /// Kerning
  static final int kern = hbTagFromString('kern');
  
  /// Standard ligatures
  static final int liga = hbTagFromString('liga');
  
  /// Contextual alternates
  static final int calt = hbTagFromString('calt');
  
  /// Discretionary ligatures
  static final int dlig = hbTagFromString('dlig');
  
  /// Historical ligatures
  static final int hlig = hbTagFromString('hlig');
  
  /// Contextual ligatures
  static final int clig = hbTagFromString('clig');
  
  /// Small caps
  static final int smcp = hbTagFromString('smcp');
  
  /// Capitals to small caps
  static final int c2sc = hbTagFromString('c2sc');
  
  /// Petite caps
  static final int pcap = hbTagFromString('pcap');
  
  /// Capitals to petite caps
  static final int c2pc = hbTagFromString('c2pc');
  
  /// Unicase
  static final int unic = hbTagFromString('unic');
  
  /// Titling
  static final int titl = hbTagFromString('titl');
  
  /// Lining figures
  static final int lnum = hbTagFromString('lnum');
  
  /// Oldstyle figures
  static final int onum = hbTagFromString('onum');
  
  /// Proportional figures
  static final int pnum = hbTagFromString('pnum');
  
  /// Tabular figures
  static final int tnum = hbTagFromString('tnum');
  
  /// Fractions
  static final int frac = hbTagFromString('frac');
  
  /// Alternative fractions
  static final int afrc = hbTagFromString('afrc');
  
  /// Ordinals
  static final int ordn = hbTagFromString('ordn');
  
  /// Superscript
  static final int sups = hbTagFromString('sups');
  
  /// Subscript
  static final int subs = hbTagFromString('subs');
  
  /// Scientific inferiors
  static final int sinf = hbTagFromString('sinf');
  
  /// Numerators
  static final int numr = hbTagFromString('numr');
  
  /// Denominators
  static final int dnom = hbTagFromString('dnom');
  
  /// Slashed zero
  static final int zero = hbTagFromString('zero');
  
  /// Swash
  static final int swsh = hbTagFromString('swsh');
  
  /// Contextual swash
  static final int cswh = hbTagFromString('cswh');
  
  /// Stylistic set 1
  static final int ss01 = hbTagFromString('ss01');
  
  /// Stylistic alternates
  static final int salt = hbTagFromString('salt');
  
  /// Access all alternates
  static final int aalt = hbTagFromString('aalt');
  
  /// Localized forms
  static final int locl = hbTagFromString('locl');
  
  /// Required ligatures
  static final int rlig = hbTagFromString('rlig');
  
  /// Required contextual alternates
  static final int rclt = hbTagFromString('rclt');
  
  /// Character composition/decomposition
  static final int ccmp = hbTagFromString('ccmp');
  
  /// Glyph composition/decomposition
  static final int mark = hbTagFromString('mark');
  
  /// Mark positioning
  static final int mkmk = hbTagFromString('mkmk');
}
