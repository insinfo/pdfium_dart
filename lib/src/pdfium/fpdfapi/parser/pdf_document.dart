/// PDF Document
/// 
/// Port of core/fpdfapi/parser/cpdf_document.h

import 'dart:io';
import 'dart:typed_data';

import '../../fxcrt/fx_coordinates.dart';
import '../../fxcrt/fx_stream.dart';
import '../../fxcrt/fx_types.dart';
import '../page/pdf_page.dart';
import 'pdf_array.dart';
import 'pdf_dictionary.dart';
import 'pdf_object.dart';
import 'pdf_parser.dart';
import 'pdf_reference.dart';

/// PDF Document
/// 
/// Equivalent to CPDF_Document in PDFium
class PdfDocument implements IndirectObjectHolder {
  final PdfParser _parser;
  PdfDictionary? _root;
  PdfDictionary? _info;
  
  /// Page tree (lazily built)
  List<int>? _pageObjNums;
  
  /// Cached pages
  final Map<int, PdfPage> _pageCache = {};
  
  PdfDocument._(this._parser);
  
  /// Load a document from a file
  static Future<Result<PdfDocument>> fromFile(String path, {String? password}) async {
    final stream = await FileReadStream.open(path);
    if (stream == null) {
      return const Result.failure(PdfError.file);
    }
    
    return _loadFromStream(stream, password);
  }
  
  /// Load a document from a file synchronously
  static Result<PdfDocument> fromFileSync(String path, {String? password}) {
    final stream = FileReadStream.openSync(path);
    if (stream == null) {
      return const Result.failure(PdfError.file);
    }
    
    return _loadFromStream(stream, password);
  }
  
  /// Load a document from memory
  static Result<PdfDocument> fromMemory(Uint8List data, {String? password}) {
    final stream = MemoryReadStream(data);
    return _loadFromStream(stream, password);
  }
  
  static Result<PdfDocument> _loadFromStream(SeekableReadStream stream, String? password) {
    final parser = PdfParser();
    final result = parser.parse(stream);
    
    if (result.isFailure) {
      return Result.failure(result.error);
    }
    
    final doc = PdfDocument._(parser);
    
    // Load root catalog
    if (!doc._loadRoot()) {
      return const Result.failure(PdfError.format);
    }
    
    // TODO: Handle encryption with password
    
    return Result.success(doc);
  }
  
  bool _loadRoot() {
    final rootObjNum = _parser.rootObjNum;
    if (rootObjNum == 0) return false;
    
    final root = _parser.getIndirectObject(rootObjNum);
    if (root is! PdfDictionary) return false;
    
    _root = root;
    
    // Load info dictionary if present
    final infoObjNum = _parser.infoObjNum;
    if (infoObjNum > 0) {
      final info = _parser.getIndirectObject(infoObjNum);
      if (info is PdfDictionary) {
        _info = info;
      }
    }
    
    return true;
  }
  
  /// Get the root (catalog) dictionary
  PdfDictionary? get root => _root;
  
  /// Get the info dictionary
  PdfDictionary? get info => _info;
  
  /// Get the PDF version
  String get version => _parser.version;
  
  /// Get the number of pages
  int get pageCount {
    _ensurePageTree();
    return _pageObjNums?.length ?? 0;
  }
  
  /// Get a page by index (0-based)
  PdfPage? getPage(int pageIndex) {
    _ensurePageTree();
    
    if (pageIndex < 0 || pageIndex >= (_pageObjNums?.length ?? 0)) {
      return null;
    }
    
    // Check cache
    if (_pageCache.containsKey(pageIndex)) {
      return _pageCache[pageIndex];
    }
    
    // Load page
    final pageObjNum = _pageObjNums![pageIndex];
    final pageObj = _parser.getIndirectObject(pageObjNum);
    if (pageObj is! PdfDictionary) return null;
    
    final page = PdfPage(this, pageIndex, pageObj);
    _pageCache[pageIndex] = page;
    
    return page;
  }
  
  void _ensurePageTree() {
    if (_pageObjNums != null) return;
    
    _pageObjNums = [];
    
    final pages = _root?.get('Pages');
    if (pages is! PdfDictionary) return;
    
    _traversePageTree(pages);
  }
  
  void _traversePageTree(PdfDictionary node) {
    final type = node.getName('Type');
    
    if (type == 'Page') {
      // This is a page leaf node
      _pageObjNums!.add(node.objNum);
      return;
    }
    
    if (type == 'Pages') {
      // This is a pages node, traverse children
      final kids = node.getArray('Kids');
      if (kids == null) return;
      
      for (var i = 0; i < kids.length; i++) {
        final kid = kids.getAt(i);
        if (kid is PdfDictionary) {
          _traversePageTree(kid);
        }
      }
    }
  }
  
  /// Get document title
  String? get title => _info?.getString('Title');
  
  /// Get document author
  String? get author => _info?.getString('Author');
  
  /// Get document subject
  String? get subject => _info?.getString('Subject');
  
  /// Get document keywords
  String? get keywords => _info?.getString('Keywords');
  
  /// Get document creator
  String? get creator => _info?.getString('Creator');
  
  /// Get document producer
  String? get producer => _info?.getString('Producer');
  
  /// Get creation date
  String? get creationDate => _info?.getString('CreationDate');
  
  /// Get modification date
  String? get modDate => _info?.getString('ModDate');
  
  /// Get document metadata as a Map
  Map<String, String>? get metadata {
    if (_info == null) return null;
    
    final result = <String, String>{};
    
    final keys = ['Title', 'Author', 'Subject', 'Keywords', 
                  'Creator', 'Producer', 'CreationDate', 'ModDate'];
    
    for (final key in keys) {
      final value = _info!.getString(key);
      if (value != null) {
        result[key] = value;
      }
    }
    
    return result.isEmpty ? null : result;
  }
  
  // IndirectObjectHolder implementation
  
  @override
  PdfObject? getIndirectObject(int objNum) {
    return _parser.getIndirectObject(objNum);
  }
  
  @override
  PdfObject? getIndirectObjectFor(int objNum, int genNum) {
    return _parser.getIndirectObjectFor(objNum, genNum);
  }
  
  @override
  int addIndirectObject(PdfObject object) {
    return _parser.addIndirectObject(object);
  }
  
  @override
  bool replaceIndirectObject(int objNum, PdfObject object) {
    return _parser.replaceIndirectObject(objNum, object);
  }
  
  @override
  void deleteIndirectObject(int objNum) {
    _parser.deleteIndirectObject(objNum);
  }
  
  /// Close the document
  void close() {
    _pageCache.clear();
    _parser.close();
  }
}
