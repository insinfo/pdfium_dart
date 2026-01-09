

import 'dart:typed_data';

import '../parser/pdf_object.dart';
import '../parser/pdf_array.dart';
import '../parser/pdf_dictionary.dart';
import '../parser/pdf_name.dart';
import '../parser/pdf_number.dart';
import '../parser/pdf_string.dart';
import '../parser/pdf_stream.dart';
import '../../fxcrt/fx_types.dart';

/// Operador de content stream
enum ContentOperator {
  // Graphics State Operators
  gsave('q'),           // Save graphics state
  grestore('Q'),        // Restore graphics state
  ctm('cm'),           // Concatenate matrix to CTM
  lineWidth('w'),      // Set line width
  lineCap('J'),        // Set line cap style
  lineJoin('j'),       // Set line join style
  miterLimit('M'),     // Set miter limit
  dashPattern('d'),    // Set dash pattern
  intent('ri'),        // Set color rendering intent
  flatness('i'),       // Set flatness tolerance
  dictGState('gs'),    // Set graphics state from dictionary
  
  // Path Construction Operators
  moveTo('m'),         // Begin new subpath
  lineTo('l'),         // Append line segment
  curveTo('c'),        // Append Bezier curve (3 control points)
  curveToV('v'),       // Append Bezier curve (replicate initial point)
  curveToY('y'),       // Append Bezier curve (replicate final point)
  closePath('h'),      // Close current subpath
  rect('re'),          // Append rectangle
  
  // Path Painting Operators
  stroke('S'),         // Stroke the path
  closeStroke('s'),    // Close and stroke the path
  fill('f'),           // Fill the path (nonzero winding)
  fillOld('F'),        // Fill (obsolete)
  fillEvenOdd('f*'),   // Fill the path (even-odd rule)
  fillStroke('B'),     // Fill and stroke (nonzero)
  fillStrokeEvenOdd('B*'), // Fill and stroke (even-odd)
  closeFillStroke('b'), // Close, fill, and stroke (nonzero)
  closeFillStrokeEvenOdd('b*'), // Close, fill, stroke (even-odd)
  endPath('n'),        // End path without filling/stroking
  
  // Clipping Operators
  clip('W'),           // Clip (nonzero winding)
  clipEvenOdd('W*'),   // Clip (even-odd rule)
  
  // Text Object Operators
  beginText('BT'),     // Begin text object
  endText('ET'),       // End text object
  
  // Text State Operators
  charSpace('Tc'),     // Set character spacing
  wordSpace('Tw'),     // Set word spacing
  hScale('Tz'),        // Set horizontal scaling
  textLeading('TL'),   // Set text leading
  font('Tf'),          // Set font and size
  textRender('Tr'),    // Set text rendering mode
  textRise('Ts'),      // Set text rise
  
  // Text Positioning Operators
  textMove('Td'),      // Move text position
  textMoveSet('TD'),   // Move and set leading
  textMatrix('Tm'),    // Set text matrix
  textNewLine('T*'),   // Move to start of next line
  
  // Text Showing Operators
  showText('Tj'),      // Show text string
  showTextNewLine("'"),// Move to next line and show text
  showTextSpacing('"'),// Set spacing, move, and show text
  showTextArray('TJ'), // Show text with positioning
  
  // Color Operators
  strokeColorSpace('CS'), // Set stroke color space
  fillColorSpace('cs'),   // Set fill color space
  strokeColor('SC'),      // Set stroke color
  strokeColorN('SCN'),    // Set stroke color (extended)
  fillColor('sc'),        // Set fill color
  fillColorN('scn'),      // Set fill color (extended)
  strokeGray('G'),        // Set stroke gray
  fillGray('g'),          // Set fill gray
  strokeRGB('RG'),        // Set stroke RGB
  fillRGB('rg'),          // Set fill RGB
  strokeCMYK('K'),        // Set stroke CMYK
  fillCMYK('k'),          // Set fill CMYK
  
  // XObject Operators
  xobject('Do'),       // Paint XObject
  
  // Inline Image Operators
  beginImage('BI'),    // Begin inline image
  imageData('ID'),     // Begin inline image data
  endImage('EI'),      // End inline image
  
  // Shading Operators
  shading('sh'),       // Paint shading
  
  // Marked Content Operators
  markedPoint('MP'),   // Marked content point
  markedPointProps('DP'), // Marked point with property list
  beginMarked('BMC'),  // Begin marked content
  beginMarkedProps('BDC'), // Begin marked content with props
  endMarked('EMC'),    // End marked content
  
  // Compatibility Operators
  beginCompat('BX'),   // Begin compatibility section
  endCompat('EX'),     // End compatibility section
  
  // Unknown
  unknown('');

  final String name;
  const ContentOperator(this.name);
  
  static ContentOperator fromName(String name) {
    for (final op in ContentOperator.values) {
      if (op.name == name) return op;
    }
    return ContentOperator.unknown;
  }
}

/// Representa uma operação no content stream
class ContentOperation {
  final ContentOperator operator;
  final List<PdfObject> operands;
  
  ContentOperation(this.operator, this.operands);
  
  // Helpers para obter operandos tipados
  double getNumber(int index, [double defaultValue = 0.0]) {
    if (index >= operands.length) return defaultValue;
    final obj = operands[index];
    if (obj is PdfNumber) return obj.numberValue;
    return defaultValue;
  }
  
  int getInt(int index, [int defaultValue = 0]) {
    if (index >= operands.length) return defaultValue;
    final obj = operands[index];
    if (obj is PdfNumber) return obj.intValue;
    return defaultValue;
  }
  
  String? getName(int index) {
    if (index >= operands.length) return null;
    final obj = operands[index];
    if (obj is PdfName) return obj.name;
    return null;
  }
  
  String? getString(int index) {
    if (index >= operands.length) return null;
    final obj = operands[index];
    if (obj is PdfString) return obj.text;
    return null;
  }
  
  PdfArray? getArray(int index) {
    if (index >= operands.length) return null;
    final obj = operands[index];
    if (obj is PdfArray) return obj;
    return null;
  }
  
  Uint8List? getStringBytes(int index) {
    if (index >= operands.length) return null;
    final obj = operands[index];
    if (obj is PdfString) return obj.rawBytes;
    return null;
  }
  
  @override
  String toString() {
    final opStr = operands.map((o) {
      if (o is PdfNumber) return o.numberValue.toString();
      if (o is PdfName) return '/${o.name}';
      if (o is PdfString) return '(${o.text})';
      return o.toString();
    }).join(' ');
    return '$opStr ${operator.name}'.trim();
  }
}

/// Parser de content stream - tokeniza e parseia operadores PDF
class ContentStreamParser {
  final Uint8List _data;
  int _position = 0;
  final PdfDictionary? _resources;
  
  ContentStreamParser(this._data, [this._resources]);
  
  /// Cria parser de uma lista de streams concatenados
  factory ContentStreamParser.fromStreams(
    List<PdfStream> streams, [
    PdfDictionary? resources,
  ]) {
    // Concatenar dados dos streams
    int totalLength = 0;
    for (final stream in streams) {
      final data = stream.decodedData;
      if (data != null) totalLength += data.length + 1; // +1 for space
    }
    
    final combined = Uint8List(totalLength);
    int offset = 0;
    for (final stream in streams) {
      final data = stream.decodedData;
      if (data != null) {
        combined.setRange(offset, offset + data.length, data);
        offset += data.length;
        if (offset < totalLength) {
          combined[offset++] = 0x20; // space between streams
        }
      }
    }
    
    return ContentStreamParser(combined, resources);
  }
  
  bool get isAtEnd => _position >= _data.length;
  
  /// Parseia todas as operações do content stream
  List<ContentOperation> parseAll() {
    final operations = <ContentOperation>[];
    
    while (!isAtEnd) {
      final op = parseOperation();
      if (op != null) {
        operations.add(op);
      }
    }
    
    return operations;
  }
  
  /// Parseia a próxima operação
  ContentOperation? parseOperation() {
    final operands = <PdfObject>[];
    
    while (!isAtEnd) {
      _skipWhitespace();
      if (isAtEnd) break;
      
      final byte = _data[_position];
      
      // Comentário
      if (byte == 0x25) { // %
        _skipComment();
        continue;
      }
      
      // Nome
      if (byte == 0x2F) { // /
        final name = _readName();
        if (name != null) {
          operands.add(name);
        }
        continue;
      }
      
      // String literal
      if (byte == 0x28) { // (
        final str = _readLiteralString();
        if (str != null) {
          operands.add(str);
        }
        continue;
      }
      
      // String hex
      if (byte == 0x3C) { // <
        if (_position + 1 < _data.length && _data[_position + 1] == 0x3C) {
          // Dictionary - não deveria aparecer em content streams
          _skipDictionary();
        } else {
          final str = _readHexString();
          if (str != null) {
            operands.add(str);
          }
        }
        continue;
      }
      
      // Array
      if (byte == 0x5B) { // [
        final arr = _readArray();
        if (arr != null) {
          operands.add(arr);
        }
        continue;
      }
      
      // Número ou operador
      if (_isDigit(byte) || byte == 0x2D || byte == 0x2B || byte == 0x2E) {
        final num = _readNumber();
        if (num != null) {
          operands.add(num);
          continue;
        }
      }
      
      // Operador (keyword)
      if (_isAlpha(byte) || byte == 0x27 || byte == 0x22 || byte == 0x2A) {
        final keyword = _readKeyword();
        if (keyword != null) {
          final op = ContentOperator.fromName(keyword);
          
          // Tratamento especial para inline images
          if (op == ContentOperator.beginImage) {
            final imageOp = _parseInlineImage(operands);
            if (imageOp != null) {
              return imageOp;
            }
          }
          
          return ContentOperation(op, List.from(operands));
        }
      }
      
      // Caractere desconhecido - pular
      _position++;
    }
    
    return null;
  }
  
  void _skipWhitespace() {
    while (_position < _data.length) {
      final byte = _data[_position];
      if (byte == 0x00 || byte == 0x09 || byte == 0x0A || 
          byte == 0x0C || byte == 0x0D || byte == 0x20) {
        _position++;
      } else {
        break;
      }
    }
  }
  
  void _skipComment() {
    while (_position < _data.length) {
      final byte = _data[_position++];
      if (byte == 0x0A || byte == 0x0D) break;
    }
  }
  
  bool _isDigit(int byte) => byte >= 0x30 && byte <= 0x39;
  bool _isAlpha(int byte) => 
      (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A);
  
  PdfNumber? _readNumber() {
    final start = _position;
    bool hasDecimal = false;
    bool hasSign = false;
    
    if (_data[_position] == 0x2D || _data[_position] == 0x2B) {
      hasSign = true;
      _position++;
    }
    
    while (_position < _data.length) {
      final byte = _data[_position];
      if (_isDigit(byte)) {
        _position++;
      } else if (byte == 0x2E && !hasDecimal) {
        hasDecimal = true;
        _position++;
      } else {
        break;
      }
    }
    
    if (_position == start || (_position == start + 1 && hasSign)) {
      _position = start;
      return null;
    }
    
    final str = String.fromCharCodes(_data.sublist(start, _position));
    final value = double.tryParse(str);
    if (value == null) {
      _position = start;
      return null;
    }
    
    if (hasDecimal) {
      return PdfNumber.real(value);
    } else {
      return PdfNumber.integer(value.toInt());
    }
  }
  
  PdfName? _readName() {
    if (_data[_position] != 0x2F) return null; // /
    _position++;
    
    final buffer = StringBuffer();
    while (_position < _data.length) {
      final byte = _data[_position];
      
      // Delimitadores
      if (byte == 0x00 || byte == 0x09 || byte == 0x0A || 
          byte == 0x0C || byte == 0x0D || byte == 0x20 ||
          byte == 0x28 || byte == 0x29 || byte == 0x3C ||
          byte == 0x3E || byte == 0x5B || byte == 0x5D ||
          byte == 0x7B || byte == 0x7D || byte == 0x2F ||
          byte == 0x25) {
        break;
      }
      
      // Escape #XX
      if (byte == 0x23 && _position + 2 < _data.length) {
        final hex = String.fromCharCodes(_data.sublist(_position + 1, _position + 3));
        final code = int.tryParse(hex, radix: 16);
        if (code != null) {
          buffer.writeCharCode(code);
          _position += 3;
          continue;
        }
      }
      
      buffer.writeCharCode(byte);
      _position++;
    }
    
    return PdfName(buffer.toString());
  }
  
  PdfString? _readLiteralString() {
    if (_data[_position] != 0x28) return null; // (
    _position++;
    
    final buffer = <int>[];
    int parenDepth = 1;
    
    while (_position < _data.length && parenDepth > 0) {
      final byte = _data[_position++];
      
      if (byte == 0x5C) { // backslash
        if (_position < _data.length) {
          final escaped = _data[_position++];
          switch (escaped) {
            case 0x6E: buffer.add(0x0A); break; // \n
            case 0x72: buffer.add(0x0D); break; // \r
            case 0x74: buffer.add(0x09); break; // \t
            case 0x62: buffer.add(0x08); break; // \b
            case 0x66: buffer.add(0x0C); break; // \f
            case 0x28: buffer.add(0x28); break; // \(
            case 0x29: buffer.add(0x29); break; // \)
            case 0x5C: buffer.add(0x5C); break; // \\
            case 0x0A: break; // linha continuada
            case 0x0D:
              if (_position < _data.length && _data[_position] == 0x0A) {
                _position++;
              }
              break;
            default:
              // Octal
              if (escaped >= 0x30 && escaped <= 0x37) {
                int octal = escaped - 0x30;
                for (int i = 0; i < 2 && _position < _data.length; i++) {
                  final next = _data[_position];
                  if (next >= 0x30 && next <= 0x37) {
                    octal = octal * 8 + (next - 0x30);
                    _position++;
                  } else {
                    break;
                  }
                }
                buffer.add(octal & 0xFF);
              } else {
                buffer.add(escaped);
              }
          }
        }
      } else if (byte == 0x28) { // (
        parenDepth++;
        buffer.add(byte);
      } else if (byte == 0x29) { // )
        parenDepth--;
        if (parenDepth > 0) {
          buffer.add(byte);
        }
      } else {
        buffer.add(byte);
      }
    }
    
    return PdfString.fromBytes(Uint8List.fromList(buffer));
  }
  
  PdfString? _readHexString() {
    if (_data[_position] != 0x3C) return null; // <
    _position++;
    
    final buffer = <int>[];
    int? nibble;
    
    while (_position < _data.length) {
      final byte = _data[_position++];
      
      if (byte == 0x3E) { // >
        break;
      }
      
      int? hexValue;
      if (byte >= 0x30 && byte <= 0x39) {
        hexValue = byte - 0x30;
      } else if (byte >= 0x41 && byte <= 0x46) {
        hexValue = byte - 0x41 + 10;
      } else if (byte >= 0x61 && byte <= 0x66) {
        hexValue = byte - 0x61 + 10;
      }
      
      if (hexValue != null) {
        if (nibble == null) {
          nibble = hexValue;
        } else {
          buffer.add((nibble << 4) | hexValue);
          nibble = null;
        }
      }
    }
    
    // Último nibble ímpar
    if (nibble != null) {
      buffer.add(nibble << 4);
    }
    
    return PdfString.fromBytes(Uint8List.fromList(buffer), isHex: true);
  }
  
  PdfArray? _readArray() {
    if (_data[_position] != 0x5B) return null; // [
    _position++;
    
    final arr = PdfArray();
    
    while (_position < _data.length) {
      _skipWhitespace();
      if (isAtEnd) break;
      
      if (_data[_position] == 0x5D) { // ]
        _position++;
        break;
      }
      
      final obj = _readObject();
      if (obj != null) {
        arr.add(obj);
      } else {
        _position++; // Skip unknown
      }
    }
    
    return arr;
  }
  
  PdfObject? _readObject() {
    _skipWhitespace();
    if (isAtEnd) return null;
    
    final byte = _data[_position];
    
    if (byte == 0x2F) return _readName(); // /
    if (byte == 0x28) return _readLiteralString(); // (
    if (byte == 0x3C) return _readHexString(); // <
    if (byte == 0x5B) return _readArray(); // [
    
    if (_isDigit(byte) || byte == 0x2D || byte == 0x2B || byte == 0x2E) {
      return _readNumber();
    }
    
    return null;
  }
  
  String? _readKeyword() {
    final start = _position;
    
    while (_position < _data.length) {
      final byte = _data[_position];
      if (_isAlpha(byte) || byte == 0x2A || byte == 0x27 || byte == 0x22) {
        _position++;
      } else {
        break;
      }
    }
    
    if (_position == start) return null;
    return String.fromCharCodes(_data.sublist(start, _position));
  }
  
  void _skipDictionary() {
    if (_position + 1 >= _data.length) return;
    if (_data[_position] != 0x3C || _data[_position + 1] != 0x3C) return;
    _position += 2;
    
    int depth = 1;
    while (_position < _data.length && depth > 0) {
      if (_position + 1 < _data.length) {
        if (_data[_position] == 0x3C && _data[_position + 1] == 0x3C) {
          depth++;
          _position += 2;
          continue;
        }
        if (_data[_position] == 0x3E && _data[_position + 1] == 0x3E) {
          depth--;
          _position += 2;
          continue;
        }
      }
      _position++;
    }
  }
  
  /// Parseia inline image (BI ... ID data EI)
  ContentOperation? _parseInlineImage(List<PdfObject> operands) {
    final dict = PdfDictionary();
    
    // Ler pares de key/value até ID
    while (!isAtEnd) {
      _skipWhitespace();
      if (isAtEnd) break;
      
      // Verificar se chegamos em ID
      if (_position + 1 < _data.length) {
        if (_data[_position] == 0x49 && _data[_position + 1] == 0x44) { // ID
          // Verificar se é realmente o operador ID (seguido por whitespace)
          if (_position + 2 >= _data.length || _isWhitespace(_data[_position + 2])) {
            _position += 2;
            break;
          }
        }
      }
      
      final key = _readKeywordOrName();
      if (key == null) break;
      
      _skipWhitespace();
      
      final value = _readObject();
      if (value != null) {
        // Expandir abreviações
        final expandedKey = _expandInlineImageKey(key);
        dict.set(expandedKey, value);
      }
    }
    
    // Pular whitespace após ID
    if (!isAtEnd && _isWhitespace(_data[_position])) {
      _position++;
    }
    
    // Ler dados da imagem até EI
    final dataStart = _position;
    while (_position < _data.length - 1) {
      // Procurar EI precedido por whitespace
      if (_isWhitespace(_data[_position]) &&
          _data[_position + 1] == 0x45 && // E
          (_position + 2 >= _data.length || _data[_position + 2] == 0x49)) { // I
        break;
      }
      _position++;
    }
    
    final imageData = _data.sublist(dataStart, _position);
    
    // Pular até após EI
    while (_position < _data.length) {
      if (_data[_position] == 0x45) { // E
        if (_position + 1 < _data.length && _data[_position + 1] == 0x49) { // I
          _position += 2;
          break;
        }
      }
      _position++;
    }
    
    // Criar array com dict e dados
    final resultArray = PdfArray();
    resultArray.add(dict);
    resultArray.add(PdfString.fromBytes(Uint8List.fromList(imageData)));
    
    return ContentOperation(ContentOperator.beginImage, [resultArray]);
  }
  
  bool _isWhitespace(int byte) {
    return byte == 0x00 || byte == 0x09 || byte == 0x0A ||
           byte == 0x0C || byte == 0x0D || byte == 0x20;
  }
  
  String? _readKeywordOrName() {
    if (_data[_position] == 0x2F) {
      final name = _readName();
      return name?.name;
    }
    return _readKeyword();
  }
  
  String _expandInlineImageKey(String key) {
    const abbreviations = {
      'BPC': 'BitsPerComponent',
      'CS': 'ColorSpace',
      'D': 'Decode',
      'DP': 'DecodeParms',
      'F': 'Filter',
      'H': 'Height',
      'IM': 'ImageMask',
      'I': 'Interpolate',
      'W': 'Width',
    };
    return abbreviations[key] ?? key;
  }
}

/// Iterator para processar content stream de forma lazy
class ContentStreamIterator implements Iterator<ContentOperation> {
  final ContentStreamParser _parser;
  ContentOperation? _current;
  
  ContentStreamIterator(this._parser);
  
  @override
  ContentOperation get current => _current!;
  
  @override
  bool moveNext() {
    if (_parser.isAtEnd) return false;
    _current = _parser.parseOperation();
    return _current != null;
  }
}
