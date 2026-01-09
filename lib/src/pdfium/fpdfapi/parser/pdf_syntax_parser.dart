/// PDF Syntax Parser
/// 
/// Port of core/fpdfapi/parser/cpdf_syntax_parser.h

import 'dart:typed_data';

import '../../fxcrt/binary_buffer.dart';
import '../../fxcrt/fx_stream.dart';
import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_array.dart';
import 'pdf_boolean.dart';
import 'pdf_dictionary.dart';
import 'pdf_name.dart';
import 'pdf_null.dart';
import 'pdf_number.dart';
import 'pdf_object.dart';
import 'pdf_reference.dart';
import 'pdf_stream.dart';
import 'pdf_string.dart';

/// PDF Syntax Parser - lexer and low-level parser
/// 
/// Equivalent to CPDF_SyntaxParser in PDFium
class PdfSyntaxParser {
  final SeekableReadStream _stream;
  final BufferedReader _reader;
  IndirectObjectHolder? holder;
  
  /// Maximum recursion depth for parsing nested objects
  static const int maxRecursionDepth = 512;
  
  /// Current position in the stream
  int get position => _reader.position;
  set position(int value) => _reader.position = value;
  
  /// Total size of the stream
  int get size => _reader.size;
  
  /// Access to underlying stream (for advanced use)
  SeekableReadStream get stream => _stream;
  
  /// Access to buffered reader (for advanced use)
  BufferedReader get reader => _reader;
  
  /// Create a parser for the given stream
  PdfSyntaxParser(this._stream) : _reader = BufferedReader(_stream);
  
  /// Create a parser from bytes
  factory PdfSyntaxParser.fromBytes(Uint8List data) {
    return PdfSyntaxParser(MemoryReadStream(data));
  }
  
  /// Skip whitespace and comments
  void skipWhitespaceAndComments() {
    while (!_reader.isEof) {
      final byte = _reader.peekByte();
      
      if (_isWhitespace(byte)) {
        _reader.readByte();
        continue;
      }
      
      if (byte == 0x25) { // '%' comment
        _skipComment();
        continue;
      }
      
      break;
    }
  }
  
  void _skipComment() {
    while (!_reader.isEof) {
      final byte = _reader.readByte();
      if (byte == 0x0A || byte == 0x0D) break; // LF or CR
    }
  }
  
  /// Read a keyword (sequence of non-delimiter characters)
  String readKeyword() {
    skipWhitespaceAndComments();
    
    final buffer = StringBuffer();
    while (!_reader.isEof) {
      final byte = _reader.peekByte();
      if (_isWhitespace(byte) || _isDelimiter(byte)) break;
      buffer.writeCharCode(_reader.readByte());
    }
    
    return buffer.toString();
  }
  
  /// Read a number
  PdfNumber? readNumber() {
    skipWhitespaceAndComments();
    
    final buffer = StringBuffer();
    var hasDecimal = false;
    var hasSign = false;
    
    while (!_reader.isEof) {
      final byte = _reader.peekByte();
      
      if (byte == 0x2B || byte == 0x2D) { // + or -
        if (buffer.isNotEmpty) break;
        hasSign = true;
        buffer.writeCharCode(_reader.readByte());
      } else if (byte == 0x2E) { // .
        if (hasDecimal) break;
        hasDecimal = true;
        buffer.writeCharCode(_reader.readByte());
      } else if (byte >= 0x30 && byte <= 0x39) { // 0-9
        buffer.writeCharCode(_reader.readByte());
      } else {
        break;
      }
    }
    
    if (buffer.isEmpty) return null;
    
    final str = buffer.toString();
    if (hasDecimal) {
      final value = double.tryParse(str);
      if (value != null) return PdfNumber.real(value);
    } else {
      final value = int.tryParse(str);
      if (value != null) return PdfNumber.integer(value);
    }
    
    return null;
  }
  
  /// Read a name object
  PdfName? readName() {
    skipWhitespaceAndComments();
    
    if (_reader.peekByte() != 0x2F) return null; // Must start with /
    _reader.readByte(); // Consume /
    
    final buffer = StringBuffer();
    while (!_reader.isEof) {
      final byte = _reader.peekByte();
      if (_isWhitespace(byte) || _isDelimiter(byte)) break;
      
      if (byte == 0x23) { // # escape sequence
        _reader.readByte();
        final hex1 = _reader.readByte();
        final hex2 = _reader.readByte();
        if (hex1 >= 0 && hex2 >= 0) {
          final hexStr = String.fromCharCodes([hex1, hex2]);
          final code = int.tryParse(hexStr, radix: 16);
          if (code != null) {
            buffer.writeCharCode(code);
            continue;
          }
        }
      }
      
      buffer.writeCharCode(_reader.readByte());
    }
    
    return PdfName(buffer.toString());
  }
  
  /// Read a literal string (...)
  PdfString? readLiteralString() {
    skipWhitespaceAndComments();
    
    if (_reader.peekByte() != 0x28) return null; // Must start with (
    _reader.readByte(); // Consume (
    
    final bytes = <int>[];
    var depth = 1;
    
    while (!_reader.isEof && depth > 0) {
      var byte = _reader.readByte();
      
      if (byte == 0x28) { // (
        depth++;
        bytes.add(byte);
      } else if (byte == 0x29) { // )
        depth--;
        if (depth > 0) bytes.add(byte);
      } else if (byte == 0x5C) { // \ escape
        byte = _reader.readByte();
        switch (byte) {
          case 0x6E: // n
            bytes.add(0x0A);
            break;
          case 0x72: // r
            bytes.add(0x0D);
            break;
          case 0x74: // t
            bytes.add(0x09);
            break;
          case 0x62: // b
            bytes.add(0x08);
            break;
          case 0x66: // f
            bytes.add(0x0C);
            break;
          case 0x28: // (
          case 0x29: // )
          case 0x5C: // \
            bytes.add(byte);
            break;
          case 0x0A: // Line continuation (LF)
            break;
          case 0x0D: // Line continuation (CR)
            if (_reader.peekByte() == 0x0A) _reader.readByte();
            break;
          default:
            // Octal escape
            if (byte >= 0x30 && byte <= 0x37) {
              var octal = byte - 0x30;
              for (var i = 0; i < 2; i++) {
                final next = _reader.peekByte();
                if (next >= 0x30 && next <= 0x37) {
                  octal = (octal << 3) | (_reader.readByte() - 0x30);
                } else {
                  break;
                }
              }
              bytes.add(octal & 0xFF);
            } else {
              bytes.add(byte);
            }
        }
      } else {
        bytes.add(byte);
      }
    }
    
    return PdfString.fromBytes(bytes);
  }
  
  /// Read a hexadecimal string <...>
  PdfString? readHexString() {
    skipWhitespaceAndComments();
    
    if (_reader.peekByte() != 0x3C) return null; // Must start with <
    _reader.readByte(); // Consume <
    
    final hexChars = StringBuffer();
    while (!_reader.isEof) {
      final byte = _reader.readByte();
      if (byte == 0x3E) break; // > end
      if (_isWhitespace(byte)) continue;
      hexChars.writeCharCode(byte);
    }
    
    return PdfString.hex(hexChars.toString());
  }
  
  /// Read an array [...]
  PdfArray? readArray([int depth = 0]) {
    if (depth > maxRecursionDepth) return null;
    
    skipWhitespaceAndComments();
    
    if (_reader.peekByte() != 0x5B) return null; // Must start with [
    _reader.readByte(); // Consume [
    
    final array = PdfArray();
    array.holder = holder;
    
    while (!_reader.isEof) {
      skipWhitespaceAndComments();
      
      final byte = _reader.peekByte();
      if (byte == 0x5D) { // ] end
        _reader.readByte();
        break;
      }
      
      final obj = readObject(depth + 1);
      if (obj != null) {
        array.add(obj);
      } else {
        // Skip invalid content
        _reader.readByte();
      }
    }
    
    return array;
  }
  
  /// Read a dictionary <<...>>
  PdfDictionary? readDictionary([int depth = 0]) {
    if (depth > maxRecursionDepth) return null;
    
    skipWhitespaceAndComments();
    
    // Check for <<
    if (_reader.peekByte() != 0x3C) return null;
    _reader.readByte();
    if (_reader.peekByte() != 0x3C) {
      // It's a hex string, not a dictionary
      _reader.position--;
      return null;
    }
    _reader.readByte(); // Consume second <
    
    final dict = PdfDictionary();
    dict.holder = holder;
    
    while (!_reader.isEof) {
      skipWhitespaceAndComments();
      
      // Check for >>
      if (_reader.peekByte() == 0x3E) {
        _reader.readByte();
        if (_reader.peekByte() == 0x3E) {
          _reader.readByte();
          break;
        }
      }
      
      // Read key (must be a name)
      final name = readName();
      if (name == null) {
        _reader.readByte();
        continue;
      }
      
      // Read value
      final value = readObject(depth + 1);
      if (value != null) {
        dict[name.name] = value;
      }
    }
    
    return dict;
  }
  
  /// Read a stream (dictionary followed by stream data)
  PdfStream? readStream(PdfDictionary dict) {
    skipWhitespaceAndComments();
    
    // Expect 'stream' keyword
    final keyword = readKeyword();
    if (keyword != 'stream') return null;
    
    // Skip EOL after 'stream'
    var byte = _reader.readByte();
    if (byte == 0x0D && _reader.peekByte() == 0x0A) {
      _reader.readByte();
    }
    
    // Get stream length
    final lengthObj = dict.get('Length');
    var streamLength = lengthObj?.intValue ?? 0;
    
    if (streamLength <= 0) {
      // Try to find endstream
      streamLength = _findEndStream();
    }
    
    // Read stream data
    final data = _reader.readBytes(streamLength);
    if (data == null) return null;
    
    // Skip to endstream
    skipWhitespaceAndComments();
    readKeyword(); // Should be 'endstream'
    
    return PdfStream(dict, data);
  }
  
  int _findEndStream() {
    final startPos = _reader.position;
    final searchPattern = [0x65, 0x6E, 0x64, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6D]; // "endstream"
    
    while (!_reader.isEof) {
      final byte = _reader.readByte();
      if (byte == searchPattern[0]) {
        var match = true;
        for (var i = 1; i < searchPattern.length; i++) {
          if (_reader.readByte() != searchPattern[i]) {
            match = false;
            break;
          }
        }
        if (match) {
          final endPos = _reader.position - searchPattern.length;
          // Skip trailing whitespace from stream data
          var length = endPos - startPos;
          _reader.position = startPos;
          while (length > 0) {
            _reader.position = startPos + length - 1;
            final lastByte = _reader.readByte();
            if (lastByte != 0x0A && lastByte != 0x0D && lastByte != 0x20) {
              break;
            }
            length--;
          }
          _reader.position = startPos;
          return length;
        }
      }
    }
    
    _reader.position = startPos;
    return 0;
  }
  
  /// Read any PDF object
  PdfObject? readObject([int depth = 0]) {
    if (depth > maxRecursionDepth) return null;
    
    skipWhitespaceAndComments();
    if (_reader.isEof) return null;
    
    final byte = _reader.peekByte();
    
    // Name
    if (byte == 0x2F) { // /
      return readName();
    }
    
    // Literal string
    if (byte == 0x28) { // (
      return readLiteralString();
    }
    
    // Hex string or dictionary
    if (byte == 0x3C) { // <
      final savedPos = _reader.position;
      _reader.readByte();
      final nextByte = _reader.peekByte();
      _reader.position = savedPos;
      
      if (nextByte == 0x3C) {
        return readDictionary(depth);
      } else {
        return readHexString();
      }
    }
    
    // Array
    if (byte == 0x5B) { // [
      return readArray(depth);
    }
    
    // Number or reference (n n R) or keyword
    if (_isDigit(byte) || byte == 0x2B || byte == 0x2D || byte == 0x2E) {
      return _readNumberOrReference();
    }
    
    // Keyword (true, false, null, etc.)
    final keyword = readKeyword();
    switch (keyword) {
      case 'true':
        return PdfBoolean(true);
      case 'false':
        return PdfBoolean(false);
      case 'null':
        return PdfNull();
      default:
        return null;
    }
  }
  
  PdfObject? _readNumberOrReference() {
    final startPos = _reader.position;
    
    // Try to read first number
    final num1 = readNumber();
    if (num1 == null) return null;
    
    // Check if it could be a reference (objNum genNum R)
    if (num1.isInteger && num1.intValue >= 0) {
      skipWhitespaceAndComments();
      final posAfterNum1 = _reader.position;
      
      final num2 = readNumber();
      if (num2 != null && num2.isInteger && num2.intValue >= 0) {
        skipWhitespaceAndComments();
        
        if (_reader.peekByte() == 0x52) { // 'R'
          _reader.readByte();
          return PdfReference(num1.intValue, num2.intValue, holder);
        }
      }
      
      // Not a reference, restore position
      _reader.position = posAfterNum1;
    }
    
    return num1;
  }
  
  /// Read an indirect object (n n obj ... endobj)
  (int objNum, int genNum, PdfObject? obj)? readIndirectObject() {
    skipWhitespaceAndComments();
    
    final objNum = readNumber();
    if (objNum == null || !objNum.isInteger) return null;
    
    final genNum = readNumber();
    if (genNum == null || !genNum.isInteger) return null;
    
    final keyword = readKeyword();
    if (keyword != 'obj') return null;
    
    // Read the object
    var obj = readObject();
    
    // Check for stream
    if (obj is PdfDictionary) {
      skipWhitespaceAndComments();
      final savedPos = _reader.position;
      final nextKeyword = readKeyword();
      
      if (nextKeyword == 'stream') {
        _reader.position = savedPos;
        final stream = readStream(obj);
        if (stream != null) {
          obj = stream;
        }
      } else {
        _reader.position = savedPos;
      }
    }
    
    // Skip to endobj
    skipWhitespaceAndComments();
    readKeyword(); // Should be 'endobj'
    
    return (objNum.intValue, genNum.intValue, obj);
  }
  
  /// Find a keyword searching backwards from a position
  int? findKeywordBackward(String keyword, int startPos) {
    final keywordBytes = keyword.codeUnits;
    var pos = startPos;
    
    while (pos >= keywordBytes.length) {
      _reader.position = pos - keywordBytes.length;
      final data = _reader.readBytes(keywordBytes.length);
      if (data == null) break;
      
      var match = true;
      for (var i = 0; i < keywordBytes.length; i++) {
        if (data[i] != keywordBytes[i]) {
          match = false;
          break;
        }
      }
      
      if (match) {
        return pos - keywordBytes.length;
      }
      
      pos--;
    }
    
    return null;
  }
  
  static bool _isWhitespace(int byte) {
    return byte == 0x00 || // null
           byte == 0x09 || // tab
           byte == 0x0A || // LF
           byte == 0x0C || // FF
           byte == 0x0D || // CR
           byte == 0x20;   // space
  }
  
  static bool _isDelimiter(int byte) {
    return byte == 0x28 || // (
           byte == 0x29 || // )
           byte == 0x3C || // <
           byte == 0x3E || // >
           byte == 0x5B || // [
           byte == 0x5D || // ]
           byte == 0x7B || // {
           byte == 0x7D || // }
           byte == 0x2F || // /
           byte == 0x25;   // %
  }
  
  static bool _isDigit(int byte) {
    return byte >= 0x30 && byte <= 0x39;
  }
}
