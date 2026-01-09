// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG Bit Reader
/// 
/// Handles reading bits from JPEG data stream with marker handling.
library;

import 'dart:typed_data';

import 'jpeg_types.dart';

// ==========================================================
//   JPEG Bit Reader
// ==========================================================

/// Bit reader for JPEG entropy-coded data
class JpegBitReader {
  final Uint8List _data;
  int _position;
  int _bitBuffer = 0;
  int _bitsInBuffer = 0;
  bool _reachedEoi = false;

  /// Current position in data
  int get position => _position;

  /// Whether end of image marker was reached
  bool get reachedEoi => _reachedEoi;

  /// Remaining bytes
  int get remaining => _data.length - _position;

  JpegBitReader(this._data, [this._position = 0]);

  /// Seeks to a position
  void seek(int position) {
    _position = position;
    _bitBuffer = 0;
    _bitsInBuffer = 0;
  }

  /// Fills the bit buffer
  bool _fillBits() {
    while (_bitsInBuffer < 25) {
      if (_position >= _data.length) {
        return _bitsInBuffer > 0;
      }

      int byte = _data[_position++];

      // Handle marker stuffing (0xFF followed by 0x00)
      if (byte == 0xFF) {
        if (_position >= _data.length) {
          _position--;
          return _bitsInBuffer > 0;
        }

        int next = _data[_position];
        if (next == 0x00) {
          // Stuffed byte, consume it
          _position++;
        } else if (JpegMarker.isRst(0xFF00 | next)) {
          // Restart marker - don't consume, return what we have
          _position--;
          return _bitsInBuffer > 0;
        } else if (next == 0xD9) {
          // EOI marker
          _reachedEoi = true;
          _position--;
          return _bitsInBuffer > 0;
        } else {
          // Other marker - backup
          _position--;
          return _bitsInBuffer > 0;
        }
      }

      _bitBuffer = (_bitBuffer << 8) | byte;
      _bitsInBuffer += 8;
    }
    return true;
  }

  /// Reads n bits from the stream
  int readBits(int n) {
    if (n == 0) return 0;

    while (_bitsInBuffer < n) {
      if (!_fillBits()) {
        // Not enough bits, return what we can
        if (_bitsInBuffer > 0) {
          final value = _bitBuffer >> (32 - n);
          _bitsInBuffer = 0;
          _bitBuffer = 0;
          return value;
        }
        return 0;
      }
    }

    final shift = _bitsInBuffer - n;
    final value = (_bitBuffer >> shift) & ((1 << n) - 1);
    _bitsInBuffer -= n;
    _bitBuffer &= (1 << _bitsInBuffer) - 1;
    return value;
  }

  /// Peeks n bits without consuming
  int peekBits(int n) {
    while (_bitsInBuffer < n) {
      if (!_fillBits()) break;
    }

    if (_bitsInBuffer < n) return 0;

    final shift = _bitsInBuffer - n;
    return (_bitBuffer >> shift) & ((1 << n) - 1);
  }

  /// Skips n bits
  void skipBits(int n) {
    readBits(n);
  }

  /// Reads a single bit
  int readBit() {
    return readBits(1);
  }

  /// Decodes a Huffman symbol using lookup table
  int decodeHuffman(JpegHuffTable table) {
    if (table.lookupTable == null) {
      table.buildDerived();
    }

    // Fill bits if needed
    while (_bitsInBuffer < 16) {
      if (!_fillBits()) break;
    }

    // Try lookup table first
    if (_bitsInBuffer >= table.lookupBits) {
      final peek = peekBits(table.lookupBits);
      final sym = table.lookupTable![peek * 2];
      final len = table.lookupTable![peek * 2 + 1];

      if (len > 0 && len <= table.lookupBits) {
        skipBits(len);
        return sym;
      }
    }

    // Slow path for longer codes
    int code = 0;
    int k = 0;

    for (int i = 1; i <= 16; i++) {
      code = (code << 1) | readBit();

      for (int j = 0; j < table.bits[i]; j++) {
        if (code == table.huffCode![k]) {
          return table.huffVal[k];
        }
        k++;
      }
    }

    // No valid code found
    return 0;
  }

  /// Receives n bits and extends to signed
  int receive(int n) {
    if (n == 0) return 0;

    final value = readBits(n);
    return extend(value, n);
  }

  /// Extends an unsigned value to signed
  static int extend(int value, int bits) {
    if (bits == 0) return 0;
    final threshold = 1 << (bits - 1);
    if (value < threshold) {
      return value - (1 << bits) + 1;
    }
    return value;
  }

  /// Aligns to byte boundary
  void alignToByte() {
    _bitsInBuffer &= ~7;
    if (_bitsInBuffer < 0) _bitsInBuffer = 0;
  }

  /// Reads a byte directly (not bit-aligned)
  int readByte() {
    if (_position >= _data.length) return 0;
    return _data[_position++];
  }

  /// Reads a 16-bit big-endian value directly
  int readUint16BE() {
    if (_position + 1 >= _data.length) return 0;
    final high = _data[_position++];
    final low = _data[_position++];
    return (high << 8) | low;
  }

  /// Reads bytes directly
  Uint8List? readBytes(int count) {
    if (_position + count > _data.length) return null;
    final bytes = Uint8List.sublistView(_data, _position, _position + count);
    _position += count;
    return bytes;
  }

  /// Skips bytes directly
  void skip(int count) {
    _position += count;
    if (_position > _data.length) _position = _data.length;
  }

  /// Checks if a restart marker is at current position
  bool checkRestartMarker(int expectedRst) {
    if (_position + 1 >= _data.length) return false;
    if (_data[_position] == 0xFF && _data[_position + 1] == (expectedRst & 0xFF)) {
      _position += 2;
      _bitBuffer = 0;
      _bitsInBuffer = 0;
      return true;
    }
    return false;
  }

  /// Skips to the next marker
  int? findNextMarker() {
    // Align to byte boundary first
    alignToByte();

    while (_position < _data.length) {
      if (_data[_position] == 0xFF) {
        _position++;
        if (_position >= _data.length) return null;

        final code = _data[_position];
        if (code != 0x00 && code != 0xFF) {
          _position++;
          return 0xFF00 | code;
        }
      } else {
        _position++;
      }
    }
    return null;
  }
}
