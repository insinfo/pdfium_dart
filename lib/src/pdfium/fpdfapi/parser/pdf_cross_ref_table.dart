/// PDF Cross-Reference Table
/// 
/// Port of core/fpdfapi/parser/cpdf_cross_ref_table.h

import 'dart:typed_data';

import '../../fxcrt/fx_stream.dart';
import 'pdf_array.dart';
import 'pdf_dictionary.dart';
import 'pdf_stream.dart';
import 'pdf_syntax_parser.dart';

/// Entry in the cross-reference table
class XRefEntry {
  /// Object offset in file (for type 1) or object number in object stream (for type 2)
  int offset;
  
  /// Generation number (for type 1) or object stream object number (for type 2)
  int genNum;
  
  /// Entry type: 0=free, 1=in use, 2=compressed (in object stream)
  int type;
  
  XRefEntry({
    this.offset = 0,
    this.genNum = 0,
    this.type = 0,
  });
  
  /// Check if entry is in use
  bool get isInUse => type == 1;
  
  /// Check if entry is compressed (in object stream)
  bool get isCompressed => type == 2;
  
  /// Check if entry is free
  bool get isFree => type == 0;
  
  @override
  String toString() => 'XRefEntry(offset: $offset, genNum: $genNum, type: $type)';
}

/// PDF Cross-Reference Table
/// 
/// Equivalent to CPDF_CrossRefTable in PDFium
class PdfCrossRefTable {
  /// Entries indexed by object number
  final Map<int, XRefEntry> _entries = {};
  
  /// Trailer dictionary
  PdfDictionary? trailer;
  
  /// Get entry for object number
  XRefEntry? getEntry(int objNum) => _entries[objNum];
  
  /// Set entry for object number
  void setEntry(int objNum, XRefEntry entry) {
    _entries[objNum] = entry;
  }
  
  /// Check if object number exists
  bool hasEntry(int objNum) => _entries.containsKey(objNum);
  
  /// Get all object numbers
  Iterable<int> get objectNumbers => _entries.keys;
  
  /// Get total number of entries
  int get count => _entries.length;
  
  /// Get maximum object number
  int get maxObjNum => _entries.keys.isEmpty ? 0 : _entries.keys.reduce((a, b) => a > b ? a : b);
  
  /// Clear all entries
  void clear() {
    _entries.clear();
    trailer = null;
  }
  
  /// Merge another cross-reference table (for incremental updates)
  void merge(PdfCrossRefTable other) {
    for (final entry in other._entries.entries) {
      _entries[entry.key] = entry.value;
    }
    // Keep the most recent trailer
    if (other.trailer != null) {
      trailer = other.trailer;
    }
  }
}

/// Parser for cross-reference tables
class XRefParser {
  final PdfSyntaxParser _parser;
  
  XRefParser(this._parser);
  
  /// Parse cross-reference table at given position
  /// 
  /// Handles both traditional xref table format and xref streams
  PdfCrossRefTable? parse(int xrefPos) {
    _parser.position = xrefPos;
    _parser.skipWhitespaceAndComments();
    
    final keyword = _parser.readKeyword();
    
    if (keyword == 'xref') {
      // Traditional xref table
      return _parseTraditionalXRef();
    } else {
      // Might be an xref stream
      _parser.position = xrefPos;
      return _parseXRefStream();
    }
  }
  
  PdfCrossRefTable? _parseTraditionalXRef() {
    final table = PdfCrossRefTable();
    
    // Parse xref sections
    while (true) {
      _parser.skipWhitespaceAndComments();
      
      // Check for trailer
      final savedPos = _parser.position;
      final keyword = _parser.readKeyword();
      
      if (keyword == 'trailer') {
        break;
      }
      
      // Parse subsection header: startObjNum count
      _parser.position = savedPos;
      
      final startNum = _parser.readNumber();
      if (startNum == null) break;
      
      final count = _parser.readNumber();
      if (count == null) break;
      
      // Parse entries
      for (var i = 0; i < count.intValue; i++) {
        final offset = _parser.readNumber();
        final gen = _parser.readNumber();
        final type = _parser.readKeyword();
        
        if (offset == null || gen == null) break;
        
        final entry = XRefEntry(
          offset: offset.intValue,
          genNum: gen.intValue,
          type: type == 'n' ? 1 : 0,
        );
        
        table.setEntry(startNum.intValue + i, entry);
      }
    }
    
    // Parse trailer dictionary
    _parser.skipWhitespaceAndComments();
    final trailerDict = _parser.readDictionary();
    table.trailer = trailerDict;
    
    return table;
  }
  
  PdfCrossRefTable? _parseXRefStream() {
    // Try to read indirect object containing xref stream
    final indirect = _parser.readIndirectObject();
    if (indirect == null) return null;
    
    final (objNum, genNum, obj) = indirect;
    if (obj is! PdfStream) return null;
    
    final dict = obj.dict;
    if (dict.getName('Type') != 'XRef') return null;
    
    return parseXRefStreamData(obj);
  }
  
  /// Parse an xref stream object
  PdfCrossRefTable? parseXRefStreamData(PdfStream stream) {
    final table = PdfCrossRefTable();
    final dict = stream.dict;
    
    table.trailer = dict;
    
    // Get W array (field widths)
    final wArray = dict.getArray('W');
    if (wArray == null || wArray.length != 3) return null;
    
    final w1 = wArray.getIntAt(0);
    final w2 = wArray.getIntAt(1);
    final w3 = wArray.getIntAt(2);
    final entrySize = w1 + w2 + w3;
    
    // Get Index array (subsection definitions)
    List<int> indices = [];
    final indexArray = dict.getArray('Index');
    if (indexArray != null) {
      for (var i = 0; i < indexArray.length; i++) {
        indices.add(indexArray.getIntAt(i));
      }
    } else {
      // Default: single subsection starting at 0 with Size entries
      indices = [0, dict.getInt('Size')];
    }
    
    // Decode stream data
    final data = stream.data;
    var dataOffset = 0;
    
    // Process each subsection
    for (var i = 0; i < indices.length; i += 2) {
      if (i + 1 >= indices.length) break;
      
      final firstObjNum = indices[i];
      final count = indices[i + 1];
      
      for (var j = 0; j < count; j++) {
        if (dataOffset + entrySize > data.length) break;
        
        // Read fields
        final field1 = _readField(data, dataOffset, w1);
        final field2 = _readField(data, dataOffset + w1, w2);
        final field3 = _readField(data, dataOffset + w1 + w2, w3);
        dataOffset += entrySize;
        
        // Determine type (default to 1 if w1 is 0)
        final type = w1 > 0 ? field1 : 1;
        
        final entry = XRefEntry(
          type: type,
          offset: field2,
          genNum: field3,
        );
        
        table.setEntry(firstObjNum + j, entry);
      }
    }
    
    return table;
  }
  
  int _readField(Uint8List data, int offset, int width) {
    if (width == 0) return 0;
    
    var value = 0;
    for (var i = 0; i < width && offset + i < data.length; i++) {
      value = (value << 8) | data[offset + i];
    }
    return value;
  }
}
