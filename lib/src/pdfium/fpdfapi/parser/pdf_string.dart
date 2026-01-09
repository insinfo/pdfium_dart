/// PDF String object
/// 
/// Port of core/fpdfapi/parser/cpdf_string.h

import 'dart:typed_data';

import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_object.dart';

/// PDF String object (literal or hexadecimal)
/// 
/// Equivalent to CPDF_String in PDFium
class PdfString extends PdfObject {
  ByteString _data;
  bool _isHex;
  
  /// Create a literal string
  PdfString(String value) 
      : _data = ByteString.fromString(value),
        _isHex = false;
  
  /// Create from bytes
  PdfString.fromBytes(List<int> bytes, {bool isHex = false})
      : _data = ByteString.fromBytes(bytes),
        _isHex = isHex;
  
  /// Create from ByteString
  PdfString.fromByteString(this._data, {bool isHex = false})
      : _isHex = isHex;
  
  /// Create a hexadecimal string
  factory PdfString.hex(String hexString) {
    final bytes = PdfStringCodec.decodeHex(hexString);
    return PdfString.fromBytes(bytes, isHex: true);
  }
  
  @override
  PdfObjectType get type => PdfObjectType.string;
  
  /// Check if this is a hexadecimal string
  bool get isHex => _isHex;
  
  /// Get raw bytes
  Uint8List get bytes => _data.data;
  
  /// Alias for bytes - get raw bytes
  Uint8List get rawBytes => bytes;
  
  @override
  ByteString get stringValue => _data;
  
  @override
  WideString get unicodeText => PdfStringCodec.decode(_data.data.toList());
  
  /// Get as decoded text (handles PDF string encoding)
  String get text => unicodeText.toString();
  
  /// Set value from string
  void setValue(String value) {
    _data = ByteString.fromString(value);
  }
  
  /// Set value from bytes
  void setBytes(List<int> bytes) {
    _data = ByteString.fromBytes(bytes);
  }
  
  @override
  PdfString clone() => PdfString.fromByteString(
    ByteString.fromBytes(_data.data.toList()),
    isHex: _isHex,
  );
  
  @override
  void writeTo(StringBuffer buffer) {
    if (_isHex) {
      buffer.write('<');
      buffer.write(PdfStringCodec.encodeHex(_data.data.toList()));
      buffer.write('>');
    } else {
      buffer.write('(');
      _writeLiteralString(buffer);
      buffer.write(')');
    }
  }
  
  void _writeLiteralString(StringBuffer buffer) {
    for (var i = 0; i < _data.length; i++) {
      final byte = _data[i];
      switch (byte) {
        case 0x0A: // \n
          buffer.write(r'\n');
          break;
        case 0x0D: // \r
          buffer.write(r'\r');
          break;
        case 0x09: // \t
          buffer.write(r'\t');
          break;
        case 0x08: // \b
          buffer.write(r'\b');
          break;
        case 0x0C: // \f
          buffer.write(r'\f');
          break;
        case 0x28: // (
          buffer.write(r'\(');
          break;
        case 0x29: // )
          buffer.write(r'\)');
          break;
        case 0x5C: // \
          buffer.write(r'\\');
          break;
        default:
          if (byte < 32 || byte > 126) {
            // Octal escape for non-printable
            buffer.write('\\');
            buffer.write(byte.toRadixString(8).padLeft(3, '0'));
          } else {
            buffer.writeCharCode(byte);
          }
      }
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is PdfString) return _data == other._data;
    if (other is String) return text == other;
    return false;
  }
  
  @override
  int get hashCode => _data.hashCode;
  
  @override
  String toString() => 'PdfString(${_isHex ? "hex" : "literal"}: "$text")';
}

/// Date string parsing/formatting for PDF
class PdfDate {
  final DateTime dateTime;
  
  PdfDate(this.dateTime);
  
  /// Parse PDF date string format: D:YYYYMMDDHHmmSSOHH'mm'
  factory PdfDate.parse(String str) {
    var s = str;
    
    // Remove D: prefix if present
    if (s.startsWith('D:')) {
      s = s.substring(2);
    }
    
    try {
      // Parse components
      final year = s.length >= 4 ? int.parse(s.substring(0, 4)) : 2000;
      final month = s.length >= 6 ? int.parse(s.substring(4, 6)) : 1;
      final day = s.length >= 8 ? int.parse(s.substring(6, 8)) : 1;
      final hour = s.length >= 10 ? int.parse(s.substring(8, 10)) : 0;
      final minute = s.length >= 12 ? int.parse(s.substring(10, 12)) : 0;
      final second = s.length >= 14 ? int.parse(s.substring(12, 14)) : 0;
      
      // Parse timezone if present
      var tzOffset = Duration.zero;
      if (s.length > 14) {
        final tzPart = s.substring(14);
        if (tzPart.startsWith('+') || tzPart.startsWith('-')) {
          final sign = tzPart.startsWith('+') ? 1 : -1;
          final tzHours = int.tryParse(tzPart.substring(1, 3)) ?? 0;
          final tzMinutes = tzPart.length >= 6 
              ? int.tryParse(tzPart.substring(4, 6).replaceAll("'", '')) ?? 0
              : 0;
          tzOffset = Duration(hours: sign * tzHours, minutes: sign * tzMinutes);
        }
      }
      
      final utcTime = DateTime.utc(year, month, day, hour, minute, second);
      return PdfDate(utcTime.subtract(tzOffset));
    } catch (_) {
      return PdfDate(DateTime.now());
    }
  }
  
  /// Format as PDF date string
  String format() {
    final d = dateTime.toUtc();
    return 'D:${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}'
        '${d.second.toString().padLeft(2, '0')}Z';
  }
  
  @override
  String toString() => format();
}
