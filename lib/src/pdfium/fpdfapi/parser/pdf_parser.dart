/// PDF Parser
/// 
/// Port of core/fpdfapi/parser/cpdf_parser.h

import 'dart:typed_data';

import '../../fxcrt/fx_stream.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_array.dart';
import 'pdf_cross_ref_table.dart';
import 'pdf_dictionary.dart';
import 'pdf_object.dart';
import 'pdf_reference.dart';
import 'pdf_stream.dart';
import 'pdf_syntax_parser.dart';

/// PDF file parser
/// 
/// Equivalent to CPDF_Parser in PDFium
class PdfParser implements IndirectObjectHolder {
  SeekableReadStream? _stream;
  PdfSyntaxParser? _syntaxParser;
  PdfCrossRefTable _crossRefTable = PdfCrossRefTable();
  
  /// Cached indirect objects
  final Map<int, PdfObject?> _objectCache = {};
  
  /// Object streams cache
  final Map<int, _ObjectStream> _objectStreams = {};
  
  /// PDF version (e.g., 1.4, 1.7, 2.0)
  String version = '1.4';
  
  /// Whether the file is linearized
  bool isLinearized = false;
  
  /// File ID from trailer
  PdfArray? fileId;
  
  /// Encryption dictionary
  PdfDictionary? encryptDict;
  
  /// Get the trailer dictionary
  PdfDictionary? get trailer => _crossRefTable.trailer;
  
  /// Get the cross-reference table
  PdfCrossRefTable get crossRefTable => _crossRefTable;
  
  /// Parse a PDF from a stream
  Result<void> parse(SeekableReadStream stream) {
    _stream = stream;
    _syntaxParser = PdfSyntaxParser(stream);
    _syntaxParser!.holder = this;
    
    // Check PDF header
    final headerResult = _parseHeader();
    if (headerResult.isFailure) return headerResult;
    
    // Find and parse cross-reference table
    final xrefResult = _parseXRef();
    if (xrefResult.isFailure) return xrefResult;
    
    // Load file ID and encryption info
    _loadTrailerInfo();
    
    return const Result.success(null);
  }
  
  /// Parse a PDF from bytes
  Result<void> parseBytes(Uint8List data) {
    return parse(MemoryReadStream(data));
  }
  
  Result<void> _parseHeader() {
    _syntaxParser!.position = 0;
    
    // Read first line
    final headerBytes = <int>[];
    while (!_syntaxParser!.reader.isEof && headerBytes.length < 20) {
      final byte = _syntaxParser!.reader.readByte();
      if (byte == 0x0A || byte == 0x0D) break;
      headerBytes.add(byte);
    }
    
    final header = String.fromCharCodes(headerBytes);
    
    // Check for %PDF- signature
    if (!header.startsWith('%PDF-')) {
      return const Result.failure(PdfError.format);
    }
    
    // Extract version
    version = header.substring(5).trim();
    if (version.isEmpty) {
      version = '1.4';
    }
    
    return const Result.success(null);
  }
  
  Result<void> _parseXRef() {
    // Find startxref
    final startxrefPos = _findStartXRef();
    if (startxrefPos == null) {
      return const Result.failure(PdfError.format);
    }
    
    // Read startxref value
    _syntaxParser!.position = startxrefPos + 9; // Length of 'startxref'
    _syntaxParser!.skipWhitespaceAndComments();
    final xrefPosNum = _syntaxParser!.readNumber();
    if (xrefPosNum == null) {
      return const Result.failure(PdfError.format);
    }
    
    // Parse xref chain (including Prev entries)
    var xrefPos = xrefPosNum.intValue;
    final visitedXrefs = <int>{};
    
    while (xrefPos > 0 && !visitedXrefs.contains(xrefPos)) {
      visitedXrefs.add(xrefPos);
      
      final xrefParser = XRefParser(_syntaxParser!);
      final table = xrefParser.parse(xrefPos);
      if (table == null) break;
      
      _crossRefTable.merge(table);
      
      // Check for previous xref
      xrefPos = table.trailer?.getInt('Prev') ?? 0;
    }
    
    return const Result.success(null);
  }
  
  int? _findStartXRef() {
    // Search backwards from end of file for startxref
    final searchSize = 1024;
    final fileSize = _stream!.size;
    final searchStart = fileSize > searchSize ? fileSize - searchSize : 0;
    
    _syntaxParser!.position = searchStart;
    final data = _syntaxParser!.reader.readBytes(fileSize - searchStart);
    if (data == null) return null;
    
    final dataStr = String.fromCharCodes(data);
    final idx = dataStr.lastIndexOf('startxref');
    if (idx < 0) return null;
    
    return searchStart + idx;
  }
  
  void _loadTrailerInfo() {
    final trailer = _crossRefTable.trailer;
    if (trailer == null) return;
    
    // Get file ID
    fileId = trailer.getArray('ID');
    
    // Get encryption dictionary
    encryptDict = trailer.getDict('Encrypt');
  }
  
  /// Get root (catalog) object number
  int get rootObjNum {
    final trailer = _crossRefTable.trailer;
    if (trailer == null) return 0;
    
    final root = trailer.getDirect('Root');
    if (root is PdfReference) {
      return root.refObjNum;
    }
    return 0;
  }
  
  /// Get info dictionary object number
  int get infoObjNum {
    final trailer = _crossRefTable.trailer;
    if (trailer == null) return 0;
    
    final info = trailer.getDirect('Info');
    if (info is PdfReference) {
      return info.refObjNum;
    }
    return 0;
  }
  
  // IndirectObjectHolder implementation
  
  @override
  PdfObject? getIndirectObject(int objNum) {
    return getIndirectObjectFor(objNum, 0);
  }
  
  @override
  PdfObject? getIndirectObjectFor(int objNum, int genNum) {
    // Check cache first
    if (_objectCache.containsKey(objNum)) {
      return _objectCache[objNum];
    }
    
    // Get entry from xref
    final entry = _crossRefTable.getEntry(objNum);
    if (entry == null || entry.isFree) {
      _objectCache[objNum] = null;
      return null;
    }
    
    PdfObject? obj;
    
    if (entry.isCompressed) {
      // Object is in an object stream
      obj = _loadCompressedObject(objNum, entry);
    } else {
      // Regular object
      obj = _loadObject(objNum, entry);
    }
    
    // Set object number and cache
    if (obj != null) {
      obj.objNum = objNum;
      obj.genNum = entry.genNum;
    }
    
    _objectCache[objNum] = obj;
    return obj;
  }
  
  PdfObject? _loadObject(int objNum, XRefEntry entry) {
    _syntaxParser!.position = entry.offset;
    
    final indirect = _syntaxParser!.readIndirectObject();
    if (indirect == null) return null;
    
    final (parsedObjNum, parsedGenNum, obj) = indirect;
    
    // Verify object number matches
    if (parsedObjNum != objNum) return null;
    
    return obj;
  }
  
  PdfObject? _loadCompressedObject(int objNum, XRefEntry entry) {
    // entry.genNum is the object stream's object number
    // entry.offset is the index within the object stream
    final streamObjNum = entry.genNum;
    final objectIndex = entry.offset;
    
    // Get or load the object stream
    var objStream = _objectStreams[streamObjNum];
    if (objStream == null) {
      final streamObj = getIndirectObject(streamObjNum);
      if (streamObj is! PdfStream) return null;
      
      objStream = _ObjectStream(streamObj, _syntaxParser!);
      _objectStreams[streamObjNum] = objStream;
    }
    
    return objStream.getObject(objNum, objectIndex);
  }
  
  @override
  int addIndirectObject(PdfObject object) {
    final newObjNum = _crossRefTable.maxObjNum + 1;
    object.objNum = newObjNum;
    object.genNum = 0;
    _objectCache[newObjNum] = object;
    
    _crossRefTable.setEntry(newObjNum, XRefEntry(
      offset: 0,
      genNum: 0,
      type: 1,
    ));
    
    return newObjNum;
  }
  
  @override
  bool replaceIndirectObject(int objNum, PdfObject object) {
    object.objNum = objNum;
    _objectCache[objNum] = object;
    return true;
  }
  
  @override
  void deleteIndirectObject(int objNum) {
    _objectCache.remove(objNum);
    final entry = _crossRefTable.getEntry(objNum);
    if (entry != null) {
      entry.type = 0; // Mark as free
    }
  }
  
  /// Close the parser
  void close() {
    _stream?.close();
    _stream = null;
    _syntaxParser = null;
    _objectCache.clear();
    _objectStreams.clear();
    _crossRefTable.clear();
  }
}

/// Helper class for parsing object streams
class _ObjectStream {
  final PdfStream _stream;
  final PdfSyntaxParser _parser;
  final Map<int, PdfObject?> _objects = {};
  List<(int objNum, int offset)>? _index;
  
  _ObjectStream(this._stream, this._parser);
  
  PdfObject? getObject(int objNum, int indexInStream) {
    // Parse index if not already done
    _index ??= _parseIndex();
    
    if (indexInStream >= _index!.length) return null;
    
    // Check if the index matches expected object number
    final (expectedObjNum, offset) = _index![indexInStream];
    if (expectedObjNum != objNum) {
      // Search for the object in index
      for (var i = 0; i < _index!.length; i++) {
        if (_index![i].$1 == objNum) {
          return _loadObject(objNum, _index![i].$2);
        }
      }
      return null;
    }
    
    return _loadObject(objNum, offset);
  }
  
  List<(int, int)> _parseIndex() {
    final dict = _stream.dict;
    final n = dict.getInt('N'); // Number of objects
    final first = dict.getInt('First'); // Offset to first object
    
    // Parse the index from stream header
    final data = _stream.data;
    final headerParser = PdfSyntaxParser.fromBytes(data);
    
    final index = <(int, int)>[];
    for (var i = 0; i < n; i++) {
      final objNum = headerParser.readNumber()?.intValue ?? 0;
      final offset = headerParser.readNumber()?.intValue ?? 0;
      index.add((objNum, first + offset));
    }
    
    return index;
  }
  
  PdfObject? _loadObject(int objNum, int offset) {
    if (_objects.containsKey(objNum)) {
      return _objects[objNum];
    }
    
    final data = _stream.data;
    if (offset >= data.length) return null;
    
    // Parse object at offset within stream
    final objParser = PdfSyntaxParser.fromBytes(
      Uint8List.sublistView(data, offset),
    );
    objParser.holder = _parser.holder;
    
    final obj = objParser.readObject();
    _objects[objNum] = obj;
    
    return obj;
  }
}
