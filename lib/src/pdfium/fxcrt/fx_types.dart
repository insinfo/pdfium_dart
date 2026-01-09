/// Fundamental types for PDFium Dart
/// 
/// Port of core/fxcrt/fx_types.h

import 'dart:typed_data';

/// PDF object types - mirrors FPDF_OBJECT_* constants
enum PdfObjectType {
  unknown(0),
  boolean(1),
  number(2),
  string(3),
  name(4),
  array(5),
  dictionary(6),
  stream(7),
  nullObj(8),
  reference(9);

  const PdfObjectType(this.value);
  final int value;
  
  static PdfObjectType fromValue(int value) {
    return PdfObjectType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PdfObjectType.unknown,
    );
  }
}

/// Text rendering modes
enum TextRenderMode {
  unknown(-1),
  fill(0),
  stroke(1),
  fillStroke(2),
  invisible(3),
  fillClip(4),
  strokeClip(5),
  fillStrokeClip(6),
  clip(7);

  const TextRenderMode(this.value);
  final int value;
}

/// Duplex types for printing
enum DuplexType {
  undefined(0),
  simplex(1),
  flipShortEdge(2),
  flipLongEdge(3);

  const DuplexType(this.value);
  final int value;
}

/// Annotation subtypes
enum AnnotationSubtype {
  unknown(0),
  text(1),
  link(2),
  freeText(3),
  line(4),
  square(5),
  circle(6),
  polygon(7),
  polyline(8),
  highlight(9),
  underline(10),
  squiggly(11),
  strikeOut(12),
  stamp(13),
  caret(14),
  ink(15),
  popup(16),
  fileAttachment(17),
  sound(18),
  movie(19),
  widget(20),
  screen(21),
  printerMark(22),
  trapNet(23),
  watermark(24),
  threeDimensional(25),
  richMedia(26),
  xfaWidget(27),
  redact(28);

  const AnnotationSubtype(this.value);
  final int value;
}

/// Page rotation values
enum PageRotation {
  none(0),
  rotate90(1),
  rotate180(2),
  rotate270(3);

  const PageRotation(this.value);
  final int value;
  
  /// Get rotation in degrees
  int get degrees => value * 90;
  
  static PageRotation fromDegrees(int degrees) {
    final normalized = (degrees % 360 + 360) % 360;
    switch (normalized) {
      case 0:
        return PageRotation.none;
      case 90:
        return PageRotation.rotate90;
      case 180:
        return PageRotation.rotate180;
      case 270:
        return PageRotation.rotate270;
      default:
        return PageRotation.none;
    }
  }
}

/// Color space types
enum ColorSpaceType {
  deviceGray,
  deviceRgb,
  deviceCmyk,
  calGray,
  calRgb,
  lab,
  iccBased,
  separation,
  deviceN,
  indexed,
  pattern,
}

/// Bitmap format
enum BitmapFormat {
  /// Unknown or invalid format
  unknown(0),
  /// Gray scale bitmap, one byte per pixel
  gray(1),
  /// 3 bytes per pixel, byte order: blue, green, red
  bgr(2),
  /// 4 bytes per pixel, byte order: blue, green, red, unused
  bgrx(3),
  /// 4 bytes per pixel, byte order: blue, green, red, alpha
  bgra(4);

  const BitmapFormat(this.value);
  final int value;
  
  /// Bytes per pixel for this format
  int get bytesPerPixel {
    switch (this) {
      case BitmapFormat.unknown:
        return 0;
      case BitmapFormat.gray:
        return 1;
      case BitmapFormat.bgr:
        return 3;
      case BitmapFormat.bgrx:
      case BitmapFormat.bgra:
        return 4;
    }
  }
}

/// Error codes returned by PDF operations
enum PdfError {
  success(0),
  unknown(1),
  file(2),
  format(3),
  password(4),
  security(5),
  page(6),
  xfaLoad(7),
  xfaLayout(8);

  const PdfError(this.value);
  final int value;
  
  String get message {
    switch (this) {
      case PdfError.success:
        return 'Success';
      case PdfError.unknown:
        return 'Unknown error';
      case PdfError.file:
        return 'File not found or could not be opened';
      case PdfError.format:
        return 'File not in PDF format or corrupted';
      case PdfError.password:
        return 'Password required or incorrect password';
      case PdfError.security:
        return 'Security scheme not supported';
      case PdfError.page:
        return 'Page not found or content error';
      case PdfError.xfaLoad:
        return 'XFA load error';
      case PdfError.xfaLayout:
        return 'XFA layout error';
    }
  }
}

/// Filter types for PDF streams
enum StreamFilter {
  none,
  asciihexDecode,
  ascii85Decode,
  lzwDecode,
  flateDeocde,
  runLengthDecode,
  ccittFaxDecode,
  jbig2Decode,
  dctDecode,
  jpxDecode,
  crypt,
}

/// A span of bytes - similar to C++ pdfium::span
/// 
/// This is a lightweight view into a byte array.
class ByteSpan {
  final Uint8List _data;
  final int _offset;
  final int _length;
  
  ByteSpan(this._data, [this._offset = 0, int? length])
      : _length = length ?? (_data.length - _offset);
  
  factory ByteSpan.empty() => ByteSpan(Uint8List(0));
  
  factory ByteSpan.fromList(List<int> bytes) => 
      ByteSpan(Uint8List.fromList(bytes));
  
  int get length => _length;
  bool get isEmpty => _length == 0;
  bool get isNotEmpty => _length > 0;
  
  int operator [](int index) {
    if (index < 0 || index >= _length) {
      throw RangeError.index(index, this);
    }
    return _data[_offset + index];
  }
  
  ByteSpan subspan(int start, [int? length]) {
    final newLength = length ?? (_length - start);
    if (start < 0 || start > _length || newLength < 0 || start + newLength > _length) {
      throw RangeError('Invalid subspan range');
    }
    return ByteSpan(_data, _offset + start, newLength);
  }
  
  ByteSpan first(int count) => subspan(0, count);
  ByteSpan last(int count) => subspan(_length - count, count);
  
  Uint8List toBytes() {
    if (_offset == 0 && _length == _data.length) {
      return _data;
    }
    return Uint8List.sublistView(_data, _offset, _offset + _length);
  }
  
  Uint8List get data => _data;
  int get offset => _offset;
  
  @override
  String toString() => 'ByteSpan(length: $_length)';
}

/// Result type for operations that can fail
class Result<T> {
  final T? _value;
  final PdfError _error;
  
  const Result.success(T value) : _value = value, _error = PdfError.success;
  const Result.failure(PdfError error) : _value = null, _error = error;
  
  bool get isSuccess => _error == PdfError.success;
  bool get isFailure => _error != PdfError.success;
  
  T get value {
    if (_value == null) {
      throw StateError('Cannot get value from failed result: ${_error.message}');
    }
    return _value;
  }
  
  T? get valueOrNull => _value;
  PdfError get error => _error;
  
  T getOrElse(T defaultValue) => _value ?? defaultValue;
  
  Result<U> map<U>(U Function(T value) transform) {
    if (isSuccess) {
      return Result.success(transform(_value as T));
    }
    return Result.failure(_error);
  }
  
  Result<U> flatMap<U>(Result<U> Function(T value) transform) {
    if (isSuccess) {
      return transform(_value as T);
    }
    return Result.failure(_error);
  }
}
