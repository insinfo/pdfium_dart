// HarfBuzz - A text shaping library
// Copyright © 2007,2008,2009 Red Hat, Inc.
// Copyright © 2011,2012 Google, Inc.
// Ported to Dart

/// HarfBuzz font and face abstraction.
library;

import 'harfbuzz_types.dart';
import 'harfbuzz_buffer.dart';

// ============================================================================
// Font Functions (Callbacks)
// ============================================================================

/// Callback to get nominal glyph for a codepoint.
typedef HbFontGetNominalGlyphFunc = HbCodepoint? Function(
  HbFont font,
  HbCodepoint unicode,
);

/// Callback to get glyph for a codepoint with variation selector.
typedef HbFontGetVariationGlyphFunc = HbCodepoint? Function(
  HbFont font,
  HbCodepoint unicode,
  HbCodepoint variationSelector,
);

/// Callback to get glyph horizontal advance.
typedef HbFontGetGlyphHAdvanceFunc = HbPosition Function(
  HbFont font,
  HbCodepoint glyph,
);

/// Callback to get glyph vertical advance.
typedef HbFontGetGlyphVAdvanceFunc = HbPosition Function(
  HbFont font,
  HbCodepoint glyph,
);

/// Callback to get glyph horizontal origin.
typedef HbFontGetGlyphHOriginFunc = ({HbPosition x, HbPosition y})? Function(
  HbFont font,
  HbCodepoint glyph,
);

/// Callback to get glyph vertical origin.
typedef HbFontGetGlyphVOriginFunc = ({HbPosition x, HbPosition y})? Function(
  HbFont font,
  HbCodepoint glyph,
);

/// Callback to get horizontal kerning.
typedef HbFontGetGlyphHKerningFunc = HbPosition Function(
  HbFont font,
  HbCodepoint firstGlyph,
  HbCodepoint secondGlyph,
);

/// Callback to get glyph extents.
typedef HbFontGetGlyphExtentsFunc = HbGlyphExtents? Function(
  HbFont font,
  HbCodepoint glyph,
);

/// Callback to get glyph contour point.
typedef HbFontGetGlyphContourPointFunc = ({HbPosition x, HbPosition y})? Function(
  HbFont font,
  HbCodepoint glyph,
  int pointIndex,
);

/// Callback to get glyph name.
typedef HbFontGetGlyphNameFunc = String? Function(
  HbFont font,
  HbCodepoint glyph,
);

/// Callback to get glyph from name.
typedef HbFontGetGlyphFromNameFunc = HbCodepoint? Function(
  HbFont font,
  String name,
);

// ============================================================================
// Font Functions Set
// ============================================================================

/// Collection of font callback functions.
class HbFontFuncs {
  /// Get nominal glyph.
  HbFontGetNominalGlyphFunc? getNominalGlyph;
  
  /// Get variation glyph.
  HbFontGetVariationGlyphFunc? getVariationGlyph;
  
  /// Get horizontal advance.
  HbFontGetGlyphHAdvanceFunc? getGlyphHAdvance;
  
  /// Get vertical advance.
  HbFontGetGlyphVAdvanceFunc? getGlyphVAdvance;
  
  /// Get horizontal origin.
  HbFontGetGlyphHOriginFunc? getGlyphHOrigin;
  
  /// Get vertical origin.
  HbFontGetGlyphVOriginFunc? getGlyphVOrigin;
  
  /// Get horizontal kerning.
  HbFontGetGlyphHKerningFunc? getGlyphHKerning;
  
  /// Get glyph extents.
  HbFontGetGlyphExtentsFunc? getGlyphExtents;
  
  /// Get contour point.
  HbFontGetGlyphContourPointFunc? getGlyphContourPoint;
  
  /// Get glyph name.
  HbFontGetGlyphNameFunc? getGlyphName;
  
  /// Get glyph from name.
  HbFontGetGlyphFromNameFunc? getGlyphFromName;

  HbFontFuncs();

  /// Create empty font functions.
  factory HbFontFuncs.empty() => HbFontFuncs();
}

// ============================================================================
// Face
// ============================================================================

/// Font face - represents the data from a font file.
class HbFace {
  /// Font data (raw bytes).
  final List<int>? _data;
  
  /// Face index in the font file.
  final int index;
  
  /// Number of glyphs.
  int _numGlyphs = 0;
  
  /// Units per EM.
  int _upem = 1000;
  
  /// Tables in the face.
  final Map<int, List<int>> _tables = {};

  HbFace._({
    List<int>? data,
    this.index = 0,
  }) : _data = data;

  /// Create an empty face.
  factory HbFace.empty() => HbFace._();

  /// Create a face from font data.
  factory HbFace.fromData(List<int> data, {int index = 0}) {
    return HbFace._(data: data, index: index);
  }

  /// Get number of glyphs.
  int get glyphCount => _numGlyphs;
  
  /// Set number of glyphs.
  set glyphCount(int count) => _numGlyphs = count;

  /// Get units per EM.
  int get upem => _upem;
  
  /// Set units per EM.
  set upem(int value) => _upem = value > 0 ? value : 1000;

  /// Get a table from the face.
  List<int>? getTable(int tag) {
    return _tables[tag];
  }

  /// Set a table in the face.
  void setTable(int tag, List<int> data) {
    _tables[tag] = data;
  }

  /// Check if face has a table.
  bool hasTable(int tag) => _tables.containsKey(tag);

  /// Get all table tags.
  List<int> get tableTags => _tables.keys.toList();

  @override
  String toString() => 'HbFace(index:$index, glyphs:$_numGlyphs, upem:$_upem)';
}

// ============================================================================
// Font
// ============================================================================

/// Font - represents a face at a specific size.
class HbFont {
  /// Parent font (for sub-fonts).
  HbFont? parent;
  
  /// The face this font is based on.
  final HbFace face;
  
  /// Font functions.
  HbFontFuncs funcs = HbFontFuncs();
  
  /// X scale factor.
  int _xScale = 0;
  
  /// Y scale factor.
  int _yScale = 0;
  
  /// X ppem.
  int _xPpem = 0;
  
  /// Y ppem.
  int _yPpem = 0;
  
  /// Point size (26.6 fixed-point).
  int _ptem = 0;
  
  /// Variations.
  final List<HbVariation> _variations = [];
  
  /// Synthetic slant ratio.
  double _syntheticSlant = 0.0;

  HbFont._(this.face);

  /// Create a font from a face.
  factory HbFont.fromFace(HbFace face) {
    final font = HbFont._(face);
    font._xScale = face.upem;
    font._yScale = face.upem;
    return font;
  }

  /// Create empty font.
  factory HbFont.empty() => HbFont._(HbFace.empty());

  /// Create a sub-font.
  HbFont createSubFont() {
    final sub = HbFont._(face);
    sub.parent = this;
    sub._xScale = _xScale;
    sub._yScale = _yScale;
    sub._xPpem = _xPpem;
    sub._yPpem = _yPpem;
    sub._ptem = _ptem;
    sub.funcs = funcs;
    return sub;
  }

  // Scale

  /// Get X scale.
  int get xScale => _xScale;
  
  /// Set X scale.
  set xScale(int scale) => _xScale = scale;

  /// Get Y scale.
  int get yScale => _yScale;
  
  /// Set Y scale.
  set yScale(int scale) => _yScale = scale;

  /// Set both scales.
  void setScale(int xScale, int yScale) {
    _xScale = xScale;
    _yScale = yScale;
  }

  // Ppem (pixels per EM)

  /// Get X ppem.
  int get xPpem => _xPpem;
  
  /// Set X ppem.
  set xPpem(int ppem) => _xPpem = ppem;

  /// Get Y ppem.
  int get yPpem => _yPpem;
  
  /// Set Y ppem.
  set yPpem(int ppem) => _yPpem = ppem;

  /// Set both ppem values.
  void setPpem(int xPpem, int yPpem) {
    _xPpem = xPpem;
    _yPpem = yPpem;
  }

  /// Get point size (26.6).
  int get ptem => _ptem;
  
  /// Set point size (26.6).
  set ptem(int size) => _ptem = size;

  /// Get synthetic slant.
  double get syntheticSlant => _syntheticSlant;
  
  /// Set synthetic slant.
  set syntheticSlant(double slant) => _syntheticSlant = slant;

  // Variations

  /// Set font variations.
  void setVariations(List<HbVariation> variations) {
    _variations.clear();
    _variations.addAll(variations);
  }

  /// Get font variations.
  List<HbVariation> get variations => List.unmodifiable(_variations);

  // Glyph methods

  /// Get nominal glyph for Unicode codepoint.
  HbCodepoint? getGlyph(HbCodepoint unicode) {
    if (funcs.getNominalGlyph != null) {
      return funcs.getNominalGlyph!(this, unicode);
    }
    return parent?.getGlyph(unicode);
  }

  /// Get variation glyph.
  HbCodepoint? getVariationGlyph(HbCodepoint unicode, HbCodepoint variationSelector) {
    if (funcs.getVariationGlyph != null) {
      return funcs.getVariationGlyph!(this, unicode, variationSelector);
    }
    return parent?.getVariationGlyph(unicode, variationSelector);
  }

  /// Get horizontal advance for glyph.
  HbPosition getGlyphHAdvance(HbCodepoint glyph) {
    if (funcs.getGlyphHAdvance != null) {
      return funcs.getGlyphHAdvance!(this, glyph);
    }
    return parent?.getGlyphHAdvance(glyph) ?? face.upem;
  }

  /// Get vertical advance for glyph.
  HbPosition getGlyphVAdvance(HbCodepoint glyph) {
    if (funcs.getGlyphVAdvance != null) {
      return funcs.getGlyphVAdvance!(this, glyph);
    }
    return parent?.getGlyphVAdvance(glyph) ?? face.upem;
  }

  /// Get horizontal advances for multiple glyphs.
  List<HbPosition> getGlyphHAdvances(List<HbCodepoint> glyphs) {
    return glyphs.map((g) => getGlyphHAdvance(g)).toList();
  }

  /// Get vertical advances for multiple glyphs.
  List<HbPosition> getGlyphVAdvances(List<HbCodepoint> glyphs) {
    return glyphs.map((g) => getGlyphVAdvance(g)).toList();
  }

  /// Get horizontal origin for glyph.
  ({HbPosition x, HbPosition y})? getGlyphHOrigin(HbCodepoint glyph) {
    if (funcs.getGlyphHOrigin != null) {
      return funcs.getGlyphHOrigin!(this, glyph);
    }
    return parent?.getGlyphHOrigin(glyph) ?? (x: 0, y: 0);
  }

  /// Get vertical origin for glyph.
  ({HbPosition x, HbPosition y})? getGlyphVOrigin(HbCodepoint glyph) {
    if (funcs.getGlyphVOrigin != null) {
      return funcs.getGlyphVOrigin!(this, glyph);
    }
    return parent?.getGlyphVOrigin(glyph);
  }

  /// Get horizontal kerning.
  HbPosition getGlyphHKerning(HbCodepoint first, HbCodepoint second) {
    if (funcs.getGlyphHKerning != null) {
      return funcs.getGlyphHKerning!(this, first, second);
    }
    return parent?.getGlyphHKerning(first, second) ?? 0;
  }

  /// Get glyph extents.
  HbGlyphExtents? getGlyphExtents(HbCodepoint glyph) {
    if (funcs.getGlyphExtents != null) {
      return funcs.getGlyphExtents!(this, glyph);
    }
    return parent?.getGlyphExtents(glyph);
  }

  /// Get glyph contour point.
  ({HbPosition x, HbPosition y})? getGlyphContourPoint(
    HbCodepoint glyph, 
    int pointIndex,
  ) {
    if (funcs.getGlyphContourPoint != null) {
      return funcs.getGlyphContourPoint!(this, glyph, pointIndex);
    }
    return parent?.getGlyphContourPoint(glyph, pointIndex);
  }

  /// Get glyph name.
  String? getGlyphName(HbCodepoint glyph) {
    if (funcs.getGlyphName != null) {
      return funcs.getGlyphName!(this, glyph);
    }
    return parent?.getGlyphName(glyph);
  }

  /// Get glyph from name.
  HbCodepoint? getGlyphFromName(String name) {
    if (funcs.getGlyphFromName != null) {
      return funcs.getGlyphFromName!(this, name);
    }
    return parent?.getGlyphFromName(name);
  }

  // Scaling helpers

  /// Scale X value from font units.
  HbPosition scaleX(int value) {
    if (_xScale == 0 || face.upem == 0) return value;
    return (value * _xScale) ~/ face.upem;
  }

  /// Scale Y value from font units.
  HbPosition scaleY(int value) {
    if (_yScale == 0 || face.upem == 0) return value;
    return (value * _yScale) ~/ face.upem;
  }

  /// Unscale X value to font units.
  int unscaleX(HbPosition value) {
    if (_xScale == 0) return value;
    return (value * face.upem) ~/ _xScale;
  }

  /// Unscale Y value to font units.
  int unscaleY(HbPosition value) {
    if (_yScale == 0) return value;
    return (value * face.upem) ~/ _yScale;
  }

  @override
  String toString() => 'HbFont(scale:$_xScale x $_yScale, ppem:$_xPpem x $_yPpem)';
}

// ============================================================================
// Font Extents
// ============================================================================

/// Font-wide metrics.
class HbFontExtents {
  /// Ascender.
  HbPosition ascender;
  
  /// Descender.
  HbPosition descender;
  
  /// Line gap.
  HbPosition lineGap;

  HbFontExtents({
    this.ascender = 0,
    this.descender = 0,
    this.lineGap = 0,
  });

  @override
  String toString() => 'HbFontExtents(asc:$ascender, desc:$descender, gap:$lineGap)';
}

/// Get horizontal font extents.
HbFontExtents? hbFontGetHExtents(HbFont font) {
  // Would normally come from font tables
  return HbFontExtents(
    ascender: font.face.upem * 8 ~/ 10,
    descender: -font.face.upem * 2 ~/ 10,
    lineGap: 0,
  );
}

/// Get vertical font extents.
HbFontExtents? hbFontGetVExtents(HbFont font) {
  return HbFontExtents(
    ascender: font.face.upem ~/ 2,
    descender: -font.face.upem ~/ 2,
    lineGap: 0,
  );
}
