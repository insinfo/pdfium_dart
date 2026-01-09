// Copyright 2017 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Original code copyright 2014 Foxit Software Inc. http://www.foxitsoftware.com

import 'dart:typed_data';
import 'cpdf_cidfont.dart';
import 'cpdf_cmapparser.dart';
import '../parser/cpdf_simple_parser.dart';

/// CID Coding schemes
enum CIDCoding {
  unknown,
  gb,
  big5,
  jis,
  korea,
  ucs2,
  cid,
  utf16,
}

/// CMap Coding schemes
enum CMapCodingScheme {
  oneByte,
  twoBytes,
  mixedTwoBytes,
  mixedFourBytes,
}

/// CMap class for CID fonts
class CMap {
  static const int kDirectMapTableSize = 65536;

  bool _loaded = false;
  bool _vertical = false;
  CIDSet _charset = CIDSet.unknown;
  CMapCodingScheme _codingScheme = CMapCodingScheme.twoBytes;
  CIDCoding _coding = CIDCoding.unknown;
  List<bool> _mixedTwoByteLeadingBytes = [];
  List<CodeRange> _mixedFourByteLeadingRanges = [];
  Uint16List _directCharcodeToCidTable = Uint16List(0);
  List<CIDRange> _additionalCharcodeToCidMappings = [];
  EmbeddedCMap? _embedMap;

  /// Constructor for predefined CMap
  CMap.predefined(String bsPredefinedName) {
    _vertical = bsPredefinedName.endsWith('V');

    if (bsPredefinedName == 'Identity-H' || bsPredefinedName == 'Identity-V') {
      _coding = CIDCoding.cid;
      _loaded = true;
      return;
    }

    final map = _getPredefinedCMap(bsPredefinedName);
    if (map == null) {
      return;
    }

    _charset = map.charset;
    _coding = map.coding;
    _codingScheme = map.codingScheme;

    if (_codingScheme == CMapCodingScheme.mixedTwoBytes) {
      _mixedTwoByteLeadingBytes = _loadLeadingSegments(map);
    }

    _embedMap = _findEmbeddedCMap(bsPredefinedName, _charset);
    if (_embedMap == null) {
      return;
    }

    _loaded = true;
  }

  /// Constructor for embedded CMap data
  CMap.embedded(Uint8List embeddedData) {
    _directCharcodeToCidTable = Uint16List(kDirectMapTableSize);

    final parser = CMapParser(this);
    final syntax = SimpleParser(embeddedData);

    while (true) {
      final word = syntax.getWord();
      if (word.isEmpty) {
        break;
      }
      parser.parseWord(word);
    }
  }

  bool get isLoaded => _loaded;
  bool get isVertWriting => _vertical;
  CIDCoding get coding => _coding;
  CIDSet get charset => _charset;

  set charset(CIDSet value) => _charset = value;
  set vertical(bool value) => _vertical = value;
  set codingScheme(CMapCodingScheme value) => _codingScheme = value;

  /// Get CID from character code
  int cidFromCharCode(int charcode) {
    if (_coding == CIDCoding.cid) {
      return charcode & 0xFFFF;
    }

    if (_embedMap != null) {
      return _embedMap!.cidFromCharCode(charcode);
    }

    if (_directCharcodeToCidTable.isEmpty) {
      return charcode & 0xFFFF;
    }

    if (charcode < _directCharcodeToCidTable.length) {
      return _directCharcodeToCidTable[charcode];
    }

    // Binary search in additional mappings
    int left = 0;
    int right = _additionalCharcodeToCidMappings.length - 1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final range = _additionalCharcodeToCidMappings[mid];

      if (charcode < range.startCode) {
        right = mid - 1;
      } else if (charcode > range.endCode) {
        left = mid + 1;
      } else {
        return range.startCid + charcode - range.startCode;
      }
    }

    return 0;
  }

  /// Get next character from string
  int getNextChar(Uint8List bytes, IntRef offset) {
    switch (_codingScheme) {
      case CMapCodingScheme.oneByte:
        return offset.value < bytes.length ? bytes[offset.value++] : 0;

      case CMapCodingScheme.twoBytes:
        final byte1 = offset.value < bytes.length ? bytes[offset.value++] : 0;
        final byte2 = offset.value < bytes.length ? bytes[offset.value++] : 0;
        return 256 * byte1 + byte2;

      case CMapCodingScheme.mixedTwoBytes:
        final byte1 = offset.value < bytes.length ? bytes[offset.value++] : 0;
        if (!_mixedTwoByteLeadingBytes[byte1]) {
          return byte1;
        }
        final byte2 = offset.value < bytes.length ? bytes[offset.value++] : 0;
        return 256 * byte1 + byte2;

      case CMapCodingScheme.mixedFourBytes:
        final codes = Uint8List(4);
        int charSize = 1;
        codes[0] = offset.value < bytes.length ? bytes[offset.value++] : 0;

        while (true) {
          final ret = _checkFourByteCodeRange(codes, charSize);
          if (ret == 0) {
            return 0;
          }
          if (ret == 2) {
            int charcode = 0;
            for (int i = 0; i < charSize; i++) {
              charcode = (charcode << 8) + codes[i];
            }
            return charcode;
          }
          if (charSize == 4 || offset.value == bytes.length) {
            return 0;
          }
          codes[charSize++] = bytes[offset.value++];
        }
    }
  }

  /// Get character size
  int getCharSize(int charcode) {
    switch (_codingScheme) {
      case CMapCodingScheme.oneByte:
        return 1;
      case CMapCodingScheme.twoBytes:
        return 2;
      case CMapCodingScheme.mixedTwoBytes:
        return charcode < 0x100 ? 1 : 2;
      case CMapCodingScheme.mixedFourBytes:
        if (charcode < 0x100) return 1;
        if (charcode < 0x10000) return 2;
        if (charcode < 0x1000000) return 3;
        return 4;
    }
  }

  /// Count characters in string
  int countChar(Uint8List bytes) {
    switch (_codingScheme) {
      case CMapCodingScheme.oneByte:
        return bytes.length;

      case CMapCodingScheme.twoBytes:
        return (bytes.length + 1) ~/ 2;

      case CMapCodingScheme.mixedTwoBytes:
        int count = 0;
        for (int i = 0; i < bytes.length; i++) {
          count++;
          if (_mixedTwoByteLeadingBytes[bytes[i]]) {
            i++;
          }
        }
        return count;

      case CMapCodingScheme.mixedFourBytes:
        int count = 0;
        final offset = IntRef(0);
        while (offset.value < bytes.length) {
          getNextChar(bytes, offset);
          count++;
        }
        return count;
    }
  }

  /// Append character to string
  void appendChar(StringBuffer str, int charcode) {
    switch (_codingScheme) {
      case CMapCodingScheme.oneByte:
        str.writeCharCode(charcode & 0xFF);
        break;

      case CMapCodingScheme.twoBytes:
        str.writeCharCode((charcode ~/ 256) & 0xFF);
        str.writeCharCode(charcode & 0xFF);
        break;

      case CMapCodingScheme.mixedTwoBytes:
        if (charcode < 0x100 && !_mixedTwoByteLeadingBytes[charcode]) {
          str.writeCharCode(charcode);
        } else {
          str.writeCharCode((charcode >> 8) & 0xFF);
          str.writeCharCode(charcode & 0xFF);
        }
        break;

      case CMapCodingScheme.mixedFourBytes:
        if (charcode < 0x100) {
          final size = _getFourByteCharSize(charcode);
          final pad = size > 0 ? size - 1 : 0;
          for (int i = 0; i < pad; i++) {
            str.writeCharCode(0);
          }
          str.writeCharCode(charcode);
        } else if (charcode < 0x10000) {
          str.writeCharCode((charcode >> 8) & 0xFF);
          str.writeCharCode(charcode & 0xFF);
        } else if (charcode < 0x1000000) {
          str.writeCharCode((charcode >> 16) & 0xFF);
          str.writeCharCode((charcode >> 8) & 0xFF);
          str.writeCharCode(charcode & 0xFF);
        } else {
          str.writeCharCode((charcode >> 24) & 0xFF);
          str.writeCharCode((charcode >> 16) & 0xFF);
          str.writeCharCode((charcode >> 8) & 0xFF);
          str.writeCharCode(charcode & 0xFF);
        }
        break;
    }
  }

  /// Set additional mappings
  void setAdditionalMappings(List<CIDRange> mappings) {
    if (_codingScheme != CMapCodingScheme.mixedFourBytes || mappings.isEmpty) {
      return;
    }

    mappings.sort((a, b) => a.endCode.compareTo(b.endCode));
    _additionalCharcodeToCidMappings = mappings;
  }

  /// Set mixed four byte leading ranges
  void setMixedFourByteLeadingRanges(List<CodeRange> ranges) {
    _mixedFourByteLeadingRanges = ranges;
  }

  /// Set direct charcode to CID table range
  void setDirectCharcodeToCIDTableRange(
      int startCode, int endCode, int startCid) {
    for (int code = startCode; code <= endCode; code++) {
      _directCharcodeToCidTable[code] = (startCid + code - startCode) & 0xFFFF;
    }
  }

  bool get isDirectCharcodeToCIDTableEmpty => _directCharcodeToCidTable.isEmpty;

  // Helper methods
  int _checkFourByteCodeRange(Uint8List codes, int charSize) {
    for (int i = _mixedFourByteLeadingRanges.length - 1; i >= 0; i--) {
      final range = _mixedFourByteLeadingRanges[i];
      if (range.charSize < charSize) {
        continue;
      }

      int iChar = 0;
      while (iChar < charSize) {
        if (codes[iChar] < range.lower[iChar] ||
            codes[iChar] > range.upper[iChar]) {
          break;
        }
        iChar++;
      }

      if (iChar == range.charSize) {
        return 2;
      }
      if (iChar > 0) {
        return charSize == range.charSize ? 2 : 1;
      }
    }
    return 0;
  }

  int _getFourByteCharSize(int charcode) {
    if (_mixedFourByteLeadingRanges.isEmpty) {
      return 1;
    }

    final codes = Uint8List(4);
    codes[0] = 0x00;
    codes[1] = 0x00;
    codes[2] = (charcode >> 8) & 0xFF;
    codes[3] = charcode & 0xFF;

    for (int offset = 0; offset < 4; offset++) {
      final size = 4 - offset;
      for (int j = _mixedFourByteLeadingRanges.length - 1; j >= 0; j--) {
        final range = _mixedFourByteLeadingRanges[j];
        if (range.charSize < size) {
          continue;
        }

        int iChar = 0;
        while (iChar < size) {
          if (codes[offset + iChar] < range.lower[iChar] ||
              codes[offset + iChar] > range.upper[iChar]) {
            break;
          }
          iChar++;
        }

        if (iChar == range.charSize) {
          return size;
        }
      }
    }
    return 1;
  }

  static List<bool> _loadLeadingSegments(PredefinedCMapInfo map) {
    final segments = List<bool>.filled(256, false);
    for (final seg in map.leadingSegs) {
      if (seg.first == 0 && seg.last == 0) {
        break;
      }
      for (int b = seg.first; b <= seg.last; b++) {
        segments[b] = true;
      }
    }
    return segments;
  }

  static PredefinedCMapInfo? _getPredefinedCMap(String cmapId) {
    String searchId = cmapId;
    if (cmapId.length > 2) {
      searchId = cmapId.substring(0, cmapId.length - 2);
    }

    for (final map in _kPredefinedCMaps) {
      if (searchId == map.name) {
        return map;
      }
    }
    return null;
  }

  static EmbeddedCMap? _findEmbeddedCMap(String name, CIDSet charset) {
    // TODO: Implement embedded CMap lookup from font globals
    return null;
  }
}

/// Code range for CMap
class CodeRange {
  final int charSize;
  final Uint8List lower;
  final Uint8List upper;

  CodeRange({
    required this.charSize,
    required this.lower,
    required this.upper,
  });
}

/// CID range for mapping
class CIDRange {
  final int startCode;
  final int endCode;
  final int startCid;

  CIDRange({
    required this.startCode,
    required this.endCode,
    required this.startCid,
  });
}

/// Byte range
class ByteRange {
  final int first;
  final int last;

  const ByteRange(this.first, this.last);
}

/// Predefined CMap information
class PredefinedCMapInfo {
  final String name;
  final CIDSet charset;
  final CIDCoding coding;
  final CMapCodingScheme codingScheme;
  final List<ByteRange> leadingSegs;

  const PredefinedCMapInfo({
    required this.name,
    required this.charset,
    required this.coding,
    required this.codingScheme,
    required this.leadingSegs,
  });
}

/// Embedded CMap (placeholder for actual implementation)
class EmbeddedCMap {
  final String name;

  EmbeddedCMap(this.name);

  int cidFromCharCode(int charcode) {
    // TODO: Implement actual embedded CMap lookup
    return charcode;
  }
}

/// Integer reference for passing by reference
class IntRef {
  int value;
  IntRef(this.value);
}

/// Predefined CMaps
const List<PredefinedCMapInfo> _kPredefinedCMaps = [
  PredefinedCMapInfo(
    name: 'GB-EUC',
    charset: CIDSet.gb1,
    coding: CIDCoding.gb,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0xa1, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'GBpc-EUC',
    charset: CIDSet.gb1,
    coding: CIDCoding.gb,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0xa1, 0xfc)],
  ),
  PredefinedCMapInfo(
    name: 'GBK-EUC',
    charset: CIDSet.gb1,
    coding: CIDCoding.gb,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'GBKp-EUC',
    charset: CIDSet.gb1,
    coding: CIDCoding.gb,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'GBK2K-EUC',
    charset: CIDSet.gb1,
    coding: CIDCoding.gb,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'GBK2K',
    charset: CIDSet.gb1,
    coding: CIDCoding.gb,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'UniGB-UCS2',
    charset: CIDSet.gb1,
    coding: CIDCoding.ucs2,
    codingScheme: CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
  PredefinedCMapInfo(
    name: 'UniGB-UTF16',
    charset: CIDSet.gb1,
    coding: CIDCoding.utf16,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
  PredefinedCMapInfo(
    name: 'B5pc',
    charset: CIDSet.cns1,
    coding: CIDCoding.big5,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0xa1, 0xfc)],
  ),
  PredefinedCMapInfo(
    name: 'HKscs-B5',
    charset: CIDSet.cns1,
    coding: CIDCoding.big5,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x88, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'ETen-B5',
    charset: CIDSet.cns1,
    coding: CIDCoding.big5,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0xa1, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'ETenms-B5',
    charset: CIDSet.cns1,
    coding: CIDCoding.big5,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0xa1, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'UniCNS-UCS2',
    charset: CIDSet.cns1,
    coding: CIDCoding.ucs2,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
  PredefinedCMapInfo(
    name: 'UniCNS-UTF16',
    charset: CIDSet.cns1,
    coding: CIDCoding.utf16,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
  PredefinedCMapInfo(
    name: '83pv-RKSJ',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0x9f), ByteRange(0xe0, 0xfc)],
  ),
  PredefinedCMapInfo(
    name: '90ms-RKSJ',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0x9f), ByteRange(0xe0, 0xfc)],
  ),
  PredefinedCMapInfo(
    name: '90msp-RKSJ',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0x9f), ByteRange(0xe0, 0xfc)],
  ),
  PredefinedCMapInfo(
    name: '90pv-RKSJ',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0x9f), ByteRange(0xe0, 0xfc)],
  ),
  PredefinedCMapInfo(
    name: 'Add-RKSJ',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0x9f), ByteRange(0xe0, 0xfc)],
  ),
  PredefinedCMapInfo(
    name: 'EUC',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x8e, 0x8e), ByteRange(0xa1, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'H',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [ByteRange(0x21, 0x7e)],
  ),
  PredefinedCMapInfo(
    name: 'V',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [ByteRange(0x21, 0x7e)],
  ),
  PredefinedCMapInfo(
    name: 'Ext-RKSJ',
    charset: CIDSet.japan1,
    coding: CIDCoding.jis,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0x9f), ByteRange(0xe0, 0xfc)],
  ),
  PredefinedCMapInfo(
    name: 'UniJIS-UCS2',
    charset: CIDSet.japan1,
    coding: CIDCoding.ucs2,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
  PredefinedCMapInfo(
    name: 'UniJIS-UCS2-HW',
    charset: CIDSet.japan1,
    coding: CIDCoding.ucs2,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
  PredefinedCMapInfo(
    name: 'UniJIS-UTF16',
    charset: CIDSet.japan1,
    coding: CIDCoding.utf16,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
  PredefinedCMapInfo(
    name: 'KSC-EUC',
    charset: CIDSet.korea1,
    coding: CIDCoding.korea,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0xa1, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'KSCms-UHC',
    charset: CIDSet.korea1,
    coding: CIDCoding.korea,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'KSCms-UHC-HW',
    charset: CIDSet.korea1,
    coding: CIDCoding.korea,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0x81, 0xfe)],
  ),
  PredefinedCMapInfo(
    name: 'KSCpc-EUC',
    charset: CIDSet.korea1,
    coding: CIDCoding.korea,
    codingScheme: CMapCodingScheme.mixedTwoBytes,
    leadingSegs: [ByteRange(0xa1, 0xfd)],
  ),
  PredefinedCMapInfo(
    name: 'UniKS-UCS2',
    charset: CIDSet.korea1,
    coding: CIDCoding.ucs2,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
  PredefinedCMapInfo(
    name: 'UniKS-UTF16',
    charset: CIDSet.korea1,
    coding: CIDCoding.utf16,
    codingScheme: CMap.CMapCodingScheme.twoBytes,
    leadingSegs: [],
  ),
];
