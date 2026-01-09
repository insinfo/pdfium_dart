// Copyright 2016 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Original code copyright 2014 Foxit Software Inc. http://www.foxitsoftware.com

import 'dart:typed_data';

/// Simple PDF parser for basic token extraction
class SimpleParser {
  final Uint8List _data;
  int _curPosition = 0;

  SimpleParser(this._data);

  /// Get current position
  int get currentPosition => _curPosition;

  /// Set current position
  set currentPosition(int value) => _curPosition = value;

  /// Get next word from stream
  String getWord() {
    final ch = _skipSpacesAndComments();
    if (ch == null) {
      return '';
    }

    final startPos = _curPosition;

    if (ch == 0x2F) {
      // '/' - Name
      return _handleName();
    } else if (ch == 0x3C) {
      // '<'
      return _handleBeginAngleBracket();
    } else if (ch == 0x3E) {
      // '>'
      return _handleEndAngleBracket();
    } else if (ch == 0x28) {
      // '('
      return _handleParentheses();
    } else {
      return _handleNonDelimiter();
    }
  }

  // Helper methods
  int? _skipSpacesAndComments() {
    while (_curPosition < _data.length) {
      final ch = _data[_curPosition];

      // Skip whitespace
      if (_isWhitespace(ch)) {
        _curPosition++;
        continue;
      }

      // Skip comments
      if (ch == 0x25) {
        // '%' - comment
        _curPosition++;
        while (_curPosition < _data.length) {
          final c = _data[_curPosition];
          _curPosition++;
          if (c == 0x0A || c == 0x0D) {
            // '\n' or '\r'
            break;
          }
        }
        continue;
      }

      return ch;
    }
    return null;
  }

  String _handleName() {
    final startPos = _curPosition;
    _curPosition++; // Skip '/'

    while (_curPosition < _data.length) {
      final ch = _data[_curPosition];
      if (_isDelimiter(ch) || _isWhitespace(ch)) {
        break;
      }
      _curPosition++;
    }

    return String.fromCharCodes(_data.sublist(startPos, _curPosition));
  }

  String _handleBeginAngleBracket() {
    final startPos = _curPosition;
    _curPosition++; // Skip '<'

    if (_curPosition < _data.length && _data[_curPosition] == 0x3C) {
      // '<<'
      _curPosition++;
      return '<<';
    }

    // Hex string
    while (_curPosition < _data.length) {
      final ch = _data[_curPosition];
      _curPosition++;
      if (ch == 0x3E) {
        // '>'
        break;
      }
    }

    return String.fromCharCodes(_data.sublist(startPos, _curPosition));
  }

  String _handleEndAngleBracket() {
    final startPos = _curPosition;
    _curPosition++; // Skip '>'

    if (_curPosition < _data.length && _data[_curPosition] == 0x3E) {
      // '>>'
      _curPosition++;
    }

    return String.fromCharCodes(_data.sublist(startPos, _curPosition));
  }

  String _handleParentheses() {
    final startPos = _curPosition;
    _curPosition++; // Skip '('

    int level = 1;
    while (_curPosition < _data.length && level > 0) {
      final ch = _data[_curPosition];
      _curPosition++;

      if (ch == 0x28) {
        // '('
        level++;
      } else if (ch == 0x29) {
        // ')'
        level--;
      } else if (ch == 0x5C) {
        // '\' - escape
        if (_curPosition < _data.length) {
          _curPosition++;
        }
      }
    }

    return String.fromCharCodes(_data.sublist(startPos, _curPosition));
  }

  String _handleNonDelimiter() {
    final startPos = _curPosition;

    while (_curPosition < _data.length) {
      final ch = _data[_curPosition];
      if (_isDelimiter(ch) || _isWhitespace(ch)) {
        break;
      }
      _curPosition++;
    }

    return String.fromCharCodes(_data.sublist(startPos, _curPosition));
  }

  bool _isWhitespace(int ch) {
    return ch == 0x00 || // NULL
        ch == 0x09 || // TAB
        ch == 0x0A || // LF
        ch == 0x0C || // FF
        ch == 0x0D || // CR
        ch == 0x20; // SPACE
  }

  bool _isDelimiter(int ch) {
    return ch == 0x28 || // '('
        ch == 0x29 || // ')'
        ch == 0x3C || // '<'
        ch == 0x3E || // '>'
        ch == 0x5B || // '['
        ch == 0x5D || // ']'
        ch == 0x7B || // '{'
        ch == 0x7D || // '}'
        ch == 0x2F || // '/'
        ch == 0x25; // '%'
  }
}
