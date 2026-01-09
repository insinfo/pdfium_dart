/// PDF Stream object
/// 
/// Port of core/fpdfapi/parser/cpdf_stream.h

import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_array.dart';
import 'pdf_dictionary.dart';
import 'pdf_name.dart';
import 'pdf_object.dart';

/// PDF Stream object
/// 
/// Equivalent to CPDF_Stream in PDFium
/// 
/// A stream consists of a dictionary followed by the keyword 'stream',
/// followed by the stream data, followed by the keyword 'endstream'.
class PdfStream extends PdfObject {
  PdfDictionary _dict;
  Uint8List _rawData;
  Uint8List? _decodedData;
  bool _isDataDecoded;
  
  /// Create a stream with dictionary and raw data
  PdfStream(this._dict, this._rawData) : _isDataDecoded = false;
  
  /// Create an empty stream
  PdfStream.empty() 
      : _dict = PdfDictionary(),
        _rawData = Uint8List(0),
        _isDataDecoded = true;
  
  /// Create a stream with decoded data (will encode on write)
  factory PdfStream.withData(Uint8List data, {PdfDictionary? dict}) {
    final stream = PdfStream(dict ?? PdfDictionary(), data);
    stream._decodedData = data;
    stream._isDataDecoded = true;
    return stream;
  }
  
  @override
  PdfObjectType get type => PdfObjectType.stream;
  
  /// Get the stream dictionary
  PdfDictionary get dict => _dict;
  
  /// Set the stream dictionary
  set dict(PdfDictionary value) => _dict = value;
  
  /// Set the object holder
  set holder(IndirectObjectHolder? value) {
    _dict.holder = value;
  }
  
  /// Get raw (possibly encoded) data
  Uint8List get rawData => _rawData;
  
  /// Get the length of raw data
  int get rawLength => _rawData.length;
  
  /// Get decoded data
  Uint8List get data {
    if (_decodedData != null) return _decodedData!;
    
    // Decode the data
    _decodedData = _decodeData();
    return _decodedData!;
  }
  
  /// Alias for data - get decoded data
  Uint8List get decodedData => data;
  
  /// Get the length of decoded data
  int get length => data.length;
  
  /// Check if stream has a specific filter
  bool hasFilter(String filterName) {
    final filter = _dict.get('Filter');
    if (filter == null) return false;
    
    if (filter is PdfName) {
      return filter.name == filterName;
    }
    
    if (filter is PdfArray) {
      for (final f in filter) {
        if (f is PdfName && f.name == filterName) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /// Get list of filters
  List<String> get filters {
    final result = <String>[];
    final filter = _dict.get('Filter');
    if (filter == null) return result;
    
    if (filter is PdfName) {
      result.add(filter.name);
    } else if (filter is PdfArray) {
      for (final f in filter) {
        if (f is PdfName) {
          result.add(f.name);
        }
      }
    }
    
    return result;
  }
  
  /// Set raw data
  void setRawData(Uint8List data) {
    _rawData = data;
    _decodedData = null;
    _isDataDecoded = false;
  }
  
  /// Set decoded data (updates length in dictionary)
  void setData(Uint8List data) {
    _decodedData = data;
    _rawData = data; // For unfiltered stream
    _isDataDecoded = true;
    _dict.setInt('Length', data.length);
  }
  
  Uint8List _decodeData() {
    var data = _rawData;
    final filterList = filters;
    
    if (filterList.isEmpty) {
      return data;
    }
    
    // Get decode parameters
    final decodeParms = _dict.get('DecodeParms');
    List<PdfDictionary?> parmsList = [];
    
    if (decodeParms is PdfDictionary) {
      parmsList = [decodeParms];
    } else if (decodeParms is PdfArray) {
      parmsList = List.generate(
        decodeParms.length,
        (i) => decodeParms.getDictAt(i),
      );
    } else {
      parmsList = List.filled(filterList.length, null);
    }
    
    // Apply filters in order
    for (var i = 0; i < filterList.length; i++) {
      final filter = filterList[i];
      final parms = i < parmsList.length ? parmsList[i] : null;
      data = _applyFilter(data, filter, parms);
    }
    
    return data;
  }
  
  Uint8List _applyFilter(Uint8List data, String filter, PdfDictionary? parms) {
    switch (filter) {
      case 'FlateDecode':
      case 'Fl':
        return _decodeFlate(data, parms);
      case 'ASCIIHexDecode':
      case 'AHx':
        return _decodeAsciiHex(data);
      case 'ASCII85Decode':
      case 'A85':
        return _decodeAscii85(data);
      case 'LZWDecode':
      case 'LZW':
        return _decodeLzw(data, parms);
      case 'RunLengthDecode':
      case 'RL':
        return _decodeRunLength(data);
      default:
        // Unknown filter, return as-is
        return data;
    }
  }
  
  Uint8List _decodeFlate(Uint8List data, PdfDictionary? parms) {
    try {
      final inflated = Inflate(data).getBytes();
      var result = Uint8List.fromList(inflated);
      
      // Apply predictor if specified
      if (parms != null) {
        result = _applyPredictor(result, parms);
      }
      
      return result;
    } catch (_) {
      return data;
    }
  }
  
  Uint8List _applyPredictor(Uint8List data, PdfDictionary parms) {
    final predictor = parms.getInt('Predictor', 1);
    if (predictor == 1) return data; // No prediction
    
    final columns = parms.getInt('Columns', 1);
    final colors = parms.getInt('Colors', 1);
    final bitsPerComponent = parms.getInt('BitsPerComponent', 8);
    
    final bytesPerPixel = (colors * bitsPerComponent + 7) ~/ 8;
    final bytesPerRow = (columns * colors * bitsPerComponent + 7) ~/ 8;
    
    if (predictor >= 10 && predictor <= 15) {
      // PNG predictors
      return _decodePngPredictor(data, bytesPerRow, bytesPerPixel);
    } else if (predictor == 2) {
      // TIFF predictor
      return _decodeTiffPredictor(data, bytesPerRow, bytesPerPixel);
    }
    
    return data;
  }
  
  Uint8List _decodePngPredictor(Uint8List data, int bytesPerRow, int bytesPerPixel) {
    final rowSize = bytesPerRow + 1; // +1 for filter byte
    final rows = data.length ~/ rowSize;
    final output = Uint8List(rows * bytesPerRow);
    final prevRow = Uint8List(bytesPerRow);
    
    for (var row = 0; row < rows; row++) {
      final srcOffset = row * rowSize;
      final dstOffset = row * bytesPerRow;
      final filter = data[srcOffset];
      
      for (var col = 0; col < bytesPerRow; col++) {
        final raw = data[srcOffset + 1 + col];
        final left = col >= bytesPerPixel ? output[dstOffset + col - bytesPerPixel] : 0;
        final up = prevRow[col];
        final upLeft = col >= bytesPerPixel ? prevRow[col - bytesPerPixel] : 0;
        
        int decoded;
        switch (filter) {
          case 0: // None
            decoded = raw;
            break;
          case 1: // Sub
            decoded = (raw + left) & 0xFF;
            break;
          case 2: // Up
            decoded = (raw + up) & 0xFF;
            break;
          case 3: // Average
            decoded = (raw + ((left + up) >> 1)) & 0xFF;
            break;
          case 4: // Paeth
            decoded = (raw + _paethPredictor(left, up, upLeft)) & 0xFF;
            break;
          default:
            decoded = raw;
        }
        
        output[dstOffset + col] = decoded;
      }
      
      // Save current row as previous
      for (var i = 0; i < bytesPerRow; i++) {
        prevRow[i] = output[dstOffset + i];
      }
    }
    
    return output;
  }
  
  int _paethPredictor(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }
  
  Uint8List _decodeTiffPredictor(Uint8List data, int bytesPerRow, int bytesPerPixel) {
    final rows = data.length ~/ bytesPerRow;
    final output = Uint8List.fromList(data);
    
    for (var row = 0; row < rows; row++) {
      final offset = row * bytesPerRow;
      for (var col = bytesPerPixel; col < bytesPerRow; col++) {
        output[offset + col] = 
            (output[offset + col] + output[offset + col - bytesPerPixel]) & 0xFF;
      }
    }
    
    return output;
  }
  
  Uint8List _decodeAsciiHex(Uint8List data) {
    final result = <int>[];
    var highNibble = -1;
    
    for (final byte in data) {
      if (byte == 0x3E) break; // '>' end marker
      
      int? nibble;
      if (byte >= 0x30 && byte <= 0x39) {
        nibble = byte - 0x30;
      } else if (byte >= 0x41 && byte <= 0x46) {
        nibble = byte - 0x41 + 10;
      } else if (byte >= 0x61 && byte <= 0x66) {
        nibble = byte - 0x61 + 10;
      }
      
      if (nibble != null) {
        if (highNibble < 0) {
          highNibble = nibble;
        } else {
          result.add((highNibble << 4) | nibble);
          highNibble = -1;
        }
      }
    }
    
    // Handle odd number of digits
    if (highNibble >= 0) {
      result.add(highNibble << 4);
    }
    
    return Uint8List.fromList(result);
  }
  
  Uint8List _decodeAscii85(Uint8List data) {
    final result = <int>[];
    var tuple = 0;
    var count = 0;
    
    for (final byte in data) {
      if (byte == 0x7E) break; // '~' end marker (part of ~>)
      if (byte <= 0x20) continue; // Skip whitespace
      
      if (byte == 0x7A) { // 'z' represents 4 zero bytes
        if (count > 0) {
          // Invalid: z in middle of group
          break;
        }
        result.addAll([0, 0, 0, 0]);
        continue;
      }
      
      if (byte < 0x21 || byte > 0x75) continue; // Invalid character
      
      tuple = tuple * 85 + (byte - 0x21);
      count++;
      
      if (count == 5) {
        result.add((tuple >> 24) & 0xFF);
        result.add((tuple >> 16) & 0xFF);
        result.add((tuple >> 8) & 0xFF);
        result.add(tuple & 0xFF);
        tuple = 0;
        count = 0;
      }
    }
    
    // Handle remaining bytes
    if (count > 0) {
      for (var i = count; i < 5; i++) {
        tuple = tuple * 85 + 84;
      }
      for (var i = 0; i < count - 1; i++) {
        result.add((tuple >> (24 - i * 8)) & 0xFF);
      }
    }
    
    return Uint8List.fromList(result);
  }
  
  Uint8List _decodeLzw(Uint8List data, PdfDictionary? parms) {
    // LZW decoding implementation
    // This is a simplified version - full implementation would be more complex
    try {
      // Use archive package's LZW decoder if available
      // For now, return data as-is (placeholder)
      return data;
    } catch (_) {
      return data;
    }
  }
  
  Uint8List _decodeRunLength(Uint8List data) {
    final result = <int>[];
    var i = 0;
    
    while (i < data.length) {
      final length = data[i++];
      
      if (length == 128) break; // EOD marker
      
      if (length < 128) {
        // Copy next length+1 bytes literally
        final count = length + 1;
        for (var j = 0; j < count && i < data.length; j++) {
          result.add(data[i++]);
        }
      } else {
        // Repeat next byte 257-length times
        if (i >= data.length) break;
        final count = 257 - length;
        final byte = data[i++];
        for (var j = 0; j < count; j++) {
          result.add(byte);
        }
      }
    }
    
    return Uint8List.fromList(result);
  }
  
  @override
  PdfStream clone() {
    return PdfStream(
      _dict.clone(),
      Uint8List.fromList(_rawData),
    );
  }
  
  @override
  void writeTo(StringBuffer buffer) {
    _dict.writeTo(buffer);
    buffer.write('\nstream\n');
    // Note: actual binary data would be written separately
    buffer.write('endstream');
  }
  
  @override
  String toString() => 'PdfStream(length: $rawLength, filters: $filters)';
}

/// Accessor for stream data with automatic decoding
class StreamAcc {
  final PdfStream _stream;
  Uint8List? _data;
  
  StreamAcc(this._stream);
  
  /// Load and decode stream data
  void loadAllData() {
    _data = _stream.data;
  }
  
  /// Get decoded data
  Uint8List get data => _data ?? _stream.data;
  
  /// Get data length
  int get length => data.length;
  
  /// Get the stream dictionary
  PdfDictionary get dict => _stream.dict;
}
