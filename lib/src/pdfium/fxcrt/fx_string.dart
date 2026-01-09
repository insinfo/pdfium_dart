/// String handling for PDFium Dart
/// 
/// Port of core/fxcrt/bytestring.h and widestring.h

import 'dart:convert';
import 'dart:typed_data';

/// Byte string - sequence of 8-bit characters
/// 
/// Equivalent to ByteString in PDFium (core/fxcrt/bytestring.h)
/// Used for PDF keywords, names, and ASCII strings.
class ByteString implements Comparable<ByteString> {
  final Uint8List _data;
  
  ByteString._(this._data);
  
  /// Create an empty byte string
  factory ByteString.empty() => ByteString._(Uint8List(0));
  
  /// Create from a Dart string (Latin-1 encoding)
  factory ByteString.fromString(String str) {
    return ByteString._(Uint8List.fromList(latin1.encode(str)));
  }
  
  /// Create from bytes
  factory ByteString.fromBytes(List<int> bytes) {
    return ByteString._(Uint8List.fromList(bytes));
  }
  
  /// Create from Uint8List (efficient, no copy)
  factory ByteString.fromUint8List(Uint8List data) {
    return ByteString._(data);
  }
  
  /// Create from a UTF-8 encoded string
  factory ByteString.fromUtf8(String str) {
    return ByteString._(Uint8List.fromList(utf8.encode(str)));
  }
  
  int get length => _data.length;
  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;
  
  /// Raw byte data
  Uint8List get data => _data;
  
  /// Get byte at index
  int operator [](int index) => _data[index];
  
  /// Get first byte
  int get first => _data.first;
  
  /// Get last byte
  int get last => _data.last;
  
  /// Convert to Latin-1 string
  String toLatin1String() => latin1.decode(_data);
  
  /// Try to convert to UTF-8 string
  String toUtf8String() {
    try {
      return utf8.decode(_data);
    } catch (_) {
      return latin1.decode(_data);
    }
  }
  
  /// Get substring
  ByteString substring(int start, [int? end]) {
    return ByteString._(_data.sublist(start, end));
  }
  
  /// Check if starts with prefix
  bool startsWith(ByteString prefix) {
    if (prefix.length > length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (_data[i] != prefix._data[i]) return false;
    }
    return true;
  }
  
  /// Check if ends with suffix
  bool endsWith(ByteString suffix) {
    if (suffix.length > length) return false;
    final offset = length - suffix.length;
    for (var i = 0; i < suffix.length; i++) {
      if (_data[offset + i] != suffix._data[i]) return false;
    }
    return true;
  }
  
  /// Find first occurrence of byte
  int indexOf(int byte, [int start = 0]) {
    for (var i = start; i < length; i++) {
      if (_data[i] == byte) return i;
    }
    return -1;
  }
  
  /// Find last occurrence of byte
  int lastIndexOf(int byte, [int? end]) {
    final endIndex = end ?? length;
    for (var i = endIndex - 1; i >= 0; i--) {
      if (_data[i] == byte) return i;
    }
    return -1;
  }
  
  /// Check if contains byte
  bool contains(int byte) => indexOf(byte) >= 0;
  
  /// Trim whitespace from start and end
  ByteString trim() {
    var start = 0;
    var end = length;
    
    while (start < end && _isWhitespace(_data[start])) {
      start++;
    }
    while (end > start && _isWhitespace(_data[end - 1])) {
      end--;
    }
    
    if (start == 0 && end == length) return this;
    return substring(start, end);
  }
  
  /// Concatenate two byte strings
  ByteString operator +(ByteString other) {
    final result = Uint8List(length + other.length);
    result.setRange(0, length, _data);
    result.setRange(length, result.length, other._data);
    return ByteString._(result);
  }
  
  /// Compare to another byte string
  @override
  int compareTo(ByteString other) {
    final minLen = length < other.length ? length : other.length;
    for (var i = 0; i < minLen; i++) {
      final diff = _data[i] - other._data[i];
      if (diff != 0) return diff;
    }
    return length - other.length;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ByteString) return false;
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      if (_data[i] != other._data[i]) return false;
    }
    return true;
  }
  
  @override
  int get hashCode {
    var hash = 0;
    for (var i = 0; i < length; i++) {
      hash = (hash * 31 + _data[i]) & 0x7FFFFFFF;
    }
    return hash;
  }
  
  @override
  String toString() => toLatin1String();
  
  static bool _isWhitespace(int byte) {
    return byte == 0x20 || // space
           byte == 0x09 || // tab
           byte == 0x0A || // newline
           byte == 0x0D || // carriage return
           byte == 0x0C;   // form feed
  }
}

/// Wide string - sequence of 16-bit UTF-16 characters
/// 
/// Equivalent to WideString in PDFium (core/fxcrt/widestring.h)
/// Used for text content and Unicode strings.
class WideString implements Comparable<WideString> {
  final String _data;
  
  WideString._(this._data);
  
  /// Create an empty wide string
  factory WideString.empty() => WideString._('');
  
  /// Create from a Dart string
  factory WideString.fromString(String str) => WideString._(str);
  
  /// Create from UTF-16 code units
  factory WideString.fromCodeUnits(List<int> codeUnits) {
    return WideString._(String.fromCharCodes(codeUnits));
  }
  
  /// Create from a byte string (Latin-1 to Unicode)
  factory WideString.fromByteString(ByteString bs) {
    return WideString._(bs.toLatin1String());
  }
  
  /// Create from UTF-8 bytes
  factory WideString.fromUtf8(List<int> bytes) {
    return WideString._(utf8.decode(bytes));
  }
  
  /// Create from UTF-16LE bytes (PDF standard)
  factory WideString.fromUtf16LE(List<int> bytes) {
    if (bytes.length < 2) return WideString.empty();
    
    final codeUnits = <int>[];
    for (var i = 0; i < bytes.length - 1; i += 2) {
      codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return WideString._(String.fromCharCodes(codeUnits));
  }
  
  /// Create from UTF-16BE bytes
  factory WideString.fromUtf16BE(List<int> bytes) {
    if (bytes.length < 2) return WideString.empty();
    
    final codeUnits = <int>[];
    for (var i = 0; i < bytes.length - 1; i += 2) {
      codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return WideString._(String.fromCharCodes(codeUnits));
  }
  
  int get length => _data.length;
  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;
  
  /// Underlying string
  String get data => _data;
  
  /// Get character code at index
  int operator [](int index) => _data.codeUnitAt(index);
  
  /// Convert to Dart string
  @override
  String toString() => _data;
  
  /// Convert to ByteString (Latin-1 encoding, lossy)
  ByteString toByteString() {
    return ByteString.fromString(_data);
  }
  
  /// Convert to UTF-8 bytes
  Uint8List toUtf8() {
    return Uint8List.fromList(utf8.encode(_data));
  }
  
  /// Convert to UTF-16LE bytes (PDF standard)
  Uint8List toUtf16LE() {
    final bytes = <int>[];
    for (var i = 0; i < _data.length; i++) {
      final code = _data.codeUnitAt(i);
      bytes.add(code & 0xFF);
      bytes.add((code >> 8) & 0xFF);
    }
    return Uint8List.fromList(bytes);
  }
  
  /// Get substring
  WideString substring(int start, [int? end]) {
    return WideString._(_data.substring(start, end));
  }
  
  /// Check if starts with prefix
  bool startsWith(WideString prefix) => _data.startsWith(prefix._data);
  
  /// Check if ends with suffix
  bool endsWith(WideString suffix) => _data.endsWith(suffix._data);
  
  /// Find first occurrence
  int indexOf(String pattern, [int start = 0]) => _data.indexOf(pattern, start);
  
  /// Find last occurrence
  int lastIndexOf(String pattern, [int? start]) => 
      _data.lastIndexOf(pattern, start);
  
  /// Check if contains pattern
  bool contains(String pattern) => _data.contains(pattern);
  
  /// Trim whitespace
  WideString trim() => WideString._(_data.trim());
  
  /// Convert to lowercase
  WideString toLowerCase() => WideString._(_data.toLowerCase());
  
  /// Convert to uppercase
  WideString toUpperCase() => WideString._(_data.toUpperCase());
  
  /// Concatenate two wide strings
  WideString operator +(WideString other) {
    return WideString._(_data + other._data);
  }
  
  @override
  int compareTo(WideString other) => _data.compareTo(other._data);
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is WideString) return _data == other._data;
    if (other is String) return _data == other;
    return false;
  }
  
  @override
  int get hashCode => _data.hashCode;
}

/// PDF string type detection
enum PdfStringType {
  /// Literal string in parentheses: (Hello World)
  literal,
  /// Hexadecimal string in angle brackets: <48656C6C6F>
  hexadecimal,
}

/// Utilities for PDF string encoding/decoding
class PdfStringCodec {
  PdfStringCodec._();
  
  /// Check if bytes have a UTF-16BE BOM
  static bool hasUtf16BeBom(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF;
  }
  
  /// Check if bytes have a UTF-16LE BOM
  static bool hasUtf16LeBom(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE;
  }
  
  /// Check if bytes have a UTF-8 BOM
  static bool hasUtf8Bom(List<int> bytes) {
    return bytes.length >= 3 && 
           bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
  }
  
  /// Decode PDF string bytes to WideString
  static WideString decode(List<int> bytes) {
    if (bytes.isEmpty) return WideString.empty();
    
    // Check for UTF-16BE BOM
    if (hasUtf16BeBom(bytes)) {
      return WideString.fromUtf16BE(bytes.sublist(2));
    }
    
    // Check for UTF-16LE BOM  
    if (hasUtf16LeBom(bytes)) {
      return WideString.fromUtf16LE(bytes.sublist(2));
    }
    
    // Check for UTF-8 BOM
    if (hasUtf8Bom(bytes)) {
      return WideString.fromUtf8(bytes.sublist(3));
    }
    
    // Default to PDFDocEncoding (similar to Latin-1)
    return WideString.fromByteString(ByteString.fromBytes(bytes));
  }
  
  /// Encode WideString to PDF bytes (UTF-16BE with BOM)
  static Uint8List encodeUtf16(WideString str) {
    final result = <int>[0xFE, 0xFF]; // UTF-16BE BOM
    for (var i = 0; i < str.length; i++) {
      final code = str[i];
      result.add((code >> 8) & 0xFF);
      result.add(code & 0xFF);
    }
    return Uint8List.fromList(result);
  }
  
  /// Decode hexadecimal string
  static Uint8List decodeHex(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'\s'), '');
    final bytes = <int>[];
    
    for (var i = 0; i < cleaned.length; i += 2) {
      final end = i + 2 > cleaned.length ? cleaned.length : i + 2;
      var hexByte = cleaned.substring(i, end);
      if (hexByte.length == 1) hexByte += '0'; // Pad with 0
      bytes.add(int.parse(hexByte, radix: 16));
    }
    
    return Uint8List.fromList(bytes);
  }
  
  /// Encode bytes to hexadecimal string
  static String encodeHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
