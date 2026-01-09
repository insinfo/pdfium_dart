// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG XL bit reader.
///
/// 64-bit buffer with support for deferred refills.
library;

import 'dart:typed_data';

/// Bit reader for JPEG XL bitstream
class JxlBitReader {
  final Uint8List _data;
  int _pos = 0;
  int _buf = 0;
  int _bitsInBuf = 0;

  /// Maximum bits that can be read in one call
  static const int maxBitsPerCall = 56;

  JxlBitReader(this._data);

  /// Creates from a byte array
  factory JxlBitReader.fromBytes(Uint8List data) {
    final reader = JxlBitReader(data);
    reader._refill();
    return reader;
  }

  /// Current byte position in stream
  int get position => _pos - (_bitsInBuf >> 3);

  /// Total bytes in stream
  int get length => _data.length;

  /// Remaining bytes
  int get remaining => length - position;

  /// Whether at end of stream
  bool get isAtEnd => _pos >= _data.length && _bitsInBuf == 0;

  /// Total bits consumed
  int get totalBitsConsumed => (_pos * 8) - _bitsInBuf;

  /// Refills the buffer with more bits
  void _refill() {
    while (_bitsInBuf <= 56 && _pos < _data.length) {
      _buf |= _data[_pos] << _bitsInBuf;
      _pos++;
      _bitsInBuf += 8;
    }
  }

  /// Ensures buffer has at least nbits available
  void refill() {
    if (_bitsInBuf < 56) {
      _refill();
    }
  }

  /// Peeks at nbits without consuming them
  int peekBits(int nbits) {
    assert(nbits <= maxBitsPerCall);
    if (nbits == 0) return 0;
    final mask = (1 << nbits) - 1;
    return _buf & mask;
  }

  /// Consumes nbits from the buffer
  void consume(int nbits) {
    assert(nbits <= _bitsInBuf);
    _bitsInBuf -= nbits;
    _buf >>= nbits;
  }

  /// Reads nbits from the stream
  int readBits(int nbits) {
    refill();
    final bits = peekBits(nbits);
    consume(nbits);
    return bits;
  }

  /// Reads a single bit
  int readBit() => readBits(1);

  /// Reads a U32 with variable encoding
  /// 
  /// JXL uses a compact encoding for U32:
  /// - First 2 bits indicate encoding type
  /// - Type 0: value is 0
  /// - Type 1: value is 1 + next 4 bits
  /// - Type 2: value is 17 + next 8 bits  
  /// - Type 3: value is next 32 bits
  int readU32(int selector, List<int> bits, List<int> offsets) {
    refill();
    final sel = peekBits(selector);
    consume(selector);
    
    if (sel < bits.length) {
      final numBits = bits[sel];
      if (numBits == 0) {
        return offsets[sel];
      }
      final value = readBits(numBits);
      return offsets[sel] + value;
    }
    return 0;
  }

  /// Reads a U64 with variable encoding
  int readU64() {
    refill();
    final selector = readBits(2);
    switch (selector) {
      case 0:
        return 0;
      case 1:
        return 1 + readBits(4);
      case 2:
        return 17 + readBits(8);
      case 3:
        // Read 12 bits at a time
        int value = readBits(12);
        int shift = 12;
        while (readBit() == 1) {
          if (shift >= 60) {
            value |= readBits(4) << shift;
            break;
          }
          value |= readBits(8) << shift;
          shift += 8;
        }
        return value;
      default:
        return 0;
    }
  }

  /// Reads a boolean (1 bit)
  bool readBool() => readBit() == 1;

  /// Reads an enum value encoded with variable bits
  int readEnum(int maxValue) {
    if (maxValue == 0) return 0;
    int bits = 0;
    int temp = maxValue;
    while (temp > 0) {
      bits++;
      temp >>= 1;
    }
    return readBits(bits);
  }

  /// Reads bytes into a buffer
  void readBytes(Uint8List buffer, int offset, int count) {
    // Align to byte boundary first
    final extraBits = _bitsInBuf & 7;
    if (extraBits != 0) {
      consume(extraBits);
    }

    // Copy any remaining buffered bytes
    while (count > 0 && _bitsInBuf >= 8) {
      buffer[offset++] = _buf & 0xFF;
      consume(8);
      count--;
    }

    // Copy directly from source
    while (count > 0 && _pos < _data.length) {
      buffer[offset++] = _data[_pos++];
      count--;
    }
  }

  /// Skips nbits
  void skipBits(int nbits) {
    while (nbits > 0) {
      refill();
      final toSkip = nbits < _bitsInBuf ? nbits : _bitsInBuf;
      consume(toSkip);
      nbits -= toSkip;
    }
  }

  /// Aligns to byte boundary
  void alignToByte() {
    final extraBits = _bitsInBuf & 7;
    if (extraBits != 0) {
      consume(extraBits);
    }
  }

  /// Reads a fixed-point value with given precision
  double readFixedPoint(int intBits, int fracBits) {
    final totalBits = intBits + fracBits;
    final value = readBits(totalBits);
    return value / (1 << fracBits);
  }

  /// Reads an F16 (half-precision float)
  double readF16() {
    final bits = readBits(16);
    return _decodeF16(bits);
  }

  /// Decodes half-precision float
  double _decodeF16(int bits) {
    final sign = (bits >> 15) & 1;
    final exp = (bits >> 10) & 0x1F;
    final frac = bits & 0x3FF;

    double value;
    if (exp == 0) {
      // Denormalized
      value = (frac / 1024.0) * (1.0 / 16384.0);
    } else if (exp == 31) {
      // Inf/NaN
      value = frac == 0 ? double.infinity : double.nan;
    } else {
      // Normalized
      value = (1.0 + frac / 1024.0) * (1 << (exp - 15));
    }

    return sign == 1 ? -value : value;
  }

  /// Reads a compact size value
  int readSize() {
    refill();
    final small = readBit();
    if (small == 1) {
      // Small size: 5 bits for ysize_div8_minus_1
      final ysizeDiv8Minus1 = readBits(5);
      return (ysizeDiv8Minus1 + 1) * 8;
    } else {
      // Large size: variable encoding
      final selector = readBits(2);
      switch (selector) {
        case 0:
          return 1 + readBits(9); // 1-512
        case 1:
          return 1 + readBits(13); // 1-8192
        case 2:
          return 1 + readBits(18); // 1-262144
        case 3:
          return 1 + readBits(30); // 1-1073741824
        default:
          return 0;
      }
    }
  }

  /// Creates a sub-reader for a portion of the stream
  JxlBitReader subReader(int numBytes) {
    alignToByte();
    final start = position;
    final end = start + numBytes;
    if (end > _data.length) {
      return JxlBitReader(Uint8List(0));
    }
    final subData = Uint8List.sublistView(_data, start, end);
    skipBits(numBytes * 8);
    return JxlBitReader.fromBytes(subData);
  }
}

/// Entropy decoder for ANS (Asymmetric Numeral Systems)
class JxlAnsDecoder {
  final JxlBitReader _reader;
  int _state = 0;

  static const int _ansP8Shift = 8;
  static const int _ansStateBits = 32;
  static const int _ansSignatureBits = 16;

  JxlAnsDecoder(this._reader);

  /// Initializes ANS state from stream
  void init() {
    _state = _reader.readBits(_ansStateBits);
  }

  /// Reads ANS checksum/signature
  bool readChecksum() {
    final signature = _reader.readBits(_ansSignatureBits);
    return signature == (_state & ((1 << _ansSignatureBits) - 1));
  }

  /// Decodes a symbol using distribution table
  int decode(List<int> distribution, int log2BucketSize) {
    final bucketSize = 1 << log2BucketSize;
    final bucketIndex = _state & (bucketSize - 1);
    
    // Find symbol
    int symbol = 0;
    int cumulative = 0;
    for (int i = 0; i < distribution.length; i++) {
      if (cumulative + distribution[i] > bucketIndex) {
        symbol = i;
        break;
      }
      cumulative += distribution[i];
    }

    // Update state
    final freq = distribution[symbol];
    _state = freq * (_state >> log2BucketSize) + bucketIndex - cumulative;

    // Refill if needed
    while (_state < (1 << (_ansStateBits - 16))) {
      _state = (_state << 16) | _reader.readBits(16);
    }

    return symbol;
  }
}

/// Huffman decoder
class JxlHuffmanDecoder {
  final List<int> _symbols;
  final List<int> _lengths;
  final int _maxLength;

  JxlHuffmanDecoder(this._symbols, this._lengths, this._maxLength);

  /// Builds a Huffman decoder from code lengths
  factory JxlHuffmanDecoder.fromLengths(List<int> lengths) {
    final maxLength = lengths.reduce((a, b) => a > b ? a : b);
    final symbols = List<int>.filled(1 << maxLength, 0);
    final sortedLengths = List<int>.from(lengths);

    // Build lookup table
    int code = 0;
    for (int len = 1; len <= maxLength; len++) {
      for (int sym = 0; sym < lengths.length; sym++) {
        if (lengths[sym] == len) {
          final base = code << (maxLength - len);
          final count = 1 << (maxLength - len);
          for (int i = 0; i < count; i++) {
            symbols[base + i] = sym;
          }
          code++;
        }
      }
      code <<= 1;
    }

    return JxlHuffmanDecoder(symbols, sortedLengths, maxLength);
  }

  /// Decodes a symbol
  int decode(JxlBitReader reader) {
    reader.refill();
    final index = reader.peekBits(_maxLength);
    final symbol = _symbols[index];
    reader.consume(_lengths[symbol]);
    return symbol;
  }
}
