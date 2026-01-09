/// PDF Page
/// 
/// Port of core/fpdfapi/page/cpdf_page.h

import '../../fxcrt/fx_coordinates.dart';
import '../../fxcrt/fx_types.dart';
import '../parser/pdf_array.dart';
import '../parser/pdf_dictionary.dart';
import '../parser/pdf_document.dart';
import '../parser/pdf_object.dart';
import '../parser/pdf_stream.dart';
import 'pdf_page_object.dart';

/// PDF Page
/// 
/// Equivalent to CPDF_Page in PDFium
class PdfPage {
  final PdfDocument _document;
  final int _pageIndex;
  final PdfDictionary _pageDict;
  
  /// Parsed page objects (lazily loaded)
  List<PdfPageObject>? _objects;
  
  /// Resources dictionary
  PdfDictionary? _resources;
  
  PdfPage(this._document, this._pageIndex, this._pageDict);
  
  /// Get the page index (0-based)
  int get pageIndex => _pageIndex;
  
  /// Get the page dictionary
  PdfDictionary get pageDict => _pageDict;
  
  /// Alias for pageDict
  PdfDictionary get dict => _pageDict;
  
  /// Get the document
  PdfDocument get document => _document;
  
  /// Get MediaBox (required)
  FxRect get mediaBox {
    var box = _pageDict.getRect('MediaBox');
    if (box != null) return box.normalized();
    
    // Try parent
    box = _getInheritedRect('MediaBox');
    if (box != null) return box.normalized();
    
    // Default to US Letter
    return const FxRect(0, 0, 612, 792);
  }
  
  /// Get CropBox (defaults to MediaBox)
  FxRect get cropBox {
    return _pageDict.getRect('CropBox')?.normalized() ??
           _getInheritedRect('CropBox')?.normalized() ??
           mediaBox;
  }
  
  /// Get BleedBox (defaults to CropBox)
  FxRect get bleedBox {
    return _pageDict.getRect('BleedBox')?.normalized() ?? cropBox;
  }
  
  /// Get TrimBox (defaults to CropBox)
  FxRect get trimBox {
    return _pageDict.getRect('TrimBox')?.normalized() ?? cropBox;
  }
  
  /// Get ArtBox (defaults to CropBox)
  FxRect get artBox {
    return _pageDict.getRect('ArtBox')?.normalized() ?? cropBox;
  }
  
  /// Get page width (from MediaBox)
  double get width => mediaBox.width;
  
  /// Get page height (from MediaBox)
  double get height => mediaBox.height;
  
  /// Get page size
  FxSize get size => FxSize(width, height);
  
  /// Get page rotation (0, 90, 180, 270)
  PageRotation get rotation {
    final rotate = _pageDict.getInt('Rotate') ?? _getInheritedInt('Rotate') ?? 0;
    return PageRotation.fromDegrees(rotate);
  }
  
  /// Get effective page size (accounting for rotation)
  FxSize get effectiveSize {
    final rot = rotation;
    if (rot == PageRotation.rotate90 || rot == PageRotation.rotate270) {
      return FxSize(height, width);
    }
    return size;
  }
  
  /// Get resources dictionary
  PdfDictionary? get resources {
    _resources ??= _pageDict.getDict('Resources') ?? _getInheritedDict('Resources');
    return _resources;
  }
  
  /// Get page contents
  List<PdfStream> getContents() {
    final contents = _pageDict.get('Contents');
    if (contents == null) return [];
    
    if (contents is PdfStream) {
      return [contents];
    }
    
    if (contents is PdfArray) {
      final result = <PdfStream>[];
      for (var i = 0; i < contents.length; i++) {
        final item = contents.getAt(i);
        if (item is PdfStream) {
          result.add(item);
        }
      }
      return result;
    }
    
    return [];
  }
  
  /// Get concatenated content stream data
  List<int> getContentData() {
    final contents = getContents();
    if (contents.isEmpty) return [];
    
    final result = <int>[];
    for (final stream in contents) {
      result.addAll(stream.data);
      result.add(0x0A); // Newline between streams
    }
    return result;
  }
  
  /// Get annotations array
  PdfArray? get annotations => _pageDict.getArray('Annots');
  
  /// Get number of annotations
  int get annotationCount => annotations?.length ?? 0;
  
  // Helper methods for inherited attributes
  
  FxRect? _getInheritedRect(String key) {
    var parent = _pageDict.getDict('Parent');
    while (parent != null) {
      final rect = parent.getRect(key);
      if (rect != null) return rect;
      parent = parent.getDict('Parent');
    }
    return null;
  }
  
  int? _getInheritedInt(String key) {
    var parent = _pageDict.getDict('Parent');
    while (parent != null) {
      if (parent.has(key)) {
        return parent.getInt(key);
      }
      parent = parent.getDict('Parent');
    }
    return null;
  }
  
  PdfDictionary? _getInheritedDict(String key) {
    // First check the page itself
    var dict = _pageDict.getDict(key);
    if (dict != null) return dict;
    
    // Then check parents
    var parent = _pageDict.getDict('Parent');
    while (parent != null) {
      dict = parent.getDict(key);
      if (dict != null) return dict;
      parent = parent.getDict('Parent');
    }
    return null;
  }
  
  /// Convert page coordinates to device coordinates
  FxMatrix getDisplayMatrix(int width, int height, {PageRotation? rotate}) {
    final effectiveRotation = rotate ?? rotation;
    final box = mediaBox;
    
    // Calculate scale to fit
    var scaleX = width / box.width;
    var scaleY = height / box.height;
    
    // Adjust for rotation
    if (effectiveRotation == PageRotation.rotate90 || 
        effectiveRotation == PageRotation.rotate270) {
      scaleX = width / box.height;
      scaleY = height / box.width;
    }
    
    // Use uniform scale
    final scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Build transformation matrix
    var matrix = const FxMatrix.identity();
    
    // Translate origin
    matrix = matrix.translate(-box.left, -box.bottom);
    
    // Apply scale
    matrix = matrix.scaleBy(scale, -scale); // Flip Y axis
    
    // Adjust for rotation
    switch (effectiveRotation) {
      case PageRotation.none:
        matrix = matrix.translate(0, -box.height * scale);
        break;
      case PageRotation.rotate90:
        matrix = matrix.rotateBy(-90 * 3.14159265 / 180);
        matrix = matrix.translate(-box.height * scale, 0);
        break;
      case PageRotation.rotate180:
        matrix = matrix.rotateBy(-180 * 3.14159265 / 180);
        matrix = matrix.translate(-box.width * scale, box.height * scale);
        break;
      case PageRotation.rotate270:
        matrix = matrix.rotateBy(-270 * 3.14159265 / 180);
        matrix = matrix.translate(0, box.width * scale);
        break;
    }
    
    return matrix;
  }
  
  @override
  String toString() => 'PdfPage(index: $_pageIndex, size: ${width}x$height)';
}
