/// PDF Name object
/// 
/// Port of core/fpdfapi/parser/cpdf_name.h

import '../../fxcrt/fx_string.dart';
import '../../fxcrt/fx_types.dart';
import 'pdf_object.dart';

/// PDF Name object
/// 
/// Equivalent to CPDF_Name in PDFium
/// 
/// Names are atomic symbols uniquely defined by a sequence of characters.
/// They are written as a solidus (/) followed by the name characters.
class PdfName extends PdfObject {
  ByteString _name;
  
  /// Create a name from a string (without the leading /)
  PdfName(String name) : _name = ByteString.fromString(name);
  
  /// Create from ByteString
  PdfName.fromByteString(this._name);
  
  /// Parse a name with possible escape sequences (#xx)
  factory PdfName.parse(String rawName) {
    if (!rawName.contains('#')) {
      return PdfName(rawName);
    }
    
    // Decode #xx escape sequences
    final buffer = StringBuffer();
    var i = 0;
    while (i < rawName.length) {
      if (rawName[i] == '#' && i + 2 < rawName.length) {
        final hex = rawName.substring(i + 1, i + 3);
        final code = int.tryParse(hex, radix: 16);
        if (code != null) {
          buffer.writeCharCode(code);
          i += 3;
          continue;
        }
      }
      buffer.write(rawName[i]);
      i++;
    }
    
    return PdfName(buffer.toString());
  }
  
  @override
  PdfObjectType get type => PdfObjectType.name;
  
  /// Get the name value
  String get name => _name.toLatin1String();
  
  @override
  ByteString get stringValue => _name;
  
  @override
  WideString get unicodeText => WideString.fromString(name);
  
  /// Set the name value
  void setName(String value) {
    _name = ByteString.fromString(value);
  }
  
  @override
  PdfName clone() => PdfName.fromByteString(
    ByteString.fromBytes(_name.data.toList())
  );
  
  @override
  void writeTo(StringBuffer buffer) {
    buffer.write('/');
    _writeEncodedName(buffer);
  }
  
  void _writeEncodedName(StringBuffer buffer) {
    for (var i = 0; i < _name.length; i++) {
      final byte = _name[i];
      // Characters that need to be escaped
      if (byte < 33 || byte > 126 || 
          byte == 0x23 || // #
          byte == 0x25 || // %
          byte == 0x28 || // (
          byte == 0x29 || // )
          byte == 0x2F || // /
          byte == 0x3C || // <
          byte == 0x3E || // >
          byte == 0x5B || // [
          byte == 0x5D || // ]
          byte == 0x7B || // {
          byte == 0x7D)   // }
      {
        buffer.write('#');
        buffer.write(byte.toRadixString(16).padLeft(2, '0'));
      } else {
        buffer.writeCharCode(byte);
      }
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is PdfName) return _name == other._name;
    if (other is String) return name == other;
    return false;
  }
  
  @override
  int get hashCode => _name.hashCode;
  
  @override
  String toString() => 'PdfName(/$name)';
  
  // Common PDF name constants
  static final nameType = PdfName('Type');
  static final nameSubtype = PdfName('Subtype');
  static final namePages = PdfName('Pages');
  static final namePage = PdfName('Page');
  static final nameCount = PdfName('Count');
  static final nameKids = PdfName('Kids');
  static final nameParent = PdfName('Parent');
  static final nameResources = PdfName('Resources');
  static final nameMediaBox = PdfName('MediaBox');
  static final nameCropBox = PdfName('CropBox');
  static final nameContents = PdfName('Contents');
  static final nameRotate = PdfName('Rotate');
  static final nameCatalog = PdfName('Catalog');
  static final nameRoot = PdfName('Root');
  static final nameInfo = PdfName('Info');
  static final nameSize = PdfName('Size');
  static final nameId = PdfName('ID');
  static final nameEncrypt = PdfName('Encrypt');
  static final nameLength = PdfName('Length');
  static final nameFilter = PdfName('Filter');
  static final nameDecodeParms = PdfName('DecodeParms');
  static final nameFlateDecode = PdfName('FlateDecode');
  static final nameAsciiHexDecode = PdfName('ASCIIHexDecode');
  static final nameAscii85Decode = PdfName('ASCII85Decode');
  static final nameLzwDecode = PdfName('LZWDecode');
  static final nameDctDecode = PdfName('DCTDecode');
  static final nameCcittFaxDecode = PdfName('CCITTFaxDecode');
  static final nameJbig2Decode = PdfName('JBIG2Decode');
  static final nameJpxDecode = PdfName('JPXDecode');
  static final nameXObject = PdfName('XObject');
  static final nameImage = PdfName('Image');
  static final nameForm = PdfName('Form');
  static final nameWidth = PdfName('Width');
  static final nameHeight = PdfName('Height');
  static final nameBitsPerComponent = PdfName('BitsPerComponent');
  static final nameColorSpace = PdfName('ColorSpace');
  static final nameDeviceRgb = PdfName('DeviceRGB');
  static final nameDeviceGray = PdfName('DeviceGray');
  static final nameDeviceCmyk = PdfName('DeviceCMYK');
  static final nameFont = PdfName('Font');
  static final nameBaseFont = PdfName('BaseFont');
  static final nameEncoding = PdfName('Encoding');
  static final nameToUnicode = PdfName('ToUnicode');
  static final nameFontDescriptor = PdfName('FontDescriptor');
  static final nameFirstChar = PdfName('FirstChar');
  static final nameLastChar = PdfName('LastChar');
  static final nameWidths = PdfName('Widths');
  static final nameN = PdfName('N');
  static final nameFirst = PdfName('First');
  static final namePrev = PdfName('Prev');
  static final nameW = PdfName('W');
  static final nameIndex = PdfName('Index');
  static final nameXRef = PdfName('XRef');
  static final nameObjStm = PdfName('ObjStm');
}
