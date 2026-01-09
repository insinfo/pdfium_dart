// Copyright 2014 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Original code copyright 2014 Foxit Software Inc. http://www.foxitsoftware.com

import 'dart:typed_data';
import 'cpdf_cmap.dart';
import 'cpdf_cidfont.dart';

/// CMap parser for parsing embedded CMap data
class CMapParser {
  /// Parser status
  enum _Status {
    start,
    processingCidChar,
    processingCidRange,
    processingRegistry,
    processingOrdering,
    processingSupplement,
    processingWMode,
    processingCodeSpaceRange,
  }

  _Status _status = _Status.start;
  int _codeSeq = 0;
  final CMap _cmap;
  final List<CodeRange> _ranges = [];
  final List<CodeRange> _pendingRanges = [];
  final List<CIDRange> _additionalCharcodeToCidMappings = [];
  String _lastWord = '';
  final List<int> _codePoints = [0, 0, 0, 0];

  CMapParser(this._cmap);

  /// Finalize parsing
  void finalize() {
    _cmap.setAdditionalMappings(_additionalCharcodeToCidMappings);
    _cmap.setMixedFourByteLeadingRanges(_ranges);
  }

  /// Parse a word from CMap stream
  void parseWord(String word) {
    if (word.isEmpty) {
      return;
    }

    if (word == 'begincidchar') {
      _status = _Status.processingCidChar;
      _codeSeq = 0;
    } else if (word == 'begincidrange') {
      _status = _Status.processingCidRange;
      _codeSeq = 0;
    } else if (word == 'endcidrange' || word == 'endcidchar') {
      _status = _Status.start;
    } else if (word == '/WMode') {
      _status = _Status.processingWMode;
    } else if (word == '/Registry') {
      _status = _Status.processingRegistry;
    } else if (word == '/Ordering') {
      _status = _Status.processingOrdering;
    } else if (word == '/Supplement') {
      _status = _Status.processingSupplement;
    } else if (word == 'begincodespacerange') {
      _status = _Status.processingCodeSpaceRange;
      _codeSeq = 0;
    } else if (word == 'usecmap') {
      // Handle usecmap if needed
    } else if (_status == _Status.processingCidChar) {
      _handleCid(word);
    } else if (_status == _Status.processingCidRange) {
      _handleCid(word);
    } else if (_status == _Status.processingRegistry) {
      _status = _Status.start;
    } else if (_status == _Status.processingOrdering) {
      _cmap.charset = charsetFromOrdering(_cmapGetString(word));
      _status = _Status.start;
    } else if (_status == _Status.processingSupplement) {
      _status = _Status.start;
    } else if (_status == _Status.processingWMode) {
      _cmap.vertical = getCode(word) != 0;
      _status = _Status.start;
    } else if (_status == _Status.processingCodeSpaceRange) {
      _handleCodeSpaceRange(word);
    }
    
    _lastWord = word;
  }

  /// Handle CID character or range
  void _handleCid(String word) {
    final bChar = _status == _Status.processingCidChar;

    _codePoints[_codeSeq] = getCode(word);
    _codeSeq++;
    
    final nRequiredCodePoints = bChar ? 2 : 3;
    if (_codeSeq < nRequiredCodePoints) {
      return;
    }

    final startCode = _codePoints[0];
    final endCode = bChar ? startCode : _codePoints[1];
    final startCID = bChar ? _codePoints[1] : _codePoints[2];

    if (endCode < CMap.kDirectMapTableSize) {
      _cmap.setDirectCharcodeToCIDTableRange(startCode, endCode, startCID);
    } else {
      _additionalCharcodeToCidMappings.add(CIDRange(
        startCode: startCode,
        endCode: endCode,
        startCid: startCID,
      ));
    }
    
    _codeSeq = 0;
  }

  /// Handle code space range
  void _handleCodeSpaceRange(String word) {
    if (word != 'endcodespacerange') {
      if (word.isEmpty || word[0] != '<') {
        return;
      }

      if (_codeSeq % 2 == 1) {
        final range = getCodeRange(_lastWord, word);
        if (range != null) {
          _pendingRanges.add(range);
        }
      }
      _codeSeq++;
      return;
    }

    final nSegs = _ranges.length + _pendingRanges.length;
    if (nSegs == 1) {
      final firstRange = _ranges.isNotEmpty ? _ranges[0] : _pendingRanges[0];
      _cmap.codingScheme = firstRange.charSize == 2
          ? CMapCodingScheme.twoBytes
          : CMapCodingScheme.oneByte;
    } else if (nSegs > 1) {
      _cmap.codingScheme = CMapCodingScheme.mixedFourBytes;
      _ranges.addAll(_pendingRanges);
      _pendingRanges.clear();
    }
    _status = _Status.start;
  }

  /// Get code from word
  static int getCode(String word) {
    if (word.isEmpty) {
      return 0;
    }

    int num = 0;
    if (word[0] == '<') {
      // Hex number
      for (int i = 1; i < word.length && _isHexDigit(word[i]); i++) {
        final digit = _hexCharToInt(word[i]);
        if (num > 0xFFFFFFF) {
          // Overflow check
          return 0;
        }
        num = num * 16 + digit;
      }
      return num;
    }

    // Decimal number
    for (int i = 0; i < word.length && _isDecimalDigit(word[i]); i++) {
      final digit = _decimalCharToInt(word[i]);
      if (num > 429496729) {
        // Overflow check (0xFFFFFFFF / 10)
        return 0;
      }
      num = num * 10 + digit;
    }
    return num;
  }

  /// Get code range from two words
  static CodeRange? getCodeRange(String first, String second) {
    if (first.isEmpty || first[0] != '<') {
      return null;
    }

    int i;
    for (i = 1; i < first.length; i++) {
      if (first[i] == '>') {
        break;
      }
    }
    
    final charSize = (i - 1) ~/ 2;
    if (charSize > 4) {
      return null;
    }

    final lower = Uint8List(4);
    final upper = Uint8List(4);

    // Parse lower bound
    for (i = 0; i < charSize; i++) {
      final digit1 = first[i * 2 + 1];
      final digit2 = first[i * 2 + 2];
      lower[i] = _hexCharToInt(digit1) * 16 + _hexCharToInt(digit2);
    }

    // Parse upper bound
    final size = second.length;
    for (i = 0; i < charSize; i++) {
      final i1 = i * 2 + 1;
      final i2 = i1 + 1;
      final digit1 = i1 < size ? second[i1] : '0';
      final digit2 = i2 < size ? second[i2] : '0';
      upper[i] = _hexCharToInt(digit1) * 16 + _hexCharToInt(digit2);
    }

    return CodeRange(
      charSize: charSize,
      lower: lower,
      upper: upper,
    );
  }

  /// Get charset from ordering string
  static CIDSet charsetFromOrdering(String ordering) {
    const charsetNames = [
      '',
      'GB1',
      'CNS1',
      'Japan1',
      'Korea1',
      'UCS',
    ];

    for (int i = 1; i < charsetNames.length; i++) {
      if (ordering == charsetNames[i]) {
        return CIDSet.values[i];
      }
    }
    return CIDSet.unknown;
  }

  // Helper functions
  static String _cmapGetString(String word) {
    if (word.length <= 2) {
      return '';
    }
    return word.substring(2);
  }

  static bool _isHexDigit(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 70) || // A-F
        (code >= 97 && code <= 102); // a-f
  }

  static bool _isDecimalDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57; // 0-9
  }

  static int _hexCharToInt(String char) {
    final code = char.codeUnitAt(0);
    if (code >= 48 && code <= 57) return code - 48; // 0-9
    if (code >= 65 && code <= 70) return code - 55; // A-F
    if (code >= 97 && code <= 102) return code - 87; // a-f
    return 0;
  }

  static int _decimalCharToInt(String char) {
    return char.codeUnitAt(0) - 48;
  }
}
