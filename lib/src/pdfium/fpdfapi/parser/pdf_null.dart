/// PDF Null object
/// 
/// Port of core/fpdfapi/parser/cpdf_null.h

import '../../fxcrt/fx_types.dart';
import 'pdf_object.dart';

/// PDF Null object
/// 
/// Equivalent to CPDF_Null in PDFium
class PdfNull extends PdfObject {
  /// Singleton instance
  static final PdfNull instance = PdfNull._();
  
  PdfNull._();
  
  /// Create a null object (returns singleton)
  factory PdfNull() => instance;
  
  @override
  PdfObjectType get type => PdfObjectType.nullObj;
  
  @override
  PdfNull clone() => this;
  
  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('null');
  }
  
  @override
  bool operator ==(Object other) => other is PdfNull;
  
  @override
  int get hashCode => 0;
  
  @override
  String toString() => 'PdfNull';
}
