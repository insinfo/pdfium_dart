// FreeType 2 - A high-quality font engine
// Copyright (C) 1996-2025 by David Turner, Robert Wilhelm, and Werner Lemberg.
// Ported to Dart
//
// This file is part of the FreeType project, and may only be used,
// modified, and distributed under the terms of the FreeType project
// license.

/// FreeType font face, size, and glyph slot structures.
library;

import 'dart:typed_data';
import 'freetype_types.dart';
import 'freetype_outline.dart';

// ============================================================================
// Encoding Types
// ============================================================================

/// Character encoding types.
enum FtEncoding {
  /// No encoding specified.
  none,
  /// Unicode encoding.
  unicode,
  /// Microsoft Symbol encoding.
  msSymbol,
  /// Shift JIS encoding.
  sjis,
  /// Simplified Chinese (PRC).
  prc,
  /// Traditional Chinese (Big5).
  big5,
  /// Korean Wansung.
  wansung,
  /// Korean Johab.
  johab,
  /// Adobe Standard encoding.
  adobeStandard,
  /// Adobe Expert encoding.
  adobeExpert,
  /// Adobe Custom encoding.
  adobeCustom,
  /// Adobe Latin-1 encoding.
  adobeLatin1,
  /// Apple Roman encoding.
  appleRoman,
}

// ============================================================================
// Face Flags
// ============================================================================

/// Flags indicating face properties.
class FtFaceFlags {
  /// Face has horizontal metrics.
  static const int horizontal = 1 << 0;
  
  /// Face has vertical metrics.
  static const int vertical = 1 << 1;
  
  /// Face has kerning information.
  static const int kerning = 1 << 2;
  
  /// Face is scalable.
  static const int scalable = 1 << 3;
  
  /// Face has bitmap strikes.
  static const int fixedSizes = 1 << 4;
  
  /// Face has fixed-width glyphs.
  static const int fixedWidth = 1 << 5;
  
  /// Face is SFNT-based (TrueType/OpenType).
  static const int sfnt = 1 << 6;
  
  /// Face has horizontal glyph names.
  static const int glyphNames = 1 << 7;
  
  /// Face is CID-keyed.
  static const int cidKeyed = 1 << 8;
  
  /// Face is a "tricky" font.
  static const int tricky = 1 << 9;
  
  /// Face has color glyphs.
  static const int color = 1 << 10;
  
  /// Face has variations.
  static const int variation = 1 << 11;
  
  /// Face has SVG glyphs.
  static const int svg = 1 << 12;
  
  /// Face has sbix bitmaps.
  static const int sbix = 1 << 13;
  
  /// Face has sbix overlay.
  static const int sbixOverlay = 1 << 14;
}

/// Flags indicating style properties.
class FtStyleFlags {
  /// Italic style.
  static const int italic = 1 << 0;
  
  /// Bold style.
  static const int bold = 1 << 1;
}

// ============================================================================
// Glyph Metrics
// ============================================================================

/// Metrics for a single glyph.
class FtGlyphMetrics {
  /// Glyph width in 26.6 fractional pixels (or font units if no scaling).
  FtPos width;
  
  /// Glyph height in 26.6 fractional pixels.
  FtPos height;
  
  /// Left side bearing for horizontal layout.
  FtPos horiBearingX;
  
  /// Top side bearing for horizontal layout.
  FtPos horiBearingY;
  
  /// Advance width for horizontal layout.
  FtPos horiAdvance;
  
  /// Left side bearing for vertical layout.
  FtPos vertBearingX;
  
  /// Top side bearing for vertical layout.
  FtPos vertBearingY;
  
  /// Advance height for vertical layout.
  FtPos vertAdvance;

  FtGlyphMetrics({
    this.width = 0,
    this.height = 0,
    this.horiBearingX = 0,
    this.horiBearingY = 0,
    this.horiAdvance = 0,
    this.vertBearingX = 0,
    this.vertBearingY = 0,
    this.vertAdvance = 0,
  });

  /// Copy the metrics.
  FtGlyphMetrics copy() {
    return FtGlyphMetrics(
      width: width,
      height: height,
      horiBearingX: horiBearingX,
      horiBearingY: horiBearingY,
      horiAdvance: horiAdvance,
      vertBearingX: vertBearingX,
      vertBearingY: vertBearingY,
      vertAdvance: vertAdvance,
    );
  }

  @override
  String toString() => 'FtGlyphMetrics(w:$width, h:$height, adv:$horiAdvance)';
}

// ============================================================================
// Size Metrics
// ============================================================================

/// Metrics for a font size.
class FtSizeMetrics {
  /// Horizontal pixels per EM in 26.6 format.
  int xPpem;
  
  /// Vertical pixels per EM in 26.6 format.
  int yPpem;
  
  /// Horizontal scale factor (16.16 fixed-point).
  FtFixed xScale;
  
  /// Vertical scale factor (16.16 fixed-point).
  FtFixed yScale;
  
  /// Ascender in 26.6 fractional pixels.
  FtPos ascender;
  
  /// Descender in 26.6 fractional pixels.
  FtPos descender;
  
  /// Text height in 26.6 fractional pixels.
  FtPos height;
  
  /// Maximum advance width in 26.6 fractional pixels.
  FtPos maxAdvance;

  FtSizeMetrics({
    this.xPpem = 0,
    this.yPpem = 0,
    this.xScale = 0,
    this.yScale = 0,
    this.ascender = 0,
    this.descender = 0,
    this.height = 0,
    this.maxAdvance = 0,
  });

  @override
  String toString() => 'FtSizeMetrics(${xPpem}x$yPpem, h:$height)';
}

// ============================================================================
// Bitmap Size (for bitmap strikes)
// ============================================================================

/// Information about a bitmap strike.
class FtBitmapSize {
  /// Vertical distance between baselines in pixels.
  int height;
  
  /// Average glyph width in pixels.
  int width;
  
  /// Nominal size in 26.6 fractional points.
  FtPos size;
  
  /// Horizontal ppem in 26.6 fractional pixels.
  FtPos xPpem;
  
  /// Vertical ppem in 26.6 fractional pixels.
  FtPos yPpem;

  FtBitmapSize({
    this.height = 0,
    this.width = 0,
    this.size = 0,
    this.xPpem = 0,
    this.yPpem = 0,
  });
}

// ============================================================================
// Character Map
// ============================================================================

/// Character map for mapping character codes to glyph indices.
class FtCharMap {
  /// Encoding type.
  FtEncoding encoding;
  
  /// Platform ID (from TrueType spec).
  int platformId;
  
  /// Platform-specific encoding ID.
  int encodingId;

  FtCharMap({
    this.encoding = FtEncoding.none,
    this.platformId = 0,
    this.encodingId = 0,
  });

  @override
  String toString() => 'FtCharMap($encoding, plat:$platformId, enc:$encodingId)';
}

// ============================================================================
// Glyph Slot
// ============================================================================

/// Container for a loaded glyph.
class FtGlyphSlot {
  /// Glyph metrics.
  FtGlyphMetrics metrics = FtGlyphMetrics();
  
  /// Linear horizontal advance (16.16 fixed-point).
  FtFixed linearHoriAdvance = 0;
  
  /// Linear vertical advance (16.16 fixed-point).
  FtFixed linearVertAdvance = 0;
  
  /// Horizontal advance in 26.6 fractional pixels.
  FtPos advanceX = 0;
  
  /// Vertical advance in 26.6 fractional pixels.
  FtPos advanceY = 0;
  
  /// Glyph format (outline, bitmap, etc.).
  FtGlyphFormat format = FtGlyphFormat.none;
  
  /// Glyph bitmap (if format is bitmap).
  FtBitmap bitmap = FtBitmap();
  
  /// Left position of bitmap.
  int bitmapLeft = 0;
  
  /// Top position of bitmap.
  int bitmapTop = 0;
  
  /// Glyph outline (if format is outline).
  FtOutline outline = FtOutline();
  
  /// Glyph index for this slot.
  int glyphIndex = 0;

  FtGlyphSlot();

  /// Reset the slot.
  void reset() {
    metrics = FtGlyphMetrics();
    linearHoriAdvance = 0;
    linearVertAdvance = 0;
    advanceX = 0;
    advanceY = 0;
    format = FtGlyphFormat.none;
    bitmap = FtBitmap();
    bitmapLeft = 0;
    bitmapTop = 0;
    outline = FtOutline();
    glyphIndex = 0;
  }

  @override
  String toString() => 'FtGlyphSlot($format, glyph:$glyphIndex)';
}

// ============================================================================
// Size
// ============================================================================

/// Represents a font size instance.
class FtSize {
  /// Size metrics.
  FtSizeMetrics metrics = FtSizeMetrics();

  FtSize();

  @override
  String toString() => 'FtSize(${metrics.xPpem}x${metrics.yPpem})';
}

// ============================================================================
// Face
// ============================================================================

/// Font face - represents a loaded font.
class FtFace {
  /// Number of faces in the font file.
  int numFaces;
  
  /// Index of this face in the font file.
  int faceIndex;
  
  /// Face flags.
  int faceFlags;
  
  /// Style flags.
  int styleFlags;
  
  /// Number of glyphs in the face.
  int numGlyphs;
  
  /// Family name (e.g., "Times New Roman").
  String? familyName;
  
  /// Style name (e.g., "Bold Italic").
  String? styleName;
  
  /// Number of bitmap strikes.
  int numFixedSizes;
  
  /// Available bitmap sizes.
  List<FtBitmapSize> availableSizes;
  
  /// Number of character maps.
  int numCharmaps;
  
  /// Character maps.
  List<FtCharMap> charmaps;
  
  /// Font bounding box (in font units).
  FtBBox bbox;
  
  /// Font units per EM (typically 2048 for TrueType, 1000 for Type 1).
  int unitsPerEM;
  
  /// Typographic ascender (in font units).
  int ascender;
  
  /// Typographic descender (in font units).
  int descender;
  
  /// Line height (in font units).
  int height;
  
  /// Maximum advance width (in font units).
  int maxAdvanceWidth;
  
  /// Maximum advance height (in font units).
  int maxAdvanceHeight;
  
  /// Underline position (in font units).
  int underlinePosition;
  
  /// Underline thickness (in font units).
  int underlineThickness;
  
  /// Active glyph slot.
  FtGlyphSlot glyph = FtGlyphSlot();
  
  /// Active size object.
  FtSize size = FtSize();
  
  /// Active character map.
  FtCharMap? charmap;

  FtFace({
    this.numFaces = 1,
    this.faceIndex = 0,
    this.faceFlags = 0,
    this.styleFlags = 0,
    this.numGlyphs = 0,
    this.familyName,
    this.styleName,
    this.numFixedSizes = 0,
    List<FtBitmapSize>? availableSizes,
    this.numCharmaps = 0,
    List<FtCharMap>? charmaps,
    FtBBox? bbox,
    this.unitsPerEM = 1000,
    this.ascender = 0,
    this.descender = 0,
    this.height = 0,
    this.maxAdvanceWidth = 0,
    this.maxAdvanceHeight = 0,
    this.underlinePosition = 0,
    this.underlineThickness = 0,
  })  : availableSizes = availableSizes ?? [],
        charmaps = charmaps ?? [],
        bbox = bbox ?? FtBBox();

  // Property check helpers
  
  /// Check if face has horizontal metrics.
  bool get hasHorizontal => (faceFlags & FtFaceFlags.horizontal) != 0;
  
  /// Check if face has vertical metrics.
  bool get hasVertical => (faceFlags & FtFaceFlags.vertical) != 0;
  
  /// Check if face has kerning information.
  bool get hasKerning => (faceFlags & FtFaceFlags.kerning) != 0;
  
  /// Check if face is scalable.
  bool get isScalable => (faceFlags & FtFaceFlags.scalable) != 0;
  
  /// Check if face has fixed sizes (bitmap strikes).
  bool get hasFixedSizes => (faceFlags & FtFaceFlags.fixedSizes) != 0;
  
  /// Check if face has fixed-width glyphs.
  bool get isFixedWidth => (faceFlags & FtFaceFlags.fixedWidth) != 0;
  
  /// Check if face is SFNT-based.
  bool get isSfnt => (faceFlags & FtFaceFlags.sfnt) != 0;
  
  /// Check if face has glyph names.
  bool get hasGlyphNames => (faceFlags & FtFaceFlags.glyphNames) != 0;
  
  /// Check if face is CID-keyed.
  bool get isCidKeyed => (faceFlags & FtFaceFlags.cidKeyed) != 0;
  
  /// Check if face is "tricky".
  bool get isTricky => (faceFlags & FtFaceFlags.tricky) != 0;
  
  /// Check if face has color glyphs.
  bool get hasColor => (faceFlags & FtFaceFlags.color) != 0;
  
  /// Check if face has variations.
  bool get hasVariation => (faceFlags & FtFaceFlags.variation) != 0;
  
  /// Check if face has SVG glyphs.
  bool get hasSvg => (faceFlags & FtFaceFlags.svg) != 0;
  
  /// Check if face is italic.
  bool get isItalic => (styleFlags & FtStyleFlags.italic) != 0;
  
  /// Check if face is bold.
  bool get isBold => (styleFlags & FtStyleFlags.bold) != 0;

  /// Select a character map by encoding.
  bool selectCharmap(FtEncoding encoding) {
    for (final cm in charmaps) {
      if (cm.encoding == encoding) {
        charmap = cm;
        return true;
      }
    }
    return false;
  }

  @override
  String toString() => 'FtFace("$familyName $styleName", $numGlyphs glyphs)';
}

// ============================================================================
// Load Flags
// ============================================================================

/// Flags for glyph loading.
class FtLoadFlags {
  /// Default loading.
  static const int defaultFlag = 0;
  
  /// Don't scale the outline.
  static const int noScale = 1 << 0;
  
  /// Don't hint the outline.
  static const int noHinting = 1 << 1;
  
  /// Render immediately.
  static const int render = 1 << 2;
  
  /// Don't load bitmap strikes.
  static const int noBitmap = 1 << 3;
  
  /// Load vertical metrics.
  static const int verticalLayout = 1 << 4;
  
  /// Force auto-hinting.
  static const int forceAutohint = 1 << 5;
  
  /// Crop bitmap to CBox.
  static const int cropBitmap = 1 << 6;
  
  /// Use pedantic rendering.
  static const int pedantic = 1 << 7;
  
  /// Ignore global advance width.
  static const int ignoreGlobalAdvanceWidth = 1 << 9;
  
  /// Don't load embedded bitmaps.
  static const int noRecurse = 1 << 10;
  
  /// Ignore font transforms.
  static const int ignoreTransform = 1 << 11;
  
  /// Render as mono.
  static const int monochrome = 1 << 12;
  
  /// Linear horizontal advance.
  static const int linearDesign = 1 << 13;
  
  /// Don't auto-hint.
  static const int noAutohint = 1 << 15;
  
  /// Load color layers.
  static const int color = 1 << 20;
  
  /// Compute metrics only.
  static const int computeMetrics = 1 << 21;
  
  /// Load as bitmap only.
  static const int bitmapMetricsOnly = 1 << 22;
  
  /// Load SVG document.
  static const int svgOnly = 1 << 23;
}

// ============================================================================
// Render Mode
// ============================================================================

/// Render modes for glyph rasterization.
enum FtRenderMode {
  /// Normal anti-aliased rendering.
  normal,
  /// Light anti-aliased rendering.
  light,
  /// Monochrome (1-bit) rendering.
  mono,
  /// LCD horizontal sub-pixel rendering.
  lcd,
  /// LCD vertical sub-pixel rendering.
  lcdV,
  /// SDF (Signed Distance Field) rendering.
  sdf,
}
