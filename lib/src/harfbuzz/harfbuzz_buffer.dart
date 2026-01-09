// HarfBuzz - A text shaping library
// Copyright © 1998-2004 David Turner and Werner Lemberg
// Copyright © 2004,2007,2009 Red Hat, Inc.
// Copyright © 2011,2012 Google, Inc.
// Ported to Dart

/// HarfBuzz buffer for text shaping.
library;

import 'harfbuzz_types.dart';

// ============================================================================
// Glyph Info
// ============================================================================

/// Information about a glyph in the buffer.
class HbGlyphInfo {
  /// Unicode codepoint (before shaping) or glyph index (after shaping).
  HbCodepoint codepoint;
  
  /// Mask/flags for this glyph.
  HbMask mask;
  
  /// Cluster index - relates glyph back to original character.
  int cluster;

  HbGlyphInfo({
    this.codepoint = 0,
    this.mask = 0,
    this.cluster = 0,
  });

  /// Copy the glyph info.
  HbGlyphInfo copy() => HbGlyphInfo(
    codepoint: codepoint,
    mask: mask,
    cluster: cluster,
  );

  @override
  String toString() => 'GlyphInfo($codepoint, cluster:$cluster)';
}

// ============================================================================
// Glyph Flags
// ============================================================================

/// Flags for glyphs.
class HbGlyphFlags {
  /// Unsafe to break at start of this cluster.
  static const int unsafeToBreak = 0x00000001;
  
  /// Unsafe to concatenate at start of this cluster.
  static const int unsafeToConcat = 0x00000002;
  
  /// Safe to insert tatweel before this cluster.
  static const int safeToInsertTatweel = 0x00000004;
  
  /// All defined flags.
  static const int defined = 0x00000007;
}

/// Get glyph flags from info.
int hbGlyphInfoGetFlags(HbGlyphInfo info) {
  return info.mask & HbGlyphFlags.defined;
}

// ============================================================================
// Glyph Position
// ============================================================================

/// Position information for a glyph.
class HbGlyphPosition {
  /// Horizontal advance after drawing this glyph.
  HbPosition xAdvance;
  
  /// Vertical advance after drawing this glyph.
  HbPosition yAdvance;
  
  /// Horizontal offset before drawing.
  HbPosition xOffset;
  
  /// Vertical offset before drawing.
  HbPosition yOffset;

  HbGlyphPosition({
    this.xAdvance = 0,
    this.yAdvance = 0,
    this.xOffset = 0,
    this.yOffset = 0,
  });

  /// Copy the position.
  HbGlyphPosition copy() => HbGlyphPosition(
    xAdvance: xAdvance,
    yAdvance: yAdvance,
    xOffset: xOffset,
    yOffset: yOffset,
  );

  @override
  String toString() => 'GlyphPos(adv:$xAdvance,$yAdvance off:$xOffset,$yOffset)';
}

// ============================================================================
// Segment Properties
// ============================================================================

/// Text segment properties.
class HbSegmentProperties {
  /// Text direction.
  HbDirection direction;
  
  /// Script.
  HbScript script;
  
  /// Language.
  HbLanguage language;

  HbSegmentProperties({
    this.direction = HbDirection.invalid,
    this.script = HbScript.invalid,
    HbLanguage? language,
  }) : language = language ?? HbLanguage.invalid;

  /// Copy the properties.
  HbSegmentProperties copy() => HbSegmentProperties(
    direction: direction,
    script: script,
    language: language,
  );

  /// Default segment properties.
  static HbSegmentProperties get defaultProps => HbSegmentProperties(
    direction: HbDirection.invalid,
    script: HbScript.invalid,
    language: HbLanguage.invalid,
  );

  @override
  bool operator ==(Object other) =>
      other is HbSegmentProperties &&
      direction == other.direction &&
      script == other.script &&
      language == other.language;

  @override
  int get hashCode => Object.hash(direction, script, language);
}

// ============================================================================
// Buffer Content Type
// ============================================================================

/// Type of content in the buffer.
enum HbBufferContentType {
  /// Invalid/empty content.
  invalid,
  /// Unicode codepoints (before shaping).
  unicode,
  /// Glyph indices (after shaping).
  glyphs,
}

// ============================================================================
// Buffer Flags
// ============================================================================

/// Buffer flags.
class HbBufferFlags {
  /// Default behavior.
  static const int defaultFlag = 0x00000000;
  
  /// Mark buffer beginning-of-text.
  static const int bot = 0x00000001;
  
  /// Mark buffer end-of-text.
  static const int eot = 0x00000002;
  
  /// Preserve default ignorables.
  static const int preserveDefaultIgnorables = 0x00000004;
  
  /// Remove default ignorables.
  static const int removeDefaultIgnorables = 0x00000008;
  
  /// Don't insert dotted circle for invalid sequences.
  static const int doNotInsertDottedCircle = 0x00000010;
  
  /// Verify correctness after shaping.
  static const int verify = 0x00000020;
  
  /// Produce unsafe-to-concat glyph flag.
  static const int produceUnsafeToConcat = 0x00000040;
  
  /// Produce safe-to-insert-tatweel glyph flag.
  static const int produceSafeToInsertTatweel = 0x00000080;
  
  /// All defined flags.
  static const int defined = 0x000000FF;
}

// ============================================================================
// Cluster Level
// ============================================================================

/// Cluster handling level.
enum HbBufferClusterLevel {
  /// Monotone graphemes (default).
  monotoneGraphemes,
  /// Monotone characters.
  monotoneCharacters,
  /// Characters.
  characters,
}

// ============================================================================
// Buffer
// ============================================================================

/// Text buffer for shaping operations.
class HbBuffer {
  /// Glyph information array.
  final List<HbGlyphInfo> _info = [];
  
  /// Glyph position array.
  final List<HbGlyphPosition> _pos = [];
  
  /// Content type.
  HbBufferContentType _contentType = HbBufferContentType.invalid;
  
  /// Segment properties.
  final HbSegmentProperties _props = HbSegmentProperties();
  
  /// Buffer flags.
  int _flags = HbBufferFlags.defaultFlag;
  
  /// Cluster level.
  HbBufferClusterLevel _clusterLevel = HbBufferClusterLevel.monotoneGraphemes;
  
  /// Replacement codepoint for invalid sequences.
  HbCodepoint _replacementCodepoint = 0xFFFD;
  
  /// Invisible glyph.
  HbCodepoint _invisibleGlyph = 0;

  HbBuffer();

  /// Create empty buffer.
  factory HbBuffer.empty() => HbBuffer();

  // Properties

  /// Get content type.
  HbBufferContentType get contentType => _contentType;
  
  /// Set content type.
  set contentType(HbBufferContentType type) => _contentType = type;

  /// Get direction.
  HbDirection get direction => _props.direction;
  
  /// Set direction.
  set direction(HbDirection dir) => _props.direction = dir;

  /// Get script.
  HbScript get script => _props.script;
  
  /// Set script.
  set script(HbScript s) => _props.script = s;

  /// Get language.
  HbLanguage get language => _props.language;
  
  /// Set language.
  set language(HbLanguage lang) => _props.language = lang;

  /// Get segment properties.
  HbSegmentProperties get segmentProperties => _props.copy();
  
  /// Set segment properties.
  set segmentProperties(HbSegmentProperties props) {
    _props.direction = props.direction;
    _props.script = props.script;
    _props.language = props.language;
  }

  /// Get flags.
  int get flags => _flags;
  
  /// Set flags.
  set flags(int f) => _flags = f;

  /// Get cluster level.
  HbBufferClusterLevel get clusterLevel => _clusterLevel;
  
  /// Set cluster level.
  set clusterLevel(HbBufferClusterLevel level) => _clusterLevel = level;

  /// Get replacement codepoint.
  HbCodepoint get replacementCodepoint => _replacementCodepoint;
  
  /// Set replacement codepoint.
  set replacementCodepoint(HbCodepoint cp) => _replacementCodepoint = cp;

  /// Get invisible glyph.
  HbCodepoint get invisibleGlyph => _invisibleGlyph;
  
  /// Set invisible glyph.
  set invisibleGlyph(HbCodepoint glyph) => _invisibleGlyph = glyph;

  /// Get length (number of glyphs/codepoints).
  int get length => _info.length;

  /// Get glyph info array (read-only).
  List<HbGlyphInfo> get glyphInfos => List.unmodifiable(_info);

  /// Get glyph position array (read-only).
  List<HbGlyphPosition> get glyphPositions => List.unmodifiable(_pos);

  // Operations

  /// Reset buffer to empty state.
  void reset() {
    _info.clear();
    _pos.clear();
    _contentType = HbBufferContentType.invalid;
    _props.direction = HbDirection.invalid;
    _props.script = HbScript.invalid;
    _props.language = HbLanguage.invalid;
    _flags = HbBufferFlags.defaultFlag;
    _clusterLevel = HbBufferClusterLevel.monotoneGraphemes;
  }

  /// Clear contents but keep settings.
  void clearContents() {
    _info.clear();
    _pos.clear();
    _contentType = HbBufferContentType.invalid;
  }

  /// Pre-allocate space for glyphs.
  void preAllocate(int size) {
    // Dart lists grow automatically, this is a no-op hint
  }

  /// Add a single codepoint.
  void add(HbCodepoint codepoint, int cluster) {
    _info.add(HbGlyphInfo(codepoint: codepoint, cluster: cluster));
    _pos.add(HbGlyphPosition());
    _contentType = HbBufferContentType.unicode;
  }

  /// Add codepoints from array.
  void addCodepoints(List<HbCodepoint> codepoints, int itemOffset, int itemLength) {
    final end = (itemLength < 0) 
        ? codepoints.length 
        : (itemOffset + itemLength).clamp(0, codepoints.length);
    
    for (var i = itemOffset; i < end; i++) {
      add(codepoints[i], i);
    }
  }

  /// Add UTF-8 text.
  void addUtf8(String text, {int textOffset = 0, int textLength = -1}) {
    final codepoints = text.runes.toList();
    final start = textOffset.clamp(0, codepoints.length);
    final length = textLength < 0 
        ? codepoints.length - start 
        : textLength;
    addCodepoints(codepoints, start, length);
  }

  /// Add UTF-16 text.
  void addUtf16(List<int> text, {int textOffset = 0, int textLength = -1}) {
    // Convert UTF-16 to codepoints
    final codepoints = <int>[];
    var i = textOffset;
    final end = textLength < 0 ? text.length : (textOffset + textLength);
    
    while (i < end) {
      final unit = text[i];
      if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < end) {
        // High surrogate
        final low = text[i + 1];
        if (low >= 0xDC00 && low <= 0xDFFF) {
          // Valid surrogate pair
          codepoints.add(0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00));
          i += 2;
          continue;
        }
      }
      codepoints.add(unit);
      i++;
    }
    
    addCodepoints(codepoints, 0, codepoints.length);
  }

  /// Add UTF-32 text (just codepoints).
  void addUtf32(List<int> text, {int textOffset = 0, int textLength = -1}) {
    addCodepoints(text, textOffset, textLength);
  }

  /// Guess segment properties from buffer content.
  void guessSegmentProperties() {
    if (_props.script == HbScript.invalid && _info.isNotEmpty) {
      // Simple script detection - just use first non-common codepoint
      for (final info in _info) {
        final script = _guessScript(info.codepoint);
        if (script != HbScript.common && script != HbScript.inherited) {
          _props.script = script;
          break;
        }
      }
      if (_props.script == HbScript.invalid) {
        _props.script = HbScript.common;
      }
    }
    
    if (_props.direction == HbDirection.invalid) {
      _props.direction = hbScriptGetHorizontalDirection(_props.script);
    }
    
    if (!_props.language.isValid) {
      _props.language = hbLanguageGetDefault();
    }
  }

  /// Reverse the buffer.
  void reverse() {
    final n = _info.length;
    for (var i = 0; i < n ~/ 2; i++) {
      final j = n - 1 - i;
      final tmpInfo = _info[i];
      _info[i] = _info[j];
      _info[j] = tmpInfo;
      final tmpPos = _pos[i];
      _pos[i] = _pos[j];
      _pos[j] = tmpPos;
    }
  }

  /// Reverse clusters.
  void reverseClusters() {
    reverse();
    
    // Then reverse within each cluster
    var start = 0;
    var cluster = _info.isNotEmpty ? _info[0].cluster : 0;
    
    for (var i = 1; i <= _info.length; i++) {
      if (i == _info.length || _info[i].cluster != cluster) {
        // Reverse [start, i)
        _reverseRange(start, i);
        start = i;
        if (i < _info.length) {
          cluster = _info[i].cluster;
        }
      }
    }
  }

  void _reverseRange(int start, int end) {
    while (start < end - 1) {
      final tmpInfo = _info[start];
      _info[start] = _info[end - 1];
      _info[end - 1] = tmpInfo;
      final tmpPos = _pos[start];
      _pos[start] = _pos[end - 1];
      _pos[end - 1] = tmpPos;
      start++;
      end--;
    }
  }

  /// Normalize glyphs for uniform cluster handling.
  void normalizeGlyphs() {
    // Sort by cluster then by index within cluster
    // This ensures consistent ordering
    if (_info.isEmpty) return;
    
    final indices = List<int>.generate(_info.length, (i) => i);
    indices.sort((a, b) {
      final cmp = _info[a].cluster.compareTo(_info[b].cluster);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
    
    final newInfo = <HbGlyphInfo>[];
    final newPos = <HbGlyphPosition>[];
    for (final i in indices) {
      newInfo.add(_info[i]);
      newPos.add(_pos[i]);
    }
    
    _info.clear();
    _info.addAll(newInfo);
    _pos.clear();
    _pos.addAll(newPos);
  }

  /// Get glyph info at index.
  HbGlyphInfo getGlyphInfo(int index) {
    if (index < 0 || index >= _info.length) {
      return HbGlyphInfo();
    }
    return _info[index];
  }

  /// Get glyph position at index.
  HbGlyphPosition getGlyphPosition(int index) {
    if (index < 0 || index >= _pos.length) {
      return HbGlyphPosition();
    }
    return _pos[index];
  }

  /// Set glyph info at index.
  void setGlyphInfo(int index, HbGlyphInfo info) {
    if (index >= 0 && index < _info.length) {
      _info[index] = info;
    }
  }

  /// Set glyph position at index.
  void setGlyphPosition(int index, HbGlyphPosition pos) {
    if (index >= 0 && index < _pos.length) {
      _pos[index] = pos;
    }
  }

  /// Simple script guessing from codepoint.
  HbScript _guessScript(int codepoint) {
    // Basic Unicode block detection
    if (codepoint >= 0x0000 && codepoint <= 0x007F) return HbScript.latin;
    if (codepoint >= 0x0080 && codepoint <= 0x00FF) return HbScript.latin;
    if (codepoint >= 0x0100 && codepoint <= 0x017F) return HbScript.latin;
    if (codepoint >= 0x0180 && codepoint <= 0x024F) return HbScript.latin;
    if (codepoint >= 0x0370 && codepoint <= 0x03FF) return HbScript.greek;
    if (codepoint >= 0x0400 && codepoint <= 0x04FF) return HbScript.cyrillic;
    if (codepoint >= 0x0500 && codepoint <= 0x052F) return HbScript.cyrillic;
    if (codepoint >= 0x0530 && codepoint <= 0x058F) return HbScript.armenian;
    if (codepoint >= 0x0590 && codepoint <= 0x05FF) return HbScript.hebrew;
    if (codepoint >= 0x0600 && codepoint <= 0x06FF) return HbScript.arabic;
    if (codepoint >= 0x0700 && codepoint <= 0x074F) return HbScript.syriac;
    if (codepoint >= 0x0780 && codepoint <= 0x07BF) return HbScript.thaana;
    if (codepoint >= 0x0900 && codepoint <= 0x097F) return HbScript.devanagari;
    if (codepoint >= 0x0980 && codepoint <= 0x09FF) return HbScript.bengali;
    if (codepoint >= 0x0A00 && codepoint <= 0x0A7F) return HbScript.gurmukhi;
    if (codepoint >= 0x0A80 && codepoint <= 0x0AFF) return HbScript.gujarati;
    if (codepoint >= 0x0B00 && codepoint <= 0x0B7F) return HbScript.oriya;
    if (codepoint >= 0x0B80 && codepoint <= 0x0BFF) return HbScript.tamil;
    if (codepoint >= 0x0C00 && codepoint <= 0x0C7F) return HbScript.telugu;
    if (codepoint >= 0x0C80 && codepoint <= 0x0CFF) return HbScript.kannada;
    if (codepoint >= 0x0D00 && codepoint <= 0x0D7F) return HbScript.malayalam;
    if (codepoint >= 0x0D80 && codepoint <= 0x0DFF) return HbScript.sinhala;
    if (codepoint >= 0x0E00 && codepoint <= 0x0E7F) return HbScript.thai;
    if (codepoint >= 0x0E80 && codepoint <= 0x0EFF) return HbScript.lao;
    if (codepoint >= 0x0F00 && codepoint <= 0x0FFF) return HbScript.tibetan;
    if (codepoint >= 0x1000 && codepoint <= 0x109F) return HbScript.myanmar;
    if (codepoint >= 0x10A0 && codepoint <= 0x10FF) return HbScript.georgian;
    if (codepoint >= 0x1100 && codepoint <= 0x11FF) return HbScript.hangul;
    if (codepoint >= 0x1200 && codepoint <= 0x137F) return HbScript.ethiopic;
    if (codepoint >= 0x13A0 && codepoint <= 0x13FF) return HbScript.cherokee;
    if (codepoint >= 0x1400 && codepoint <= 0x167F) return HbScript.canadianSyllabics;
    if (codepoint >= 0x1680 && codepoint <= 0x169F) return HbScript.ogham;
    if (codepoint >= 0x16A0 && codepoint <= 0x16FF) return HbScript.runic;
    if (codepoint >= 0x1780 && codepoint <= 0x17FF) return HbScript.khmer;
    if (codepoint >= 0x1800 && codepoint <= 0x18AF) return HbScript.mongolian;
    if (codepoint >= 0x3040 && codepoint <= 0x309F) return HbScript.hiragana;
    if (codepoint >= 0x30A0 && codepoint <= 0x30FF) return HbScript.katakana;
    if (codepoint >= 0x3100 && codepoint <= 0x312F) return HbScript.bopomofo;
    if (codepoint >= 0x3130 && codepoint <= 0x318F) return HbScript.hangul;
    if (codepoint >= 0x4E00 && codepoint <= 0x9FFF) return HbScript.han;
    if (codepoint >= 0xA000 && codepoint <= 0xA4CF) return HbScript.yi;
    if (codepoint >= 0xAC00 && codepoint <= 0xD7AF) return HbScript.hangul;
    if (codepoint >= 0x2800 && codepoint <= 0x28FF) return HbScript.braille;
    
    return HbScript.common;
  }

  @override
  String toString() => 'HbBuffer($length glyphs, $_contentType)';
}
