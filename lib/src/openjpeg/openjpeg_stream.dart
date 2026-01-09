// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// OpenJPEG I/O stream.
/// 
/// Port of stream structures from openjpeg.h and cio.h.
library;

import 'dart:typed_data';

// ==========================================================
//   Stream Interface
// ==========================================================

/// Abstract base class for OpenJPEG streams
abstract class OpjStream {
  /// Current position in the stream
  int get position;
  
  /// Total length of the stream (if known)
  int get length;
  
  /// Whether we're at end of stream
  bool get isEof;
  
  /// Reads up to [count] bytes into buffer
  /// Returns actual number of bytes read, or -1 on error/EOF
  int read(Uint8List buffer, int count);
  
  /// Reads a single byte, returns -1 on EOF
  int readByte();
  
  /// Skips [count] bytes forward
  /// Returns true on success
  bool skip(int count);
  
  /// Seeks to absolute position
  /// Returns true on success
  bool seek(int position);
  
  /// Closes the stream
  void close();
}

// ==========================================================
//   Memory Stream
// ==========================================================

/// Memory-backed read stream
class OpjMemoryStream extends OpjStream {
  final Uint8List _data;
  int _position = 0;
  bool _closed = false;

  OpjMemoryStream(this._data);

  /// Creates a stream from a copy of the data
  factory OpjMemoryStream.fromList(List<int> data) {
    return OpjMemoryStream(Uint8List.fromList(data));
  }

  @override
  int get position => _position;

  @override
  int get length => _data.length;

  @override
  bool get isEof => _position >= _data.length;

  @override
  int read(Uint8List buffer, int count) {
    if (_closed || isEof) return -1;
    
    final available = _data.length - _position;
    final toRead = count < available ? count : available;
    
    if (toRead <= 0) return -1;
    
    buffer.setRange(0, toRead, _data, _position);
    _position += toRead;
    
    return toRead;
  }

  @override
  int readByte() {
    if (_closed || isEof) return -1;
    return _data[_position++];
  }

  @override
  bool skip(int count) {
    if (_closed) return false;
    
    final newPos = _position + count;
    if (newPos < 0 || newPos > _data.length) return false;
    
    _position = newPos;
    return true;
  }

  @override
  bool seek(int position) {
    if (_closed) return false;
    if (position < 0 || position > _data.length) return false;
    
    _position = position;
    return true;
  }

  @override
  void close() {
    _closed = true;
  }

  /// Peeks at bytes without advancing position
  int peek(int offset) {
    final pos = _position + offset;
    if (pos < 0 || pos >= _data.length) return -1;
    return _data[pos];
  }

  /// Gets remaining bytes in stream
  int get remaining => _data.length - _position;

  /// Reads a big-endian 16-bit unsigned integer
  int readUint16BE() {
    if (remaining < 2) return -1;
    final b1 = _data[_position++];
    final b2 = _data[_position++];
    return (b1 << 8) | b2;
  }

  /// Reads a big-endian 32-bit unsigned integer
  int readUint32BE() {
    if (remaining < 4) return -1;
    final b1 = _data[_position++];
    final b2 = _data[_position++];
    final b3 = _data[_position++];
    final b4 = _data[_position++];
    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
  }

  /// Reads a big-endian 64-bit unsigned integer
  int readUint64BE() {
    if (remaining < 8) return -1;
    final high = readUint32BE();
    final low = readUint32BE();
    return (high << 32) | low;
  }

  /// Reads bytes into a new Uint8List
  Uint8List? readBytes(int count) {
    if (remaining < count) return null;
    final result = Uint8List(count);
    read(result, count);
    return result;
  }
}

// ==========================================================
//   Bit I/O
// ==========================================================

/// Bit input/output for entropy coding
class OpjBitIO {
  Uint8List? _data;
  int _position = 0;
  int _buffer = 0;
  int _count = 0;
  int _start = 0;
  int _end = 0;

  OpjBitIO();

  /// Initializes for reading
  void initRead(Uint8List data, int start, int length) {
    _data = data;
    _start = start;
    _position = start;
    _end = start + length;
    _buffer = 0;
    _count = 0;
  }

  /// Number of bytes read
  int get bytesRead => _position - _start;

  /// Reads a single bit
  int readBit() {
    if (_count == 0) {
      if (_position >= _end) return 0;
      _buffer = _data![_position++];
      _count = 8;
      // Check for bit-stuffing after 0xFF
      if (_position > _start + 1 && _data![_position - 2] == 0xFF) {
        _count = 7;
      }
    }
    _count--;
    return (_buffer >> _count) & 1;
  }

  /// Reads multiple bits
  int readBits(int numBits) {
    var result = 0;
    for (var i = numBits - 1; i >= 0; i--) {
      result |= readBit() << i;
    }
    return result;
  }

  /// Aligns to byte boundary
  void byteAlign() {
    _count = 0;
    _buffer = 0;
  }
}

// ==========================================================
//   Codestream I/O Helper
// ==========================================================

/// Helper class for reading JPEG2000 codestream data
class J2kStreamReader {
  final OpjMemoryStream _stream;
  
  J2kStreamReader(this._stream);

  /// Current position
  int get position => _stream.position;

  /// Stream length
  int get length => _stream.length;

  /// Remaining bytes
  int get remaining => _stream.remaining;

  /// Whether at end of stream
  bool get isEof => _stream.isEof;

  /// Seeks to position
  bool seek(int pos) => _stream.seek(pos);

  /// Skips bytes
  bool skip(int count) => _stream.skip(count);

  /// Reads a byte
  int readByte() => _stream.readByte();

  /// Reads 16-bit big-endian
  int readUint16() => _stream.readUint16BE();

  /// Reads 32-bit big-endian
  int readUint32() => _stream.readUint32BE();

  /// Reads bytes
  Uint8List? readBytes(int count) => _stream.readBytes(count);

  /// Peeks at a marker (2 bytes) without advancing
  int peekMarker() {
    final b1 = _stream.peek(0);
    final b2 = _stream.peek(1);
    if (b1 < 0 || b2 < 0) return -1;
    return (b1 << 8) | b2;
  }

  /// Reads a marker
  int readMarker() => readUint16();

  /// Checks if next bytes are a marker (0xFFxx where xx >= 0x01)
  bool isNextMarker() {
    final b1 = _stream.peek(0);
    final b2 = _stream.peek(1);
    return b1 == 0xFF && b2 >= 0x01 && b2 != 0xFF;
  }

  /// Finds the next marker in stream
  int findNextMarker() {
    while (!isEof) {
      final b = readByte();
      if (b == 0xFF) {
        final next = _stream.peek(0);
        if (next >= 0x01 && next != 0xFF) {
          // Found marker
          return (0xFF << 8) | readByte();
        }
      }
    }
    return -1;
  }

  /// Reads marker segment length (following marker)
  int readMarkerLength() {
    final len = readUint16();
    return len - 2; // Length includes the 2 bytes of length field
  }
}

// ==========================================================
//   Write Stream
// ==========================================================

/// Memory-backed write stream
class OpjWriteStream {
  final BytesBuilder _builder = BytesBuilder();
  
  OpjWriteStream();

  /// Current length
  int get length => _builder.length;

  /// Writes a byte
  void writeByte(int byte) {
    _builder.addByte(byte);
  }

  /// Writes bytes
  void writeBytes(List<int> bytes) {
    _builder.add(bytes);
  }

  /// Writes 16-bit big-endian
  void writeUint16BE(int value) {
    _builder.addByte((value >> 8) & 0xFF);
    _builder.addByte(value & 0xFF);
  }

  /// Writes 32-bit big-endian
  void writeUint32BE(int value) {
    _builder.addByte((value >> 24) & 0xFF);
    _builder.addByte((value >> 16) & 0xFF);
    _builder.addByte((value >> 8) & 0xFF);
    _builder.addByte(value & 0xFF);
  }

  /// Gets the written data
  Uint8List toBytes() {
    return _builder.toBytes();
  }

  /// Clears the stream
  void clear() {
    _builder.clear();
  }
}
