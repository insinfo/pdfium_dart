/// Binary buffer for building byte sequences
/// 
/// Port of core/fxcrt/binary_buffer.h

import 'dart:typed_data';

/// A growable buffer for building binary data
/// 
/// Equivalent to BinaryBuffer in PDFium
class BinaryBuffer {
  List<int> _data;
  
  /// Create an empty buffer
  BinaryBuffer() : _data = [];
  
  /// Create a buffer with initial capacity
  BinaryBuffer.withCapacity(int capacity) 
      : _data = List<int>.empty(growable: true);
  
  /// Current size of the buffer
  int get length => _data.length;
  
  /// Check if empty
  bool get isEmpty => _data.isEmpty;
  
  /// Check if not empty
  bool get isNotEmpty => _data.isNotEmpty;
  
  /// Clear the buffer
  void clear() {
    _data.clear();
  }
  
  /// Append a single byte
  void appendByte(int byte) {
    _data.add(byte & 0xFF);
  }
  
  /// Append bytes from a list
  void appendBytes(List<int> bytes) {
    _data.addAll(bytes);
  }
  
  /// Append bytes from a Uint8List
  void appendUint8List(Uint8List bytes) {
    _data.addAll(bytes);
  }
  
  /// Append a 16-bit integer (big-endian)
  void appendUint16BE(int value) {
    _data.add((value >> 8) & 0xFF);
    _data.add(value & 0xFF);
  }
  
  /// Append a 16-bit integer (little-endian)
  void appendUint16LE(int value) {
    _data.add(value & 0xFF);
    _data.add((value >> 8) & 0xFF);
  }
  
  /// Append a 32-bit integer (big-endian)
  void appendUint32BE(int value) {
    _data.add((value >> 24) & 0xFF);
    _data.add((value >> 16) & 0xFF);
    _data.add((value >> 8) & 0xFF);
    _data.add(value & 0xFF);
  }
  
  /// Append a 32-bit integer (little-endian)
  void appendUint32LE(int value) {
    _data.add(value & 0xFF);
    _data.add((value >> 8) & 0xFF);
    _data.add((value >> 16) & 0xFF);
    _data.add((value >> 24) & 0xFF);
  }
  
  /// Append a string as ASCII bytes
  void appendString(String str) {
    for (var i = 0; i < str.length; i++) {
      _data.add(str.codeUnitAt(i) & 0xFF);
    }
  }
  
  /// Get the buffer contents as Uint8List
  Uint8List toBytes() => Uint8List.fromList(_data);
  
  /// Get byte at index
  int operator [](int index) => _data[index];
  
  /// Set byte at index
  void operator []=(int index, int value) {
    _data[index] = value & 0xFF;
  }
}

/// Buffer for reading binary data
class BinaryReader {
  final Uint8List _data;
  int _position;
  
  /// Create a reader for the given data
  BinaryReader(this._data) : _position = 0;
  
  /// Create a reader from a list of bytes
  factory BinaryReader.fromList(List<int> data) {
    return BinaryReader(Uint8List.fromList(data));
  }
  
  /// Current position
  int get position => _position;
  
  /// Set position
  set position(int value) {
    _position = value.clamp(0, _data.length);
  }
  
  /// Total length
  int get length => _data.length;
  
  /// Remaining bytes
  int get remaining => _data.length - _position;
  
  /// Check if at end
  bool get isEof => _position >= _data.length;
  
  /// Read a single byte
  int readByte() {
    if (_position >= _data.length) return -1;
    return _data[_position++];
  }
  
  /// Peek at the next byte without advancing
  int peekByte() {
    if (_position >= _data.length) return -1;
    return _data[_position];
  }
  
  /// Read specified number of bytes
  Uint8List readBytes(int count) {
    final end = (_position + count).clamp(0, _data.length);
    final result = Uint8List.sublistView(_data, _position, end);
    _position = end;
    return result;
  }
  
  /// Read a 16-bit integer (big-endian)
  int readUint16BE() {
    if (remaining < 2) return 0;
    final value = (_data[_position] << 8) | _data[_position + 1];
    _position += 2;
    return value;
  }
  
  /// Read a 16-bit integer (little-endian)
  int readUint16LE() {
    if (remaining < 2) return 0;
    final value = _data[_position] | (_data[_position + 1] << 8);
    _position += 2;
    return value;
  }
  
  /// Read a 32-bit integer (big-endian)
  int readUint32BE() {
    if (remaining < 4) return 0;
    final value = (_data[_position] << 24) |
                  (_data[_position + 1] << 16) |
                  (_data[_position + 2] << 8) |
                  _data[_position + 3];
    _position += 4;
    return value;
  }
  
  /// Read a 32-bit integer (little-endian)
  int readUint32LE() {
    if (remaining < 4) return 0;
    final value = _data[_position] |
                  (_data[_position + 1] << 8) |
                  (_data[_position + 2] << 16) |
                  (_data[_position + 3] << 24);
    _position += 4;
    return value;
  }
  
  /// Skip bytes
  void skip(int count) {
    _position = (_position + count).clamp(0, _data.length);
  }
  
  /// Seek to absolute position
  void seek(int pos) {
    _position = pos.clamp(0, _data.length);
  }
  
  /// Get underlying data
  Uint8List get data => _data;
}
