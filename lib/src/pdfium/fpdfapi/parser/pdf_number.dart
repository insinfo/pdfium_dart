/// PDF Number object
/// 
/// Port of core/fpdfapi/parser/cpdf_number.h

import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_object.dart';

/// PDF Number object (integer or real)
/// 
/// Equivalent to CPDF_Number in PDFium
class PdfNumber extends PdfObject {
  /// Internal value storage
  /// For integers, stored as int. For reals, stored as double.
  num _value;
  bool _isInteger;
  
  /// Create an integer number
  PdfNumber.integer(int value) : _value = value, _isInteger = true;
  
  /// Create a real (floating-point) number
  PdfNumber.real(double value) : _value = value, _isInteger = false;
  
  /// Create from a numeric value (auto-detects type)
  factory PdfNumber(num value) {
    if (value is int) {
      return PdfNumber.integer(value);
    }
    return PdfNumber.real(value.toDouble());
  }
  
  /// Parse from string
  factory PdfNumber.parse(String str) {
    final trimmed = str.trim();
    
    // Check if it's an integer
    if (!trimmed.contains('.')) {
      final intValue = int.tryParse(trimmed);
      if (intValue != null) {
        return PdfNumber.integer(intValue);
      }
    }
    
    // Parse as double
    final doubleValue = double.tryParse(trimmed) ?? 0.0;
    return PdfNumber.real(doubleValue);
  }
  
  @override
  PdfObjectType get type => PdfObjectType.number;
  
  /// Check if this is an integer
  bool get isInteger => _isInteger;
  
  /// Check if this is a real number
  bool get isReal => !_isInteger;
  
  @override
  int get intValue => _value.toInt();
  
  @override
  double get numberValue => _value.toDouble();
  
  /// Get the raw numeric value
  num get value => _value;
  
  /// Set integer value
  void setInteger(int value) {
    _value = value;
    _isInteger = true;
  }
  
  /// Set real value
  void setReal(double value) {
    _value = value;
    _isInteger = false;
  }
  
  @override
  ByteString get stringValue {
    if (_isInteger) {
      return ByteString.fromString(_value.toInt().toString());
    }
    
    // Format real numbers appropriately
    final str = _formatReal(_value.toDouble());
    return ByteString.fromString(str);
  }
  
  @override
  PdfNumber clone() {
    if (_isInteger) {
      return PdfNumber.integer(_value.toInt());
    }
    return PdfNumber.real(_value.toDouble());
  }
  
  @override
  void writeTo(StringBuffer buffer) {
    if (_isInteger) {
      buffer.write(_value.toInt().toString());
    } else {
      buffer.write(_formatReal(_value.toDouble()));
    }
  }
  
  /// Format a real number for PDF output
  String _formatReal(double value) {
    // Handle special cases
    if (value == 0) return '0';
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    
    // PDF spec recommends no more than 5 decimal places
    var str = value.toStringAsFixed(5);
    
    // Remove trailing zeros
    while (str.endsWith('0')) {
      str = str.substring(0, str.length - 1);
    }
    
    // Remove trailing decimal point
    if (str.endsWith('.')) {
      str = str.substring(0, str.length - 1);
    }
    
    return str;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is PdfNumber) {
      return _value == other._value;
    }
    if (other is num) {
      return _value == other;
    }
    return false;
  }
  
  @override
  int get hashCode => _value.hashCode;
  
  @override
  String toString() => 'PdfNumber($_value${_isInteger ? "" : " (real)"})';
}
