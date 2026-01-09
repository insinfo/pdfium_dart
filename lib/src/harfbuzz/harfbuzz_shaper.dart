// HarfBuzz - A text shaping library
// Copyright © 2007,2008,2009 Red Hat, Inc.
// Copyright © 2011,2012 Google, Inc.
// Ported to Dart

/// HarfBuzz text shaping engine.
library;

import 'harfbuzz_types.dart';
import 'harfbuzz_buffer.dart';
import 'harfbuzz_font.dart';

// ============================================================================
// Shaping Functions
// ============================================================================

/// Shape the text in a buffer using a font.
/// 
/// This is the main entry point for text shaping.
/// 
/// [font] - The font to use for shaping.
/// [buffer] - The buffer containing text to shape.
/// [features] - Optional list of OpenType features to apply.
/// [shaperList] - Optional list of shapers to try (not used in this implementation).
bool hbShape(
  HbFont font,
  HbBuffer buffer, {
  List<HbFeature>? features,
  List<String>? shaperList,
}) {
  return hbShapeFull(font, buffer, features: features, shaperList: shaperList);
}

/// Full shaping function with all options.
bool hbShapeFull(
  HbFont font,
  HbBuffer buffer, {
  List<HbFeature>? features,
  List<String>? shaperList,
}) {
  // Validate buffer state
  if (buffer.contentType != HbBufferContentType.unicode) {
    return false;
  }
  
  if (buffer.length == 0) {
    buffer.contentType = HbBufferContentType.glyphs;
    return true;
  }
  
  // Ensure segment properties are set
  buffer.guessSegmentProperties();
  
  // Create shaper and run
  final shaper = _HbShaper(font, buffer, features ?? []);
  return shaper.shape();
}

/// List available shapers.
List<String> hbShapeListShapers() {
  return ['ot', 'fallback'];
}

// ============================================================================
// Internal Shaper
// ============================================================================

/// Internal shaper implementation.
class _HbShaper {
  final HbFont font;
  final HbBuffer buffer;
  final List<HbFeature> features;
  
  // Feature masks
  final Map<int, HbMask> _featureMasks = {};
  
  _HbShaper(this.font, this.buffer, this.features) {
    _setupFeatures();
  }
  
  void _setupFeatures() {
    // Assign masks to features
    var mask = 1;
    for (final feature in features) {
      if (feature.value != 0) {
        _featureMasks[feature.tag] = mask;
        mask <<= 1;
      }
    }
  }
  
  bool shape() {
    // Phase 1: Map characters to glyphs
    _mapToGlyphs();
    
    // Phase 2: Initial reordering (for complex scripts)
    _initialReorder();
    
    // Phase 3: Apply OpenType features
    _applyFeatures();
    
    // Phase 4: Position glyphs
    _positionGlyphs();
    
    // Phase 5: Final reordering
    _finalReorder();
    
    // Mark buffer as containing glyphs
    buffer.contentType = HbBufferContentType.glyphs;
    
    return true;
  }
  
  /// Map Unicode codepoints to glyph indices.
  void _mapToGlyphs() {
    final infos = buffer.glyphInfos;
    
    for (var i = 0; i < infos.length; i++) {
      final info = infos[i];
      final glyph = font.getGlyph(info.codepoint);
      
      if (glyph != null) {
        info.codepoint = glyph;
      } else {
        // Use .notdef (glyph 0) for unmapped characters
        info.codepoint = 0;
      }
      
      buffer.setGlyphInfo(i, info);
    }
  }
  
  /// Initial reordering for complex scripts.
  void _initialReorder() {
    final script = buffer.script;
    
    // Apply script-specific reordering
    switch (script) {
      case HbScript.arabic:
      case HbScript.syriac:
        _reorderArabic();
        break;
      case HbScript.devanagari:
      case HbScript.bengali:
      case HbScript.gurmukhi:
      case HbScript.gujarati:
      case HbScript.oriya:
      case HbScript.tamil:
      case HbScript.telugu:
      case HbScript.kannada:
      case HbScript.malayalam:
      case HbScript.sinhala:
        _reorderIndic();
        break;
      case HbScript.thai:
      case HbScript.lao:
        _reorderThai();
        break;
      case HbScript.hebrew:
        _reorderHebrew();
        break;
      default:
        // No special reordering needed
        break;
    }
  }
  
  /// Apply OpenType features.
  void _applyFeatures() {
    // Default features to apply
    final defaultFeatures = [
      HbFeatureTags.ccmp, // Character composition
      HbFeatureTags.locl, // Localized forms
      HbFeatureTags.rlig, // Required ligatures
      HbFeatureTags.calt, // Contextual alternates
      HbFeatureTags.liga, // Standard ligatures
      HbFeatureTags.kern, // Kerning
    ];
    
    // In a full implementation, this would:
    // 1. Look up features in GSUB/GPOS tables
    // 2. Apply substitution rules
    // 3. Build lookup lists
    // 4. Process lookups in order
    
    // For now, just mark features as applied
    for (final tag in defaultFeatures) {
      _applyFeature(tag);
    }
    
    // Apply user-requested features
    for (final feature in features) {
      _applyFeature(feature.tag, feature.value);
    }
  }
  
  void _applyFeature(int tag, [int value = 1]) {
    // Feature application would happen here
    // This requires GSUB/GPOS table parsing
  }
  
  /// Position glyphs.
  void _positionGlyphs() {
    final direction = buffer.direction;
    final isHorizontal = hbDirectionIsHorizontal(direction);
    final isBackward = hbDirectionIsBackward(direction);
    
    final infos = buffer.glyphInfos;
    
    for (var i = 0; i < infos.length; i++) {
      final info = infos[i];
      final pos = buffer.getGlyphPosition(i);
      
      if (isHorizontal) {
        pos.xAdvance = font.getGlyphHAdvance(info.codepoint);
        pos.yAdvance = 0;
      } else {
        pos.xAdvance = 0;
        pos.yAdvance = font.getGlyphVAdvance(info.codepoint);
      }
      
      pos.xOffset = 0;
      pos.yOffset = 0;
      
      buffer.setGlyphPosition(i, pos);
    }
    
    // Apply kerning
    if (isHorizontal) {
      _applyKerning();
    }
    
    // Reverse positions if backward direction
    if (isBackward) {
      buffer.reverse();
    }
  }
  
  /// Apply kerning adjustments.
  void _applyKerning() {
    final infos = buffer.glyphInfos;
    
    for (var i = 0; i < infos.length - 1; i++) {
      final kern = font.getGlyphHKerning(
        infos[i].codepoint,
        infos[i + 1].codepoint,
      );
      
      if (kern != 0) {
        final pos = buffer.getGlyphPosition(i);
        pos.xAdvance += kern;
        buffer.setGlyphPosition(i, pos);
      }
    }
  }
  
  /// Final reordering pass.
  void _finalReorder() {
    // Apply any final reordering needed
    final script = buffer.script;
    
    switch (script) {
      case HbScript.arabic:
      case HbScript.syriac:
      case HbScript.hebrew:
        // RTL scripts might need cluster reversal
        if (buffer.direction == HbDirection.rtl) {
          buffer.reverseClusters();
        }
        break;
      default:
        break;
    }
  }
  
  // Script-specific reordering
  
  void _reorderArabic() {
    // Arabic joining analysis
    // Would analyze joining types and set appropriate masks
  }
  
  void _reorderIndic() {
    // Indic syllable analysis
    // Would identify syllables and reorder
  }
  
  void _reorderThai() {
    // Thai SARA AM decomposition and reordering
  }
  
  void _reorderHebrew() {
    // Hebrew mark reordering
  }
}

// ============================================================================
// Shaping Plan
// ============================================================================

/// Cached shaping plan for a font/script/direction combination.
class HbShapePlan {
  /// The face this plan is for.
  final HbFace face;
  
  /// Segment properties.
  final HbSegmentProperties props;
  
  /// Features.
  final List<HbFeature> features;
  
  /// Shapers to use.
  final List<String> shapers;

  HbShapePlan._({
    required this.face,
    required this.props,
    required this.features,
    required this.shapers,
  });

  /// Create a shape plan.
  factory HbShapePlan.create(
    HbFace face,
    HbSegmentProperties props, {
    List<HbFeature>? features,
    List<String>? shaperList,
  }) {
    return HbShapePlan._(
      face: face,
      props: props.copy(),
      features: features ?? [],
      shapers: shaperList ?? ['ot', 'fallback'],
    );
  }

  /// Execute the shape plan.
  bool execute(HbFont font, HbBuffer buffer) {
    buffer.segmentProperties = props;
    return hbShape(font, buffer, features: features);
  }

  @override
  String toString() => 'HbShapePlan(${props.script}, ${props.direction})';
}

// ============================================================================
// Shape Utilities
// ============================================================================

/// Calculate total advance of shaped buffer.
({HbPosition x, HbPosition y}) hbBufferGetTotalAdvance(HbBuffer buffer) {
  var x = 0;
  var y = 0;
  
  for (var i = 0; i < buffer.length; i++) {
    final pos = buffer.getGlyphPosition(i);
    x += pos.xAdvance;
    y += pos.yAdvance;
  }
  
  return (x: x, y: y);
}

/// Get shaped text as positioned glyphs.
List<({
  HbCodepoint glyph,
  int cluster,
  HbPosition xOffset,
  HbPosition yOffset,
  HbPosition xAdvance,
  HbPosition yAdvance,
})> hbBufferGetGlyphPositions(HbBuffer buffer) {
  final result = <({
    HbCodepoint glyph,
    int cluster,
    HbPosition xOffset,
    HbPosition yOffset,
    HbPosition xAdvance,
    HbPosition yAdvance,
  })>[];
  
  for (var i = 0; i < buffer.length; i++) {
    final info = buffer.getGlyphInfo(i);
    final pos = buffer.getGlyphPosition(i);
    
    result.add((
      glyph: info.codepoint,
      cluster: info.cluster,
      xOffset: pos.xOffset,
      yOffset: pos.yOffset,
      xAdvance: pos.xAdvance,
      yAdvance: pos.yAdvance,
    ));
  }
  
  return result;
}

/// Serialize buffer for debugging.
String hbBufferSerialize(
  HbBuffer buffer, {
  int start = 0,
  int? end,
  HbFont? font,
  bool glyphNames = true,
  bool positions = true,
  bool clusters = true,
}) {
  end ??= buffer.length;
  final parts = <String>[];
  
  for (var i = start; i < end; i++) {
    final info = buffer.getGlyphInfo(i);
    final pos = buffer.getGlyphPosition(i);
    
    var s = StringBuffer();
    
    // Glyph name or index
    String? name;
    if (glyphNames && font != null) {
      name = font.getGlyphName(info.codepoint);
    }
    s.write(name ?? 'gid${info.codepoint}');
    
    // Cluster
    if (clusters) {
      s.write('=${info.cluster}');
    }
    
    // Position
    if (positions) {
      if (pos.xOffset != 0 || pos.yOffset != 0) {
        s.write('@${pos.xOffset},${pos.yOffset}');
      }
      s.write('+${pos.xAdvance}');
      if (pos.yAdvance != 0) {
        s.write(',${pos.yAdvance}');
      }
    }
    
    parts.add(s.toString());
  }
  
  return '[${parts.join('|')}]';
}

/// Deserialize buffer from string.
bool hbBufferDeserialize(HbBuffer buffer, String str) {
  // Parse serialized format
  if (!str.startsWith('[') || !str.endsWith(']')) {
    return false;
  }
  
  buffer.clearContents();
  
  final content = str.substring(1, str.length - 1);
  if (content.isEmpty) return true;
  
  final parts = content.split('|');
  
  for (final part in parts) {
    // Parse glyph info
    // Format: glyph=cluster@xOff,yOff+xAdv,yAdv
    
    var s = part;
    var cluster = 0;
    var xOffset = 0;
    var yOffset = 0;
    var xAdvance = 0;
    var yAdvance = 0;
    
    // Parse cluster
    final eqIdx = s.indexOf('=');
    if (eqIdx > 0) {
      final clusterStr = s.substring(eqIdx + 1);
      s = s.substring(0, eqIdx);
      
      final atIdx = clusterStr.indexOf('@');
      final plusIdx = clusterStr.indexOf('+');
      
      if (atIdx > 0) {
        cluster = int.tryParse(clusterStr.substring(0, atIdx)) ?? 0;
      } else if (plusIdx > 0) {
        cluster = int.tryParse(clusterStr.substring(0, plusIdx)) ?? 0;
      } else {
        cluster = int.tryParse(clusterStr) ?? 0;
      }
    }
    
    // Parse glyph
    int glyph;
    if (s.startsWith('gid')) {
      glyph = int.tryParse(s.substring(3)) ?? 0;
    } else {
      // Would need font to resolve name
      glyph = 0;
    }
    
    buffer.add(glyph, cluster);
  }
  
  buffer.contentType = HbBufferContentType.glyphs;
  return true;
}
