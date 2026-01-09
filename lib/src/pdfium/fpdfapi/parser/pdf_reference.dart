/// PDF Reference (indirect object reference)
/// 
/// Port of core/fpdfapi/parser/cpdf_reference.h

import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_object.dart';

/// PDF Reference to an indirect object
/// 
/// Equivalent to CPDF_Reference in PDFium
/// 
/// Written as: objNum genNum R (e.g., "12 0 R")
class PdfReference extends PdfObject {
  final int _refObjNum;
  final int _refGenNum;
  IndirectObjectHolder? _holder;
  
  /// Create a reference
  PdfReference(this._refObjNum, [this._refGenNum = 0, this._holder]);
  
  @override
  PdfObjectType get type => PdfObjectType.reference;
  
  /// Get the referenced object number
  int get refObjNum => _refObjNum;
  
  /// Get the referenced generation number
  int get refGenNum => _refGenNum;
  
  /// Get the object holder
  IndirectObjectHolder? get holder => _holder;
  
  /// Set the object holder
  set holder(IndirectObjectHolder? value) => _holder = value;
  
  /// Get the referenced object (dereference)
  @override
  PdfObject get direct {
    if (_holder == null) return this;
    final obj = _holder!.getIndirectObjectFor(_refObjNum, _refGenNum);
    if (obj == null) return this;
    // Handle chained references
    if (obj is PdfReference) {
      return obj.direct;
    }
    return obj;
  }
  
  /// Try to get the referenced object
  PdfObject? tryGetDirect() {
    if (_holder == null) return null;
    final obj = _holder!.getIndirectObjectFor(_refObjNum, _refGenNum);
    if (obj == null) return null;
    if (obj is PdfReference) {
      return obj.tryGetDirect();
    }
    return obj;
  }
  
  @override
  ByteString get stringValue {
    final resolved = tryGetDirect();
    return resolved?.stringValue ?? ByteString.empty();
  }
  
  @override
  WideString get unicodeText {
    final resolved = tryGetDirect();
    return resolved?.unicodeText ?? WideString.empty();
  }
  
  @override
  int get intValue {
    final resolved = tryGetDirect();
    return resolved?.intValue ?? 0;
  }
  
  @override
  double get numberValue {
    final resolved = tryGetDirect();
    return resolved?.numberValue ?? 0.0;
  }
  
  @override
  PdfReference clone() => PdfReference(_refObjNum, _refGenNum, _holder);
  
  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('$_refObjNum $_refGenNum R');
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is PdfReference) {
      return _refObjNum == other._refObjNum && _refGenNum == other._refGenNum;
    }
    return false;
  }
  
  @override
  int get hashCode => Object.hash(_refObjNum, _refGenNum);
  
  @override
  String toString() => 'PdfReference($_refObjNum $_refGenNum R)';
}
