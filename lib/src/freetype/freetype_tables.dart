// FreeType 2 - A high-quality font engine
// Copyright (C) 1996-2025 by David Turner, Robert Wilhelm, and Werner Lemberg.
// Ported to Dart
//
// TrueType/OpenType table structures and parsing.

/// FreeType font table structures.
library;

import 'dart:typed_data';
import 'freetype_types.dart';
import 'freetype_outline.dart';

// ============================================================================
// Table Tags
// ============================================================================

/// Common TrueType/OpenType table tags.
class FtTableTags {
  /// Create a tag from 4 characters.
  static int makeTag(int a, int b, int c, int d) =>
      (a << 24) | (b << 16) | (c << 8) | d;
  
  /// cmap - Character to glyph mapping
  static final int cmap = makeTag(0x63, 0x6D, 0x61, 0x70); // 'cmap'
  
  /// head - Font header
  static final int head = makeTag(0x68, 0x65, 0x61, 0x64); // 'head'
  
  /// hhea - Horizontal header
  static final int hhea = makeTag(0x68, 0x68, 0x65, 0x61); // 'hhea'
  
  /// hmtx - Horizontal metrics
  static final int hmtx = makeTag(0x68, 0x6D, 0x74, 0x78); // 'hmtx'
  
  /// maxp - Maximum profile
  static final int maxp = makeTag(0x6D, 0x61, 0x78, 0x70); // 'maxp'
  
  /// name - Naming table
  static final int name = makeTag(0x6E, 0x61, 0x6D, 0x65); // 'name'
  
  /// OS/2 - OS/2 and Windows metrics
  static final int os2 = makeTag(0x4F, 0x53, 0x2F, 0x32); // 'OS/2'
  
  /// post - PostScript information
  static final int post = makeTag(0x70, 0x6F, 0x73, 0x74); // 'post'
  
  /// glyf - Glyph data
  static final int glyf = makeTag(0x67, 0x6C, 0x79, 0x66); // 'glyf'
  
  /// loca - Index to location
  static final int loca = makeTag(0x6C, 0x6F, 0x63, 0x61); // 'loca'
  
  /// kern - Kerning
  static final int kern = makeTag(0x6B, 0x65, 0x72, 0x6E); // 'kern'
  
  /// GDEF - Glyph definition
  static final int gdef = makeTag(0x47, 0x44, 0x45, 0x46); // 'GDEF'
  
  /// GPOS - Glyph positioning
  static final int gpos = makeTag(0x47, 0x50, 0x4F, 0x53); // 'GPOS'
  
  /// GSUB - Glyph substitution
  static final int gsub = makeTag(0x47, 0x53, 0x55, 0x42); // 'GSUB'
  
  /// vhea - Vertical header
  static final int vhea = makeTag(0x76, 0x68, 0x65, 0x61); // 'vhea'
  
  /// vmtx - Vertical metrics
  static final int vmtx = makeTag(0x76, 0x6D, 0x74, 0x78); // 'vmtx'
  
  /// CFF  - Compact Font Format
  static final int cff = makeTag(0x43, 0x46, 0x46, 0x20); // 'CFF '
  
  /// CFF2 - Compact Font Format 2
  static final int cff2 = makeTag(0x43, 0x46, 0x46, 0x32); // 'CFF2'
  
  /// Convert tag to string.
  static String tagToString(int tag) {
    return String.fromCharCodes([
      (tag >> 24) & 0xFF,
      (tag >> 16) & 0xFF,
      (tag >> 8) & 0xFF,
      tag & 0xFF,
    ]);
  }
}

// ============================================================================
// Table Directory
// ============================================================================

/// Table directory entry.
class FtTableEntry {
  /// Table tag.
  final int tag;
  
  /// Checksum.
  final int checksum;
  
  /// Offset from beginning of file.
  final int offset;
  
  /// Length of table.
  final int length;

  FtTableEntry({
    required this.tag,
    required this.checksum,
    required this.offset,
    required this.length,
  });

  @override
  String toString() => 
      'Table(${FtTableTags.tagToString(tag)}, offset:$offset, len:$length)';
}

/// Font file table directory.
class FtTableDirectory {
  /// SFNT version (0x00010000 for TrueType, 'OTTO' for CFF).
  int sfntVersion;
  
  /// Number of tables.
  int numTables;
  
  /// Search range.
  int searchRange;
  
  /// Entry selector.
  int entrySelector;
  
  /// Range shift.
  int rangeShift;
  
  /// Table entries.
  List<FtTableEntry> tables;

  FtTableDirectory({
    this.sfntVersion = 0x00010000,
    this.numTables = 0,
    this.searchRange = 0,
    this.entrySelector = 0,
    this.rangeShift = 0,
    List<FtTableEntry>? tables,
  }) : tables = tables ?? [];

  /// Find a table by tag.
  FtTableEntry? findTable(int tag) {
    for (final table in tables) {
      if (table.tag == tag) return table;
    }
    return null;
  }

  /// Check if TrueType font.
  bool get isTrueType => sfntVersion == 0x00010000;
  
  /// Check if CFF font.
  bool get isCff => sfntVersion == 0x4F54544F; // 'OTTO'
}

// ============================================================================
// Head Table
// ============================================================================

/// TrueType 'head' table.
class FtHeadTable {
  /// Major version (usually 1).
  int majorVersion;
  
  /// Minor version (usually 0).
  int minorVersion;
  
  /// Font revision (16.16 fixed-point).
  FtFixed fontRevision;
  
  /// Checksum adjustment.
  int checksumAdjustment;
  
  /// Magic number (0x5F0F3CF5).
  int magicNumber;
  
  /// Flags.
  int flags;
  
  /// Units per EM.
  int unitsPerEM;
  
  /// Created timestamp.
  int created;
  
  /// Modified timestamp.
  int modified;
  
  /// Global bounding box.
  FtBBox bbox;
  
  /// Mac style flags.
  int macStyle;
  
  /// Smallest readable size in pixels.
  int lowestRecPPEM;
  
  /// Font direction hint.
  int fontDirectionHint;
  
  /// Index to loc format (0 = short, 1 = long).
  int indexToLocFormat;
  
  /// Glyph data format.
  int glyphDataFormat;

  FtHeadTable({
    this.majorVersion = 1,
    this.minorVersion = 0,
    this.fontRevision = 0,
    this.checksumAdjustment = 0,
    this.magicNumber = 0x5F0F3CF5,
    this.flags = 0,
    this.unitsPerEM = 2048,
    this.created = 0,
    this.modified = 0,
    FtBBox? bbox,
    this.macStyle = 0,
    this.lowestRecPPEM = 8,
    this.fontDirectionHint = 2,
    this.indexToLocFormat = 0,
    this.glyphDataFormat = 0,
  }) : bbox = bbox ?? FtBBox();
}

// ============================================================================
// Hhea Table
// ============================================================================

/// TrueType 'hhea' table.
class FtHheaTable {
  /// Major version.
  int majorVersion;
  
  /// Minor version.
  int minorVersion;
  
  /// Typographic ascender.
  int ascender;
  
  /// Typographic descender.
  int descender;
  
  /// Typographic line gap.
  int lineGap;
  
  /// Maximum advance width.
  int advanceWidthMax;
  
  /// Minimum left side bearing.
  int minLeftSideBearing;
  
  /// Minimum right side bearing.
  int minRightSideBearing;
  
  /// Maximum x extent.
  int xMaxExtent;
  
  /// Caret slope rise.
  int caretSlopeRise;
  
  /// Caret slope run.
  int caretSlopeRun;
  
  /// Caret offset.
  int caretOffset;
  
  /// Metric data format.
  int metricDataFormat;
  
  /// Number of horizontal metrics.
  int numberOfHMetrics;

  FtHheaTable({
    this.majorVersion = 1,
    this.minorVersion = 0,
    this.ascender = 0,
    this.descender = 0,
    this.lineGap = 0,
    this.advanceWidthMax = 0,
    this.minLeftSideBearing = 0,
    this.minRightSideBearing = 0,
    this.xMaxExtent = 0,
    this.caretSlopeRise = 1,
    this.caretSlopeRun = 0,
    this.caretOffset = 0,
    this.metricDataFormat = 0,
    this.numberOfHMetrics = 0,
  });
}

// ============================================================================
// Maxp Table
// ============================================================================

/// TrueType 'maxp' table.
class FtMaxpTable {
  /// Version (0x00010000 for TrueType, 0x00005000 for CFF).
  FtFixed version;
  
  /// Number of glyphs.
  int numGlyphs;
  
  /// Maximum points in non-compound glyph.
  int maxPoints;
  
  /// Maximum contours in non-compound glyph.
  int maxContours;
  
  /// Maximum points in compound glyph.
  int maxCompositePoints;
  
  /// Maximum contours in compound glyph.
  int maxCompositeContours;
  
  /// Maximum zones.
  int maxZones;
  
  /// Maximum twilight points.
  int maxTwilightPoints;
  
  /// Maximum storage areas.
  int maxStorage;
  
  /// Maximum function definitions.
  int maxFunctionDefs;
  
  /// Maximum instruction definitions.
  int maxInstructionDefs;
  
  /// Maximum stack elements.
  int maxStackElements;
  
  /// Maximum instruction size.
  int maxSizeOfInstructions;
  
  /// Maximum components at top level.
  int maxComponentElements;
  
  /// Maximum nesting depth.
  int maxComponentDepth;

  FtMaxpTable({
    this.version = 0x00010000,
    this.numGlyphs = 0,
    this.maxPoints = 0,
    this.maxContours = 0,
    this.maxCompositePoints = 0,
    this.maxCompositeContours = 0,
    this.maxZones = 2,
    this.maxTwilightPoints = 0,
    this.maxStorage = 0,
    this.maxFunctionDefs = 0,
    this.maxInstructionDefs = 0,
    this.maxStackElements = 0,
    this.maxSizeOfInstructions = 0,
    this.maxComponentElements = 0,
    this.maxComponentDepth = 0,
  });
}

// ============================================================================
// Cmap Table
// ============================================================================

/// Cmap encoding record.
class FtCmapEncodingRecord {
  /// Platform ID.
  int platformId;
  
  /// Encoding ID.
  int encodingId;
  
  /// Offset to subtable.
  int offset;

  FtCmapEncodingRecord({
    this.platformId = 0,
    this.encodingId = 0,
    this.offset = 0,
  });
}

/// Abstract cmap subtable.
abstract class FtCmapSubtable {
  /// Format number.
  int get format;
  
  /// Get glyph index for character code.
  int getGlyphIndex(int charCode);
  
  /// Get first character code.
  int? getFirstChar();
  
  /// Get next character code.
  int? getNextChar(int charCode);
}

/// Format 0: Byte encoding table.
class FtCmapFormat0 extends FtCmapSubtable {
  @override
  int get format => 0;
  
  /// Glyph index array (256 entries).
  Uint8List glyphIdArray = Uint8List(256);

  @override
  int getGlyphIndex(int charCode) {
    if (charCode < 0 || charCode >= 256) return 0;
    return glyphIdArray[charCode];
  }

  @override
  int? getFirstChar() {
    for (var i = 0; i < 256; i++) {
      if (glyphIdArray[i] != 0) return i;
    }
    return null;
  }

  @override
  int? getNextChar(int charCode) {
    for (var i = charCode + 1; i < 256; i++) {
      if (glyphIdArray[i] != 0) return i;
    }
    return null;
  }
}

/// Format 4: Segment mapping to delta values.
class FtCmapFormat4 extends FtCmapSubtable {
  @override
  int get format => 4;
  
  /// Segment count.
  int segCount = 0;
  
  /// End character codes.
  List<int> endCode = [];
  
  /// Start character codes.
  List<int> startCode = [];
  
  /// ID delta values.
  List<int> idDelta = [];
  
  /// ID range offset values.
  List<int> idRangeOffset = [];
  
  /// Glyph ID array.
  List<int> glyphIdArray = [];

  @override
  int getGlyphIndex(int charCode) {
    if (charCode > 0xFFFF) return 0;
    
    // Binary search for segment
    var low = 0;
    var high = segCount - 1;
    
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (endCode[mid] < charCode) {
        low = mid + 1;
      } else if (startCode[mid] > charCode) {
        high = mid - 1;
      } else {
        // Found segment
        if (idRangeOffset[mid] == 0) {
          return (charCode + idDelta[mid]) & 0xFFFF;
        } else {
          final offset = idRangeOffset[mid] ~/ 2 + 
                        (charCode - startCode[mid]) -
                        (segCount - mid);
          if (offset >= 0 && offset < glyphIdArray.length) {
            final glyph = glyphIdArray[offset];
            if (glyph != 0) {
              return (glyph + idDelta[mid]) & 0xFFFF;
            }
          }
          return 0;
        }
      }
    }
    return 0;
  }

  @override
  int? getFirstChar() {
    for (var i = 0; i < segCount; i++) {
      if (startCode[i] != 0xFFFF) {
        return startCode[i];
      }
    }
    return null;
  }

  @override
  int? getNextChar(int charCode) {
    for (var i = 0; i < segCount; i++) {
      if (charCode < startCode[i]) {
        return startCode[i];
      }
      if (charCode < endCode[i]) {
        return charCode + 1;
      }
    }
    return null;
  }
}

/// Format 12: Segmented coverage.
class FtCmapFormat12 extends FtCmapSubtable {
  @override
  int get format => 12;
  
  /// Groups.
  List<_CmapGroup> groups = [];

  @override
  int getGlyphIndex(int charCode) {
    // Binary search
    var low = 0;
    var high = groups.length - 1;
    
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final group = groups[mid];
      if (group.endCharCode < charCode) {
        low = mid + 1;
      } else if (group.startCharCode > charCode) {
        high = mid - 1;
      } else {
        return group.startGlyphId + (charCode - group.startCharCode);
      }
    }
    return 0;
  }

  @override
  int? getFirstChar() {
    if (groups.isEmpty) return null;
    return groups[0].startCharCode;
  }

  @override
  int? getNextChar(int charCode) {
    for (final group in groups) {
      if (charCode < group.startCharCode) {
        return group.startCharCode;
      }
      if (charCode < group.endCharCode) {
        return charCode + 1;
      }
    }
    return null;
  }
}

class _CmapGroup {
  final int startCharCode;
  final int endCharCode;
  final int startGlyphId;
  
  _CmapGroup(this.startCharCode, this.endCharCode, this.startGlyphId);
}

/// Cmap table.
class FtCmapTable {
  /// Version.
  int version;
  
  /// Encoding records.
  List<FtCmapEncodingRecord> encodingRecords;
  
  /// Subtables by offset.
  Map<int, FtCmapSubtable> subtables;

  FtCmapTable({
    this.version = 0,
    List<FtCmapEncodingRecord>? encodingRecords,
    Map<int, FtCmapSubtable>? subtables,
  })  : encodingRecords = encodingRecords ?? [],
        subtables = subtables ?? {};

  /// Get subtable for an encoding record.
  FtCmapSubtable? getSubtable(FtCmapEncodingRecord record) {
    return subtables[record.offset];
  }

  /// Find best Unicode subtable.
  FtCmapSubtable? findUnicodeSubtable() {
    // Priority: platform 0 (Unicode), platform 3 encoding 10 (UCS-4), 
    // platform 3 encoding 1 (UCS-2)
    for (final record in encodingRecords) {
      if (record.platformId == 0) {
        final subtable = subtables[record.offset];
        if (subtable != null) return subtable;
      }
    }
    for (final record in encodingRecords) {
      if (record.platformId == 3 && record.encodingId == 10) {
        final subtable = subtables[record.offset];
        if (subtable != null) return subtable;
      }
    }
    for (final record in encodingRecords) {
      if (record.platformId == 3 && record.encodingId == 1) {
        final subtable = subtables[record.offset];
        if (subtable != null) return subtable;
      }
    }
    return null;
  }
}

// ============================================================================
// Hmtx Table
// ============================================================================

/// Horizontal metric.
class FtLongHorMetric {
  /// Advance width.
  int advanceWidth;
  
  /// Left side bearing.
  int lsb;

  FtLongHorMetric({this.advanceWidth = 0, this.lsb = 0});
}

/// Horizontal metrics table.
class FtHmtxTable {
  /// Long horizontal metrics.
  List<FtLongHorMetric> hMetrics;
  
  /// Left side bearings (for remaining glyphs).
  List<int> leftSideBearings;

  FtHmtxTable({
    List<FtLongHorMetric>? hMetrics,
    List<int>? leftSideBearings,
  })  : hMetrics = hMetrics ?? [],
        leftSideBearings = leftSideBearings ?? [];

  /// Get metrics for a glyph.
  FtLongHorMetric getMetrics(int glyphIndex) {
    if (hMetrics.isEmpty) {
      return FtLongHorMetric();
    }
    if (glyphIndex < hMetrics.length) {
      return hMetrics[glyphIndex];
    }
    // Use last advance width with lsb from array
    final lastAdvance = hMetrics.last.advanceWidth;
    final lsbIndex = glyphIndex - hMetrics.length;
    final lsb = lsbIndex < leftSideBearings.length 
        ? leftSideBearings[lsbIndex] 
        : 0;
    return FtLongHorMetric(advanceWidth: lastAdvance, lsb: lsb);
  }
}

// ============================================================================
// OS/2 Table
// ============================================================================

/// OS/2 and Windows metrics table.
class FtOS2Table {
  /// Version.
  int version;
  
  /// Average weighted character width.
  int xAvgCharWidth;
  
  /// Weight class (100-900).
  int usWeightClass;
  
  /// Width class (1-9).
  int usWidthClass;
  
  /// Type flags.
  int fsType;
  
  /// Subscript X size.
  int ySubscriptXSize;
  
  /// Subscript Y size.
  int ySubscriptYSize;
  
  /// Subscript X offset.
  int ySubscriptXOffset;
  
  /// Subscript Y offset.
  int ySubscriptYOffset;
  
  /// Superscript X size.
  int ySuperscriptXSize;
  
  /// Superscript Y size.
  int ySuperscriptYSize;
  
  /// Superscript X offset.
  int ySuperscriptXOffset;
  
  /// Superscript Y offset.
  int ySuperscriptYOffset;
  
  /// Strikeout size.
  int yStrikeoutSize;
  
  /// Strikeout position.
  int yStrikeoutPosition;
  
  /// Family class.
  int sFamilyClass;
  
  /// Panose classification.
  Uint8List panose;
  
  /// Unicode range (4 x 32-bit).
  Uint32List ulUnicodeRange;
  
  /// Vendor ID.
  int achVendID;
  
  /// Selection flags.
  int fsSelection;
  
  /// First character index.
  int usFirstCharIndex;
  
  /// Last character index.
  int usLastCharIndex;
  
  /// Typographic ascender.
  int sTypoAscender;
  
  /// Typographic descender.
  int sTypoDescender;
  
  /// Typographic line gap.
  int sTypoLineGap;
  
  /// Windows ascender.
  int usWinAscent;
  
  /// Windows descender.
  int usWinDescent;
  
  /// Code page range (version >= 1).
  Uint32List ulCodePageRange;
  
  /// x-height (version >= 2).
  int sxHeight;
  
  /// Cap height (version >= 2).
  int sCapHeight;
  
  /// Default char (version >= 2).
  int usDefaultChar;
  
  /// Break char (version >= 2).
  int usBreakChar;
  
  /// Max context (version >= 2).
  int usMaxContext;
  
  /// Lower optical point size (version >= 5).
  int usLowerOpticalPointSize;
  
  /// Upper optical point size (version >= 5).
  int usUpperOpticalPointSize;

  FtOS2Table({
    this.version = 0,
    this.xAvgCharWidth = 0,
    this.usWeightClass = 400,
    this.usWidthClass = 5,
    this.fsType = 0,
    this.ySubscriptXSize = 0,
    this.ySubscriptYSize = 0,
    this.ySubscriptXOffset = 0,
    this.ySubscriptYOffset = 0,
    this.ySuperscriptXSize = 0,
    this.ySuperscriptYSize = 0,
    this.ySuperscriptXOffset = 0,
    this.ySuperscriptYOffset = 0,
    this.yStrikeoutSize = 0,
    this.yStrikeoutPosition = 0,
    this.sFamilyClass = 0,
    Uint8List? panose,
    Uint32List? ulUnicodeRange,
    this.achVendID = 0,
    this.fsSelection = 0,
    this.usFirstCharIndex = 0,
    this.usLastCharIndex = 0,
    this.sTypoAscender = 0,
    this.sTypoDescender = 0,
    this.sTypoLineGap = 0,
    this.usWinAscent = 0,
    this.usWinDescent = 0,
    Uint32List? ulCodePageRange,
    this.sxHeight = 0,
    this.sCapHeight = 0,
    this.usDefaultChar = 0,
    this.usBreakChar = 32,
    this.usMaxContext = 0,
    this.usLowerOpticalPointSize = 0,
    this.usUpperOpticalPointSize = 0xFFFF,
  })  : panose = panose ?? Uint8List(10),
        ulUnicodeRange = ulUnicodeRange ?? Uint32List(4),
        ulCodePageRange = ulCodePageRange ?? Uint32List(2);

  /// Check if bold.
  bool get isBold => (fsSelection & 0x20) != 0;
  
  /// Check if italic.
  bool get isItalic => (fsSelection & 0x01) != 0;
  
  /// Check if regular.
  bool get isRegular => (fsSelection & 0x40) != 0;
}

// ============================================================================
// Post Table
// ============================================================================

/// PostScript table.
class FtPostTable {
  /// Format (16.16 fixed-point).
  FtFixed format;
  
  /// Italic angle (16.16 fixed-point).
  FtFixed italicAngle;
  
  /// Underline position.
  int underlinePosition;
  
  /// Underline thickness.
  int underlineThickness;
  
  /// Is fixed pitch.
  int isFixedPitch;
  
  /// Minimum memory usage (Type 42).
  int minMemType42;
  
  /// Maximum memory usage (Type 42).
  int maxMemType42;
  
  /// Minimum memory usage (Type 1).
  int minMemType1;
  
  /// Maximum memory usage (Type 1).
  int maxMemType1;
  
  /// Glyph names (format 2.0).
  List<String> glyphNames;

  FtPostTable({
    this.format = 0x00020000,
    this.italicAngle = 0,
    this.underlinePosition = 0,
    this.underlineThickness = 0,
    this.isFixedPitch = 0,
    this.minMemType42 = 0,
    this.maxMemType42 = 0,
    this.minMemType1 = 0,
    this.maxMemType1 = 0,
    List<String>? glyphNames,
  }) : glyphNames = glyphNames ?? [];

  /// Get glyph name.
  String? getGlyphName(int glyphIndex) {
    if (glyphIndex < 0 || glyphIndex >= glyphNames.length) return null;
    return glyphNames[glyphIndex];
  }
}

// ============================================================================
// Kern Table
// ============================================================================

/// Kerning pair.
class FtKernPair {
  /// Left glyph index.
  int left;
  
  /// Right glyph index.
  int right;
  
  /// Kerning value.
  int value;

  FtKernPair({this.left = 0, this.right = 0, this.value = 0});
}

/// Kerning subtable.
class FtKernSubtable {
  /// Version.
  int version;
  
  /// Coverage flags.
  int coverage;
  
  /// Kerning pairs.
  List<FtKernPair> pairs;

  FtKernSubtable({
    this.version = 0,
    this.coverage = 0,
    List<FtKernPair>? pairs,
  }) : pairs = pairs ?? [];

  /// Check if horizontal kerning.
  bool get isHorizontal => (coverage & 0x01) != 0;
  
  /// Check if minimum values.
  bool get isMinimum => (coverage & 0x02) != 0;
  
  /// Check if cross-stream.
  bool get isCrossStream => (coverage & 0x04) != 0;
  
  /// Check if override.
  bool get isOverride => (coverage & 0x08) != 0;
}

/// Kerning table.
class FtKernTable {
  /// Version.
  int version;
  
  /// Subtables.
  List<FtKernSubtable> subtables;

  FtKernTable({
    this.version = 0,
    List<FtKernSubtable>? subtables,
  }) : subtables = subtables ?? [];

  /// Get kerning for a pair.
  int getKerning(int left, int right) {
    for (final subtable in subtables) {
      if (!subtable.isHorizontal) continue;
      
      // Binary search
      var lo = 0;
      var hi = subtable.pairs.length - 1;
      
      while (lo <= hi) {
        final mid = (lo + hi) ~/ 2;
        final pair = subtable.pairs[mid];
        final key = (left << 16) | right;
        final pairKey = (pair.left << 16) | pair.right;
        
        if (pairKey < key) {
          lo = mid + 1;
        } else if (pairKey > key) {
          hi = mid - 1;
        } else {
          return pair.value;
        }
      }
    }
    return 0;
  }
}
