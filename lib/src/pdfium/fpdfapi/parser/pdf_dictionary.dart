/// PDF Dictionary object
/// 
/// Port of core/fpdfapi/parser/cpdf_dictionary.h

import 'dart:collection';

import '../../fxcrt/fx_coordinates.dart';
import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_array.dart';
import 'pdf_boolean.dart';
import 'pdf_name.dart';
import 'pdf_null.dart';
import 'pdf_number.dart';
import 'pdf_object.dart';
import 'pdf_reference.dart';
import 'pdf_stream.dart';
import 'pdf_string.dart';

/// PDF Dictionary object
/// 
/// Equivalent to CPDF_Dictionary in PDFium
class PdfDictionary extends PdfObject with MapMixin<String, PdfObject> {
  final Map<String, PdfObject> _map;
  IndirectObjectHolder? _holder;
  
  /// Create an empty dictionary
  PdfDictionary() : _map = {};
  
  /// Create from a map
  PdfDictionary.from(Map<String, PdfObject> map) : _map = Map.from(map);
  
  @override
  PdfObjectType get type => PdfObjectType.dictionary;
  
  /// Set the object holder for resolving references
  set holder(IndirectObjectHolder? value) {
    _holder = value;
    // Propagate to child references
    for (final entry in _map.values) {
      if (entry is PdfReference) {
        entry.holder = value;
      } else if (entry is PdfArray) {
        entry.holder = value;
      } else if (entry is PdfDictionary) {
        entry.holder = value;
      }
    }
  }
  
  /// Get the object holder
  IndirectObjectHolder? get holder => _holder;
  
  // Map interface implementation
  @override
  PdfObject? operator [](Object? key) => _map[key];
  
  @override
  void operator []=(String key, PdfObject value) {
    _map[key] = value;
    _propagateHolder(value);
  }
  
  @override
  void clear() => _map.clear();
  
  @override
  Iterable<String> get keys => _map.keys;
  
  @override
  PdfObject? remove(Object? key) => _map.remove(key);
  
  /// Get value by key, resolving references
  PdfObject? get(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is PdfReference) {
      return value.direct;
    }
    return value;
  }
  
  /// Get value by key without resolving references
  PdfObject? getDirect(String key) => _map[key];
  
  /// Get integer value
  int getInt(String key, [int defaultValue = 0]) {
    final obj = get(key);
    return obj?.intValue ?? defaultValue;
  }
  
  /// Get number value
  double getNumber(String key, [double defaultValue = 0.0]) {
    final obj = get(key);
    return obj?.numberValue ?? defaultValue;
  }
  
  /// Get boolean value
  bool getBool(String key, [bool defaultValue = false]) {
    final obj = get(key);
    if (obj is PdfBoolean) return obj.value;
    return defaultValue;
  }
  
  /// Get string value
  String getString(String key, [String defaultValue = '']) {
    final obj = get(key);
    if (obj == null) return defaultValue;
    if (obj is PdfString) return obj.text;
    if (obj is PdfName) return obj.name;
    return obj.stringValue.toLatin1String();
  }
  
  /// Get name value
  String? getName(String key) {
    final obj = get(key);
    if (obj is PdfName) return obj.name;
    return null;
  }
  
  /// Get array value
  PdfArray? getArray(String key) {
    final obj = get(key);
    if (obj is PdfArray) return obj;
    return null;
  }
  
  /// Get dictionary value
  PdfDictionary? getDict(String key) {
    final obj = get(key);
    if (obj is PdfDictionary) return obj;
    return null;
  }
  
  /// Alias for getDict
  PdfDictionary? getDictionary(String key) => getDict(key);
  
  /// Get stream value
  PdfStream? getStream(String key) {
    final obj = get(key);
    if (obj is PdfStream) return obj;
    return null;
  }
  
  /// Get rectangle value
  FxRect? getRect(String key) {
    return getArray(key)?.toRect();
  }
  
  /// Get matrix value
  FxMatrix? getMatrix(String key) {
    return getArray(key)?.toMatrix();
  }
  
  /// Check if key exists
  bool has(String key) => _map.containsKey(key);
  
  /// Set a value by key (alias for []=)
  void set(String key, PdfObject value) {
    this[key] = value;
  }
  
  /// Set integer value
  void setInt(String key, int value) {
    this[key] = PdfNumber.integer(value);
  }
  
  /// Set number value
  void setNumber(String key, num value) {
    this[key] = PdfNumber(value);
  }
  
  /// Set boolean value
  void setBool(String key, bool value) {
    this[key] = PdfBoolean(value);
  }
  
  /// Set string value
  void setString(String key, String value) {
    this[key] = PdfString(value);
  }
  
  /// Set name value
  void setName(String key, String value) {
    this[key] = PdfName(value);
  }
  
  /// Set reference
  void setReference(String key, int objNum, [int genNum = 0]) {
    this[key] = PdfReference(objNum, genNum, _holder);
  }
  
  /// Set rectangle
  void setRect(String key, FxRect rect) {
    this[key] = PdfArray.fromRect(rect);
  }
  
  /// Set matrix
  void setMatrix(String key, FxMatrix matrix) {
    this[key] = PdfArray.fromMatrix(matrix);
  }
  
  /// Get the Type name of this dictionary
  String? get typeName => getName('Type');
  
  /// Get the Subtype name of this dictionary
  String? get subtypeName => getName('Subtype') ?? getName('S');
  
  void _propagateHolder(PdfObject element) {
    if (_holder == null) return;
    if (element is PdfReference) {
      element.holder = _holder;
    } else if (element is PdfArray) {
      element.holder = _holder;
    } else if (element is PdfDictionary) {
      element.holder = _holder;
    }
  }
  
  @override
  PdfDictionary clone() {
    final result = PdfDictionary();
    for (final entry in _map.entries) {
      result[entry.key] = entry.value.clone();
    }
    return result;
  }
  
  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('<<');
    for (final entry in _map.entries) {
      buffer.write('/');
      buffer.write(entry.key);
      buffer.write(' ');
      entry.value.writeTo(buffer);
      buffer.write(' ');
    }
    buffer.write('>>');
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PdfDictionary) return false;
    if (length != other.length) return false;
    for (final key in keys) {
      if (!other.containsKey(key)) return false;
      if (this[key] != other[key]) return false;
    }
    return true;
  }
  
  @override
  int get hashCode => Object.hashAll(_map.entries);
  
  @override
  String toString() => 'PdfDictionary(${_map.keys.join(", ")})';
}
