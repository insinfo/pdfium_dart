/// PDF Array object
/// 
/// Port of core/fpdfapi/parser/cpdf_array.h

import 'dart:collection';

import '../../fxcrt/fx_coordinates.dart';
import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_boolean.dart';
import 'pdf_dictionary.dart';
import 'pdf_name.dart';
import 'pdf_null.dart';
import 'pdf_number.dart';
import 'pdf_object.dart';
import 'pdf_reference.dart';
import 'pdf_string.dart';

/// PDF Array object
/// 
/// Equivalent to CPDF_Array in PDFium
class PdfArray extends PdfObject with IterableMixin<PdfObject> {
  final List<PdfObject> _elements;
  IndirectObjectHolder? _holder;
  
  /// Create an empty array
  PdfArray() : _elements = [];
  
  /// Create an array with initial elements
  PdfArray.from(Iterable<PdfObject> elements) 
      : _elements = List<PdfObject>.from(elements);
  
  /// Create from numbers (for rectangles, matrices, etc.)
  factory PdfArray.fromNumbers(List<num> numbers) {
    return PdfArray.from(numbers.map((n) => PdfNumber(n)));
  }
  
  /// Create a rectangle array [left, bottom, right, top]
  factory PdfArray.fromRect(FxRect rect) {
    return PdfArray.fromNumbers([rect.left, rect.bottom, rect.right, rect.top]);
  }
  
  /// Create a matrix array [a, b, c, d, e, f]
  factory PdfArray.fromMatrix(FxMatrix matrix) {
    return PdfArray.fromNumbers(matrix.toList());
  }
  
  @override
  PdfObjectType get type => PdfObjectType.array;
  
  /// Set the object holder for resolving references
  set holder(IndirectObjectHolder? value) {
    _holder = value;
    // Propagate to child references
    for (final element in _elements) {
      if (element is PdfReference) {
        element.holder = value;
      } else if (element is PdfArray) {
        element.holder = value;
      } else if (element is PdfDictionary) {
        element.holder = value;
      }
    }
  }
  
  /// Get the object holder
  IndirectObjectHolder? get holder => _holder;
  
  /// Number of elements
  int get length => _elements.length;
  
  @override
  bool get isEmpty => _elements.isEmpty;
  
  @override
  bool get isNotEmpty => _elements.isNotEmpty;
  
  @override
  Iterator<PdfObject> get iterator => _elements.iterator;
  
  /// Get element at index
  PdfObject operator [](int index) => _elements[index];
  
  /// Set element at index
  void operator []=(int index, PdfObject value) {
    _elements[index] = value;
    _propagateHolder(value);
  }
  
  /// Get element at index, resolving references
  PdfObject getAt(int index) {
    if (index < 0 || index >= _elements.length) {
      return PdfNull();
    }
    final element = _elements[index];
    if (element is PdfReference) {
      return element.direct;
    }
    return element;
  }
  
  /// Alias for getAt - get element at index resolving references
  PdfObject getDirectAt(int index) => getAt(index);
  
  /// Get integer at index
  int getIntAt(int index, [int defaultValue = 0]) {
    return getAt(index).intValue;
  }
  
  /// Get number at index
  double getNumberAt(int index, [double defaultValue = 0.0]) {
    return getAt(index).numberValue;
  }
  
  /// Get string at index
  String getStringAt(int index, [String defaultValue = '']) {
    final obj = getAt(index);
    if (obj is PdfString) return obj.text;
    if (obj is PdfName) return obj.name;
    return obj.stringValue.toLatin1String();
  }
  
  /// Get name at index
  String? getNameAt(int index) {
    final obj = getAt(index);
    if (obj is PdfName) return obj.name;
    return null;
  }
  
  /// Get array at index
  PdfArray? getArrayAt(int index) {
    final obj = getAt(index);
    if (obj is PdfArray) return obj;
    return null;
  }
  
  /// Get dictionary at index
  PdfDictionary? getDictAt(int index) {
    final obj = getAt(index);
    if (obj is PdfDictionary) return obj;
    return null;
  }
  
  /// Get as rectangle [left, bottom, right, top]
  FxRect? toRect() {
    if (length < 4) return null;
    return FxRect(
      getNumberAt(0),
      getNumberAt(1),
      getNumberAt(2),
      getNumberAt(3),
    );
  }
  
  /// Get as matrix [a, b, c, d, e, f]
  FxMatrix? toMatrix() {
    if (length < 6) return null;
    return FxMatrix(
      getNumberAt(0),
      getNumberAt(1),
      getNumberAt(2),
      getNumberAt(3),
      getNumberAt(4),
      getNumberAt(5),
    );
  }
  
  /// Add an element
  void add(PdfObject element) {
    _elements.add(element);
    _propagateHolder(element);
  }
  
  /// Add an integer
  void addInt(int value) => add(PdfNumber.integer(value));
  
  /// Add a number
  void addNumber(num value) => add(PdfNumber(value));
  
  /// Add a string
  void addString(String value) => add(PdfString(value));
  
  /// Add a name
  void addName(String value) => add(PdfName(value));
  
  /// Add a boolean
  void addBool(bool value) => add(PdfBoolean(value));
  
  /// Add a reference
  void addReference(int objNum, [int genNum = 0]) {
    add(PdfReference(objNum, genNum, _holder));
  }
  
  /// Insert element at index
  void insert(int index, PdfObject element) {
    _elements.insert(index, element);
    _propagateHolder(element);
  }
  
  /// Remove element at index
  PdfObject removeAt(int index) => _elements.removeAt(index);
  
  /// Remove specific element
  bool remove(PdfObject element) => _elements.remove(element);
  
  /// Clear all elements
  void clear() => _elements.clear();
  
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
  PdfArray clone() {
    final result = PdfArray();
    for (final element in _elements) {
      result.add(element.clone());
    }
    return result;
  }
  
  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('[');
    for (var i = 0; i < _elements.length; i++) {
      if (i > 0) buffer.write(' ');
      _elements[i].writeTo(buffer);
    }
    buffer.write(']');
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PdfArray) return false;
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      if (_elements[i] != other._elements[i]) return false;
    }
    return true;
  }
  
  @override
  int get hashCode => Object.hashAll(_elements);
  
  @override
  String toString() => 'PdfArray(length: $length)';
}
