/// PDF Boolean object
/// 
/// Port of core/fpdfapi/parser/cpdf_boolean.h

import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_object.dart';

/// PDF Boolean object
/// 
/// Equivalent to CPDF_Boolean in PDFium
class PdfBoolean extends PdfObject {
  bool _value;
  
  /// Create a boolean object
  PdfBoolean(this._value);
  
  /// Create from string ("true" or "false")
  factory PdfBoolean.fromString(String str) {
    return PdfBoolean(str.toLowerCase() == 'true');
  }
  
  @override
  PdfObjectType get type => PdfObjectType.boolean;
  
  /// Get the boolean value
  bool get value => _value;
  
  /// Set the boolean value
  set value(bool v) => _value = v;
  
  @override
  ByteString get stringValue => ByteString.fromString(_value ? 'true' : 'false');
  
  @override
  int get intValue => _value ? 1 : 0;
  
  @override
  double get numberValue => _value ? 1.0 : 0.0;
  
  @override
  PdfBoolean clone() => PdfBoolean(_value);
  
  @override
  void writeTo(StringBuffer buffer) {
    buffer.write(_value ? 'true' : 'false');
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is PdfBoolean) return _value == other._value;
    if (other is bool) return _value == other;
    return false;
  }
  
  @override
  int get hashCode => _value.hashCode;
  
  @override
  String toString() => 'PdfBoolean($_value)';
}
