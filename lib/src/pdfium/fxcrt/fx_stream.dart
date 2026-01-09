/// Stream interfaces for PDFium Dart
/// 
/// Port of core/fxcrt/fx_stream.h

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'fx_types.dart';

/// Interface for reading data from a source
/// 
/// Equivalent to IFX_SeekableReadStream in PDFium
abstract class SeekableReadStream {
  /// Get the total size of the stream
  int get size;
  
  /// Read data from the stream at specified position
  /// 
  /// Returns the bytes read, or null on failure
  Uint8List? readBlock(int offset, int size);
  
  /// Check if the stream is valid/open
  bool get isValid;
  
  /// Close the stream
  void close();
}

/// Interface for writing data to a destination
/// 
/// Equivalent to IFX_SeekableWriteStream in PDFium
abstract class SeekableWriteStream {
  /// Write data to the stream
  /// 
  /// Returns true on success
  bool writeBlock(Uint8List data);
  
  /// Flush any buffered data
  bool flush();
  
  /// Close the stream
  void close();
}

/// Read stream backed by a memory buffer
class MemoryReadStream implements SeekableReadStream {
  final Uint8List _data;
  bool _closed = false;
  
  MemoryReadStream(this._data);
  
  factory MemoryReadStream.fromList(List<int> data) {
    return MemoryReadStream(Uint8List.fromList(data));
  }
  
  @override
  int get size => _data.length;
  
  @override
  bool get isValid => !_closed;
  
  @override
  Uint8List? readBlock(int offset, int size) {
    if (_closed) return null;
    if (offset < 0 || offset >= _data.length) return null;
    
    final end = (offset + size).clamp(0, _data.length);
    final actualSize = end - offset;
    if (actualSize <= 0) return null;
    
    return Uint8List.sublistView(_data, offset, end);
  }
  
  @override
  void close() {
    _closed = true;
  }
  
  /// Get the underlying data (for efficient access)
  Uint8List get data => _data;
}

/// Write stream backed by a growing memory buffer
class MemoryWriteStream implements SeekableWriteStream {
  final List<int> _buffer = [];
  bool _closed = false;
  
  @override
  bool writeBlock(Uint8List data) {
    if (_closed) return false;
    _buffer.addAll(data);
    return true;
  }
  
  @override
  bool flush() => !_closed;
  
  @override
  void close() {
    _closed = true;
  }
  
  /// Get the written data
  Uint8List toBytes() => Uint8List.fromList(_buffer);
  
  /// Get current size
  int get size => _buffer.length;
}

/// Read stream backed by a file
class FileReadStream implements SeekableReadStream {
  final RandomAccessFile _file;
  final int _size;
  bool _closed = false;
  
  FileReadStream._(this._file, this._size);
  
  /// Open a file for reading
  static Future<FileReadStream?> open(String path) async {
    try {
      final file = await File(path).open(mode: FileMode.read);
      final size = await file.length();
      return FileReadStream._(file, size);
    } catch (_) {
      return null;
    }
  }
  
  /// Open a file synchronously
  static FileReadStream? openSync(String path) {
    try {
      final file = File(path).openSync(mode: FileMode.read);
      final size = file.lengthSync();
      return FileReadStream._(file, size);
    } catch (_) {
      return null;
    }
  }
  
  @override
  int get size => _size;
  
  @override
  bool get isValid => !_closed;
  
  @override
  Uint8List? readBlock(int offset, int size) {
    if (_closed) return null;
    if (offset < 0 || offset >= _size) return null;
    
    try {
      _file.setPositionSync(offset);
      final actualSize = (offset + size > _size) ? _size - offset : size;
      return _file.readSync(actualSize);
    } catch (_) {
      return null;
    }
  }
  
  @override
  void close() {
    if (!_closed) {
      _closed = true;
      _file.closeSync();
    }
  }
}

/// Write stream backed by a file
class FileWriteStream implements SeekableWriteStream {
  final RandomAccessFile _file;
  bool _closed = false;
  
  FileWriteStream._(this._file);
  
  /// Create/open a file for writing
  static Future<FileWriteStream?> create(String path) async {
    try {
      final file = await File(path).open(mode: FileMode.write);
      return FileWriteStream._(file);
    } catch (_) {
      return null;
    }
  }
  
  /// Create/open a file synchronously
  static FileWriteStream? createSync(String path) {
    try {
      final file = File(path).openSync(mode: FileMode.write);
      return FileWriteStream._(file);
    } catch (_) {
      return null;
    }
  }
  
  @override
  bool writeBlock(Uint8List data) {
    if (_closed) return false;
    try {
      _file.writeFromSync(data);
      return true;
    } catch (_) {
      return false;
    }
  }
  
  @override
  bool flush() {
    if (_closed) return false;
    try {
      _file.flushSync();
      return true;
    } catch (_) {
      return false;
    }
  }
  
  @override
  void close() {
    if (!_closed) {
      _closed = true;
      _file.closeSync();
    }
  }
}

/// A buffered reader that provides convenient parsing methods
class BufferedReader {
  final SeekableReadStream _stream;
  Uint8List _buffer;
  int _bufferStart;
  int _bufferEnd;
  int _position;
  
  static const int _defaultBufferSize = 65536; // 64KB
  
  BufferedReader(this._stream, {int bufferSize = _defaultBufferSize})
      : _buffer = Uint8List(0),
        _bufferStart = 0,
        _bufferEnd = 0,
        _position = 0;
  
  /// Current position in the stream
  int get position => _position;
  
  /// Set position
  set position(int value) {
    _position = value.clamp(0, _stream.size);
  }
  
  /// Total size of the stream
  int get size => _stream.size;
  
  /// Check if at end of stream
  bool get isEof => _position >= _stream.size;
  
  /// Bytes remaining
  int get remaining => _stream.size - _position;
  
  /// Read a single byte, returns -1 on EOF
  int readByte() {
    if (_position >= _stream.size) return -1;
    
    if (_position < _bufferStart || _position >= _bufferEnd) {
      _fillBuffer(_position);
    }
    
    if (_position >= _bufferEnd) return -1;
    return _buffer[_position++ - _bufferStart];
  }
  
  /// Peek at the next byte without consuming it, returns -1 on EOF
  int peekByte() {
    if (_position >= _stream.size) return -1;
    
    if (_position < _bufferStart || _position >= _bufferEnd) {
      _fillBuffer(_position);
    }
    
    if (_position >= _bufferEnd) return -1;
    return _buffer[_position - _bufferStart];
  }
  
  /// Read specified number of bytes
  Uint8List? readBytes(int count) {
    if (_position >= _stream.size || count <= 0) return null;
    
    final actualCount = (_position + count > _stream.size) 
        ? _stream.size - _position 
        : count;
    
    final data = _stream.readBlock(_position, actualCount);
    if (data != null) {
      _position += data.length;
    }
    return data;
  }
  
  /// Skip specified number of bytes
  void skip(int count) {
    _position = (_position + count).clamp(0, _stream.size);
  }
  
  /// Seek to absolute position
  void seek(int pos) {
    _position = pos.clamp(0, _stream.size);
  }
  
  void _fillBuffer(int position) {
    final readPos = position;
    final readSize = (_stream.size - readPos).clamp(0, _defaultBufferSize);
    
    if (readSize <= 0) {
      _buffer = Uint8List(0);
      _bufferStart = position;
      _bufferEnd = position;
      return;
    }
    
    final data = _stream.readBlock(readPos, readSize);
    if (data != null) {
      _buffer = data;
      _bufferStart = readPos;
      _bufferEnd = readPos + data.length;
    }
  }
}

/// Extension for ByteSpan to create streams
extension ByteSpanStream on ByteSpan {
  /// Create a read stream from this span
  MemoryReadStream toStream() => MemoryReadStream(toBytes());
}
