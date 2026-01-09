/// PDF Object base class
/// 
/// Port of core/fpdfapi/parser/cpdf_object.h

import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';

/// Base class for all PDF objects
/// 
/// Equivalent to CPDF_Object in PDFium
/// 
/// PDF objects are defined in ISO 32000-1:2008 and include:
/// - Boolean
/// - Number (integer or real)
/// - String (literal or hexadecimal)
/// - Name
/// - Array
/// - Dictionary
/// - Stream
/// - Null
/// - Indirect Reference
abstract class PdfObject {
  /// Invalid object number constant
  static const int invalidObjNum = 0xFFFFFFFF;
  
  /// Object number (0 for inline objects)
  int _objNum = 0;
  
  /// Generation number
  int _genNum = 0;
  
  /// Get the object number
  int get objNum => _objNum;
  
  /// Set the object number
  set objNum(int value) => _objNum = value;
  
  /// Get the generation number
  int get genNum => _genNum;
  
  /// Set the generation number
  set genNum(int value) => _genNum = value;
  
  /// Check if this is an inline (not indirect) object
  bool get isInline => _objNum == 0;
  
  /// Get the object type
  PdfObjectType get type;
  
  /// Create a deep copy of this object
  PdfObject clone();
  
  /// Get the direct object (for references, returns the target object)
  PdfObject get direct => this;
  
  /// Get string value (for compatible types)
  ByteString get stringValue => ByteString.empty();
  
  /// Get Unicode text value
  WideString get unicodeText => WideString.empty();
  
  /// Get numeric value as double
  double get numberValue => 0.0;
  
  /// Get integer value
  int get intValue => 0;
  
  /// Type checking methods
  bool get isBoolean => type == PdfObjectType.boolean;
  bool get isNumber => type == PdfObjectType.number;
  bool get isString => type == PdfObjectType.string;
  bool get isName => type == PdfObjectType.name;
  bool get isArray => type == PdfObjectType.array;
  bool get isDictionary => type == PdfObjectType.dictionary;
  bool get isStream => type == PdfObjectType.stream;
  bool get isNull => type == PdfObjectType.nullObj;
  bool get isReference => type == PdfObjectType.reference;
  
  /// Write this object to a binary buffer (for serialization)
  void writeTo(StringBuffer buffer);
  
  @override
  String toString() => 'PdfObject(type: $type, objNum: $_objNum, genNum: $_genNum)';
}

/// Holder for indirect PDF objects
/// 
/// This class manages indirect objects and their resolution.
abstract class IndirectObjectHolder {
  /// Get an indirect object by its object number
  PdfObject? getIndirectObject(int objNum);
  
  /// Get an indirect object by object and generation number
  PdfObject? getIndirectObjectFor(int objNum, int genNum);
  
  /// Add a new indirect object
  int addIndirectObject(PdfObject object);
  
  /// Replace an indirect object
  bool replaceIndirectObject(int objNum, PdfObject object);
  
  /// Delete an indirect object
  void deleteIndirectObject(int objNum);
}
