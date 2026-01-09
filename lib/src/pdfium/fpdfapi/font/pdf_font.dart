

import '../../fxcrt/fx_coordinates.dart';
import '../parser/pdf_array.dart';
import '../parser/pdf_dictionary.dart';
import '../parser/pdf_number.dart';
import '../parser/pdf_stream.dart';

/// Tipos de fonte PDF
enum FontType {
  type1,
  trueType,
  type3,
  cidFontType0,
  cidFontType2,
  mmType1,
  type0,
  unknown,
}

/// Subtipos de fonte
enum FontSubtype {
  type1,
  type1c,
  type1cot,
  trueType,
  trueTypeOT,
  type3,
  cidFontType0,
  cidFontType0c,
  cidFontType0cot,
  cidFontType2,
  cidFontType2ot,
  unknown,
}

/// Flags de fonte (PDF Reference Table 5.19)
class FontFlags {
  final int value;
  
  const FontFlags(this.value);
  
  bool get fixedPitch => (value & (1 << 0)) != 0;
  bool get serif => (value & (1 << 1)) != 0;
  bool get symbolic => (value & (1 << 2)) != 0;
  bool get script => (value & (1 << 3)) != 0;
  bool get nonsymbolic => (value & (1 << 5)) != 0;
  bool get italic => (value & (1 << 6)) != 0;
  bool get allCap => (value & (1 << 16)) != 0;
  bool get smallCap => (value & (1 << 17)) != 0;
  bool get forceBold => (value & (1 << 18)) != 0;
}

/// Métricas de glifo
class GlyphMetrics {
  final double width;
  final double height;
  final double bearingX;
  final double bearingY;
  final double advance;
  
  const GlyphMetrics({
    this.width = 0,
    this.height = 0,
    this.bearingX = 0,
    this.bearingY = 0,
    this.advance = 0,
  });
  
  static const empty = GlyphMetrics();
}

/// Informações de glifo
class GlyphInfo {
  final int charCode;
  final int glyphIndex;
  final double advance;
  final FxRect? bounds;
  
  const GlyphInfo({
    required this.charCode,
    required this.glyphIndex,
    this.advance = 0,
    this.bounds,
  });
}

/// Encoding de fonte
abstract class FontEncoding {
  int charCodeToGlyphIndex(int charCode);
  int? unicodeToCharCode(int unicode);
  int? charCodeToUnicode(int charCode);
}

/// Encoding padrão (Standard, MacRoman, WinAnsi)
class StandardEncoding implements FontEncoding {
  final String name;
  final Map<int, int> _charToGlyph;
  final Map<int, int> _charToUnicode;
  
  StandardEncoding._(this.name, this._charToGlyph, this._charToUnicode);
  
  factory StandardEncoding.standard() {
    return StandardEncoding._('StandardEncoding', _standardMap, _standardUnicode);
  }
  
  factory StandardEncoding.macRoman() {
    return StandardEncoding._('MacRomanEncoding', _macRomanMap, _macRomanUnicode);
  }
  
  factory StandardEncoding.winAnsi() {
    return StandardEncoding._('WinAnsiEncoding', _winAnsiMap, _winAnsiUnicode);
  }
  
  factory StandardEncoding.pdfDoc() {
    return StandardEncoding._('PDFDocEncoding', _pdfDocMap, _pdfDocUnicode);
  }
  
  @override
  int charCodeToGlyphIndex(int charCode) {
    return _charToGlyph[charCode] ?? charCode;
  }
  
  @override
  int? unicodeToCharCode(int unicode) {
    for (final entry in _charToUnicode.entries) {
      if (entry.value == unicode) return entry.key;
    }
    return null;
  }
  
  @override
  int? charCodeToUnicode(int charCode) {
    return _charToUnicode[charCode] ?? charCode;
  }
  
  // Mapeamentos simplificados - ASCII básico
  static final Map<int, int> _standardMap = {
    for (int i = 0; i < 256; i++) i: i,
  };
  
  static final Map<int, int> _standardUnicode = {
    for (int i = 0; i < 128; i++) i: i,
  };
  
  static final Map<int, int> _macRomanMap = {
    for (int i = 0; i < 256; i++) i: i,
  };
  
  static final Map<int, int> _macRomanUnicode = {
    for (int i = 0; i < 128; i++) i: i,
  };
  
  static final Map<int, int> _winAnsiMap = {
    for (int i = 0; i < 256; i++) i: i,
  };
  
  static final Map<int, int> _winAnsiUnicode = {
    for (int i = 0; i < 128; i++) i: i,
    // Caracteres especiais WinAnsi
    0x80: 0x20AC, // Euro
    0x82: 0x201A, // Single Low-9 Quotation
    0x83: 0x0192, // Latin Small Letter F With Hook
    0x84: 0x201E, // Double Low-9 Quotation
    0x85: 0x2026, // Horizontal Ellipsis
    0x86: 0x2020, // Dagger
    0x87: 0x2021, // Double Dagger
    0x88: 0x02C6, // Modifier Letter Circumflex
    0x89: 0x2030, // Per Mille Sign
    0x8A: 0x0160, // Latin Capital Letter S With Caron
    0x8B: 0x2039, // Single Left-Pointing Angle Quotation
    0x8C: 0x0152, // Latin Capital Ligature OE
    0x8E: 0x017D, // Latin Capital Letter Z With Caron
    0x91: 0x2018, // Left Single Quotation
    0x92: 0x2019, // Right Single Quotation
    0x93: 0x201C, // Left Double Quotation
    0x94: 0x201D, // Right Double Quotation
    0x95: 0x2022, // Bullet
    0x96: 0x2013, // En Dash
    0x97: 0x2014, // Em Dash
    0x98: 0x02DC, // Small Tilde
    0x99: 0x2122, // Trade Mark Sign
    0x9A: 0x0161, // Latin Small Letter S With Caron
    0x9B: 0x203A, // Single Right-Pointing Angle Quotation
    0x9C: 0x0153, // Latin Small Ligature OE
    0x9E: 0x017E, // Latin Small Letter Z With Caron
    0x9F: 0x0178, // Latin Capital Letter Y With Diaeresis
    for (int i = 0xA0; i < 256; i++) i: i,
  };
  
  static final Map<int, int> _pdfDocMap = _winAnsiMap;
  static final Map<int, int> _pdfDocUnicode = _winAnsiUnicode;
}

/// Differences encoding (customização sobre um encoding base)
class DifferencesEncoding implements FontEncoding {
  final FontEncoding base;
  final Map<int, String> differences;
  final Map<String, int> _glyphNameToIndex;
  
  DifferencesEncoding(this.base, this.differences)
      : _glyphNameToIndex = _buildGlyphNameMap(differences);
  
  static Map<String, int> _buildGlyphNameMap(Map<int, String> diffs) {
    final map = <String, int>{};
    for (final entry in diffs.entries) {
      map[entry.value] = entry.key;
    }
    return map;
  }
  
  @override
  int charCodeToGlyphIndex(int charCode) {
    if (differences.containsKey(charCode)) {
      return charCode; // Usar código diretamente para differences
    }
    return base.charCodeToGlyphIndex(charCode);
  }
  
  @override
  int? unicodeToCharCode(int unicode) {
    return base.unicodeToCharCode(unicode);
  }
  
  @override
  int? charCodeToUnicode(int charCode) {
    if (differences.containsKey(charCode)) {
      // Tentar mapear nome de glifo para unicode
      final glyphName = differences[charCode]!;
      return _adobeGlyphNameToUnicode(glyphName) ?? charCode;
    }
    return base.charCodeToUnicode(charCode);
  }
  
  static int? _adobeGlyphNameToUnicode(String name) {
    // Mapeamento básico de nomes de glifo Adobe para Unicode
    const adobeGlyphList = <String, int>{
      'space': 0x0020,
      'exclam': 0x0021,
      'quotedbl': 0x0022,
      'numbersign': 0x0023,
      'dollar': 0x0024,
      'percent': 0x0025,
      'ampersand': 0x0026,
      'quotesingle': 0x0027,
      'parenleft': 0x0028,
      'parenright': 0x0029,
      'asterisk': 0x002A,
      'plus': 0x002B,
      'comma': 0x002C,
      'hyphen': 0x002D,
      'period': 0x002E,
      'slash': 0x002F,
      'zero': 0x0030,
      'one': 0x0031,
      'two': 0x0032,
      'three': 0x0033,
      'four': 0x0034,
      'five': 0x0035,
      'six': 0x0036,
      'seven': 0x0037,
      'eight': 0x0038,
      'nine': 0x0039,
      'colon': 0x003A,
      'semicolon': 0x003B,
      'less': 0x003C,
      'equal': 0x003D,
      'greater': 0x003E,
      'question': 0x003F,
      'at': 0x0040,
      // ... mais mapeamentos conforme necessário
    };
    
    if (adobeGlyphList.containsKey(name)) {
      return adobeGlyphList[name];
    }
    
    // Formato uniXXXX
    if (name.startsWith('uni') && name.length == 7) {
      return int.tryParse(name.substring(3), radix: 16);
    }
    
    // Formato uXXXX ou uXXXXX
    if (name.startsWith('u') && name.length >= 5) {
      return int.tryParse(name.substring(1), radix: 16);
    }
    
    return null;
  }
}

/// ToUnicode CMap para mapeamento de códigos para Unicode
class ToUnicodeCMap {
  final Map<int, int> _singleMappings = {};
  final List<_CMapRange> _rangeMappings = [];
  
  ToUnicodeCMap();
  
  /// Cria CMap a partir de stream
  factory ToUnicodeCMap.fromStream(PdfStream stream) {
    final cmap = ToUnicodeCMap();
    final data = stream.decodedData;
    if (data == null) return cmap;
    
    final text = String.fromCharCodes(data);
    cmap._parse(text);
    return cmap;
  }
  
  void _parse(String text) {
    // Parser simplificado de CMap
    final lines = text.split('\n');
    bool inBfChar = false;
    bool inBfRange = false;
    
    for (var line in lines) {
      line = line.trim();
      
      if (line.contains('beginbfchar')) {
        inBfChar = true;
        continue;
      }
      if (line.contains('endbfchar')) {
        inBfChar = false;
        continue;
      }
      if (line.contains('beginbfrange')) {
        inBfRange = true;
        continue;
      }
      if (line.contains('endbfrange')) {
        inBfRange = false;
        continue;
      }
      
      if (inBfChar) {
        _parseBfChar(line);
      }
      if (inBfRange) {
        _parseBfRange(line);
      }
    }
  }
  
  void _parseBfChar(String line) {
    // Formato: <srcCode> <dstString>
    final matches = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>').allMatches(line);
    for (final match in matches) {
      final srcCode = int.tryParse(match.group(1)!, radix: 16);
      final dstCode = int.tryParse(match.group(2)!, radix: 16);
      if (srcCode != null && dstCode != null) {
        _singleMappings[srcCode] = dstCode;
      }
    }
  }
  
  void _parseBfRange(String line) {
    // Formato: <srcCodeLo> <srcCodeHi> <dstStringLo>
    final match = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>').firstMatch(line);
    if (match != null) {
      final lo = int.tryParse(match.group(1)!, radix: 16);
      final hi = int.tryParse(match.group(2)!, radix: 16);
      final dst = int.tryParse(match.group(3)!, radix: 16);
      if (lo != null && hi != null && dst != null) {
        _rangeMappings.add(_CMapRange(lo, hi, dst));
      }
    }
  }
  
  /// Mapeia código de caractere para Unicode
  int? charCodeToUnicode(int charCode) {
    if (_singleMappings.containsKey(charCode)) {
      return _singleMappings[charCode];
    }
    
    for (final range in _rangeMappings) {
      if (charCode >= range.lo && charCode <= range.hi) {
        return range.dstStart + (charCode - range.lo);
      }
    }
    
    return null;
  }
}

class _CMapRange {
  final int lo;
  final int hi;
  final int dstStart;
  
  _CMapRange(this.lo, this.hi, this.dstStart);
}

/// Fonte PDF base
abstract class PdfFont {
  final PdfDictionary dict;
  final String name;
  final FontType type;
  final FontSubtype subtype;
  final FontEncoding? encoding;
  final ToUnicodeCMap? toUnicode;
  
  PdfFont({
    required this.dict,
    required this.name,
    required this.type,
    required this.subtype,
    this.encoding,
    this.toUnicode,
  });
  
  /// Cria fonte a partir de dicionário
  factory PdfFont.fromDictionary(PdfDictionary dict) {
    final subtype = dict.getName('Subtype') ?? '';
    final baseName = dict.getName('BaseFont') ?? 'Unknown';
    
    switch (subtype) {
      case 'Type1':
        return Type1Font.fromDictionary(dict);
      case 'TrueType':
        return TrueTypeFont.fromDictionary(dict);
      case 'Type0':
        return Type0Font.fromDictionary(dict);
      case 'Type3':
        return Type3Font.fromDictionary(dict);
      default:
        return SimpleFont.fromDictionary(dict);
    }
  }
  
  /// Obtém largura do caractere (em unidades de 1/1000 do tamanho do texto)
  double getCharWidth(int charCode);
  
  /// Obtém unicode do caractere
  int? getUnicode(int charCode) {
    if (toUnicode != null) {
      final u = toUnicode!.charCodeToUnicode(charCode);
      if (u != null) return u;
    }
    return encoding?.charCodeToUnicode(charCode) ?? charCode;
  }
  
  /// Descritor de fonte
  FontDescriptor? get descriptor;
}

/// Descritor de fonte
class FontDescriptor {
  final String fontName;
  final FontFlags flags;
  final double ascent;
  final double descent;
  final double capHeight;
  final double xHeight;
  final double italicAngle;
  final double stemV;
  final double stemH;
  final FxRect fontBBox;
  
  FontDescriptor({
    required this.fontName,
    required this.flags,
    this.ascent = 0,
    this.descent = 0,
    this.capHeight = 0,
    this.xHeight = 0,
    this.italicAngle = 0,
    this.stemV = 0,
    this.stemH = 0,
    this.fontBBox = const FxRect(0, 0, 1000, 1000),
  });
  
  factory FontDescriptor.fromDictionary(PdfDictionary dict) {
    final bbox = dict.getArray('FontBBox');
    
    return FontDescriptor(
      fontName: dict.getName('FontName') ?? '',
      flags: FontFlags(dict.getInt('Flags') ?? 0),
      ascent: dict.getNumber('Ascent') ?? 0,
      descent: dict.getNumber('Descent') ?? 0,
      capHeight: dict.getNumber('CapHeight') ?? 0,
      xHeight: dict.getNumber('XHeight') ?? 0,
      italicAngle: dict.getNumber('ItalicAngle') ?? 0,
      stemV: dict.getNumber('StemV') ?? 0,
      stemH: dict.getNumber('StemH') ?? 0,
      fontBBox: bbox != null && bbox.length >= 4
          ? FxRect(
              bbox.getNumberAt(0) ?? 0,
              bbox.getNumberAt(1) ?? 0,
              bbox.getNumberAt(2) ?? 1000,
              bbox.getNumberAt(3) ?? 1000,
            )
          : const FxRect(0, 0, 1000, 1000),
    );
  }
}

/// Fonte simples (Type1, TrueType sem CID)
class SimpleFont extends PdfFont {
  final List<double> widths;
  final int firstChar;
  final int lastChar;
  final FontDescriptor? _descriptor;
  
  SimpleFont({
    required super.dict,
    required super.name,
    required super.type,
    required super.subtype,
    super.encoding,
    super.toUnicode,
    this.widths = const [],
    this.firstChar = 0,
    this.lastChar = 255,
    FontDescriptor? descriptor,
  }) : _descriptor = descriptor;
  
  factory SimpleFont.fromDictionary(PdfDictionary dict) {
    final baseName = dict.getName('BaseFont') ?? 'Unknown';
    final subtypeStr = dict.getName('Subtype') ?? '';
    
    // Parse encoding
    FontEncoding? encoding;
    final encodingObj = dict.get('Encoding');
    if (encodingObj is PdfDictionary) {
      encoding = _parseEncodingDict(encodingObj);
    } else {
      final encodingName = dict.getName('Encoding');
      encoding = _parseEncodingName(encodingName);
    }
    
    // Parse ToUnicode
    ToUnicodeCMap? toUnicode;
    final toUnicodeStream = dict.getStream('ToUnicode');
    if (toUnicodeStream != null) {
      toUnicode = ToUnicodeCMap.fromStream(toUnicodeStream);
    }
    
    // Parse widths
    final widthsArray = dict.getArray('Widths');
    final widths = <double>[];
    if (widthsArray != null) {
      for (int i = 0; i < widthsArray.length; i++) {
        widths.add(widthsArray.getNumberAt(i) ?? 0);
      }
    }
    
    // Parse font descriptor
    FontDescriptor? descriptor;
    final descriptorDict = dict.getDictionary('FontDescriptor');
    if (descriptorDict != null) {
      descriptor = FontDescriptor.fromDictionary(descriptorDict);
    }
    
    final subtype = subtypeStr == 'TrueType' 
        ? FontSubtype.trueType 
        : FontSubtype.type1;
    
    return SimpleFont(
      dict: dict,
      name: baseName,
      type: subtypeStr == 'TrueType' ? FontType.trueType : FontType.type1,
      subtype: subtype,
      encoding: encoding,
      toUnicode: toUnicode,
      widths: widths,
      firstChar: dict.getInt('FirstChar') ?? 0,
      lastChar: dict.getInt('LastChar') ?? 255,
      descriptor: descriptor,
    );
  }
  
  static FontEncoding? _parseEncodingName(String? name) {
    switch (name) {
      case 'StandardEncoding':
        return StandardEncoding.standard();
      case 'MacRomanEncoding':
        return StandardEncoding.macRoman();
      case 'WinAnsiEncoding':
        return StandardEncoding.winAnsi();
      case 'PDFDocEncoding':
        return StandardEncoding.pdfDoc();
      default:
        return StandardEncoding.winAnsi(); // Default
    }
  }
  
  static FontEncoding? _parseEncodingDict(PdfDictionary dict) {
    final baseEncodingName = dict.getName('BaseEncoding');
    final base = _parseEncodingName(baseEncodingName) ?? StandardEncoding.standard();
    
    final differencesArray = dict.getArray('Differences');
    if (differencesArray == null) return base;
    
    final differences = <int, String>{};
    int currentCode = 0;
    
    for (int i = 0; i < differencesArray.length; i++) {
      final item = differencesArray[i];
      if (item is PdfNumber) {
        currentCode = item.intValue;
      } else {
        final name = differencesArray.getNameAt(i);
        if (name != null) {
          differences[currentCode] = name;
          currentCode++;
        }
      }
    }
    
    return DifferencesEncoding(base, differences);
  }
  
  @override
  double getCharWidth(int charCode) {
    if (charCode < firstChar || charCode > lastChar) {
      return 0;
    }
    final index = charCode - firstChar;
    if (index >= 0 && index < widths.length) {
      return widths[index];
    }
    return 0;
  }
  
  @override
  FontDescriptor? get descriptor => _descriptor;
}

/// Fonte Type1
class Type1Font extends SimpleFont {
  Type1Font({
    required super.dict,
    required super.name,
    super.encoding,
    super.toUnicode,
    super.widths,
    super.firstChar,
    super.lastChar,
    super.descriptor,
  }) : super(
    type: FontType.type1,
    subtype: FontSubtype.type1,
  );
  
  factory Type1Font.fromDictionary(PdfDictionary dict) {
    final simple = SimpleFont.fromDictionary(dict);
    return Type1Font(
      dict: dict,
      name: simple.name,
      encoding: simple.encoding,
      toUnicode: simple.toUnicode,
      widths: simple.widths,
      firstChar: simple.firstChar,
      lastChar: simple.lastChar,
      descriptor: simple.descriptor,
    );
  }
}

/// Fonte TrueType
class TrueTypeFont extends SimpleFont {
  TrueTypeFont({
    required super.dict,
    required super.name,
    super.encoding,
    super.toUnicode,
    super.widths,
    super.firstChar,
    super.lastChar,
    super.descriptor,
  }) : super(
    type: FontType.trueType,
    subtype: FontSubtype.trueType,
  );
  
  factory TrueTypeFont.fromDictionary(PdfDictionary dict) {
    final simple = SimpleFont.fromDictionary(dict);
    return TrueTypeFont(
      dict: dict,
      name: simple.name,
      encoding: simple.encoding,
      toUnicode: simple.toUnicode,
      widths: simple.widths,
      firstChar: simple.firstChar,
      lastChar: simple.lastChar,
      descriptor: simple.descriptor,
    );
  }
}

/// Fonte Type0 (CID fonts compostas)
class Type0Font extends PdfFont {
  final List<PdfFont> descendantFonts;
  
  Type0Font({
    required super.dict,
    required super.name,
    super.encoding,
    super.toUnicode,
    this.descendantFonts = const [],
  }) : super(
    type: FontType.type0,
    subtype: FontSubtype.unknown,
  );
  
  factory Type0Font.fromDictionary(PdfDictionary dict) {
    final baseName = dict.getName('BaseFont') ?? 'Unknown';
    
    // Parse ToUnicode
    ToUnicodeCMap? toUnicode;
    final toUnicodeStream = dict.getStream('ToUnicode');
    if (toUnicodeStream != null) {
      toUnicode = ToUnicodeCMap.fromStream(toUnicodeStream);
    }
    
    // Parse DescendantFonts
    final descendantFonts = <PdfFont>[];
    final descendantsArray = dict.getArray('DescendantFonts');
    if (descendantsArray != null) {
      for (int i = 0; i < descendantsArray.length; i++) {
        final fontDict = descendantsArray.getDictAt(i);
        if (fontDict != null) {
          descendantFonts.add(CIDFont.fromDictionary(fontDict));
        }
      }
    }
    
    return Type0Font(
      dict: dict,
      name: baseName,
      toUnicode: toUnicode,
      descendantFonts: descendantFonts,
    );
  }
  
  @override
  double getCharWidth(int charCode) {
    if (descendantFonts.isEmpty) return 0;
    return descendantFonts.first.getCharWidth(charCode);
  }
  
  @override
  FontDescriptor? get descriptor => 
      descendantFonts.isNotEmpty ? descendantFonts.first.descriptor : null;
}

/// Fonte CID (usada como descendente de Type0)
class CIDFont extends PdfFont {
  final Map<int, double> cidWidths;
  final double defaultWidth;
  final FontDescriptor? _descriptor;
  
  CIDFont({
    required super.dict,
    required super.name,
    required super.type,
    required super.subtype,
    this.cidWidths = const {},
    this.defaultWidth = 1000,
    FontDescriptor? descriptor,
  }) : _descriptor = descriptor;
  
  factory CIDFont.fromDictionary(PdfDictionary dict) {
    final baseName = dict.getName('BaseFont') ?? 'Unknown';
    final subtypeStr = dict.getName('Subtype') ?? '';
    
    final defaultWidth = dict.getNumber('DW') ?? 1000;
    
    // Parse W (widths)
    final cidWidths = <int, double>{};
    final wArray = dict.getArray('W');
    if (wArray != null) {
      _parseWidthsArray(wArray, cidWidths);
    }
    
    // Parse font descriptor
    FontDescriptor? descriptor;
    final descriptorDict = dict.getDictionary('FontDescriptor');
    if (descriptorDict != null) {
      descriptor = FontDescriptor.fromDictionary(descriptorDict);
    }
    
    final type = subtypeStr == 'CIDFontType2' 
        ? FontType.cidFontType2 
        : FontType.cidFontType0;
    final subtype = subtypeStr == 'CIDFontType2'
        ? FontSubtype.cidFontType2
        : FontSubtype.cidFontType0;
    
    return CIDFont(
      dict: dict,
      name: baseName,
      type: type,
      subtype: subtype,
      cidWidths: cidWidths,
      defaultWidth: defaultWidth,
      descriptor: descriptor,
    );
  }
  
  static void _parseWidthsArray(PdfArray w, Map<int, double> widths) {
    int i = 0;
    while (i < w.length) {
      final first = w.getIntAt(i);
      if (first == null) break;
      i++;
      
      if (i >= w.length) break;
      
      final second = w[i];
      if (second is PdfArray) {
        // Formato: c [w1 w2 w3 ...]
        for (int j = 0; j < second.length; j++) {
          widths[first + j] = second.getNumberAt(j) ?? 1000;
        }
        i++;
      } else {
        // Formato: c_first c_last w
        final last = w.getIntAt(i);
        i++;
        if (last == null || i >= w.length) break;
        
        final width = w.getNumberAt(i) ?? 1000;
        i++;
        
        for (int cid = first; cid <= last; cid++) {
          widths[cid] = width;
        }
      }
    }
  }
  
  @override
  double getCharWidth(int charCode) {
    return cidWidths[charCode] ?? defaultWidth;
  }
  
  @override
  FontDescriptor? get descriptor => _descriptor;
}

/// Fonte Type3 (fontes definidas por procedimentos PDF)
class Type3Font extends PdfFont {
  final FxRect fontBBox;
  final FxMatrix fontMatrix;
  final Map<int, double> charWidths;
  
  Type3Font({
    required super.dict,
    required super.name,
    this.fontBBox = const FxRect(0, 0, 1000, 1000),
    this.fontMatrix = const FxMatrix(0.001, 0, 0, 0.001, 0, 0),
    this.charWidths = const {},
  }) : super(
    type: FontType.type3,
    subtype: FontSubtype.type3,
  );
  
  factory Type3Font.fromDictionary(PdfDictionary dict) {
    // Parse FontBBox
    final bboxArray = dict.getArray('FontBBox');
    final fontBBox = bboxArray != null && bboxArray.length >= 4
        ? FxRect(
            bboxArray.getNumberAt(0) ?? 0,
            bboxArray.getNumberAt(1) ?? 0,
            bboxArray.getNumberAt(2) ?? 1000,
            bboxArray.getNumberAt(3) ?? 1000,
          )
        : const FxRect(0, 0, 1000, 1000);
    
    // Parse FontMatrix
    final matrixArray = dict.getArray('FontMatrix');
    final fontMatrix = matrixArray != null && matrixArray.length >= 6
        ? FxMatrix(
            matrixArray.getNumberAt(0) ?? 0.001,
            matrixArray.getNumberAt(1) ?? 0,
            matrixArray.getNumberAt(2) ?? 0,
            matrixArray.getNumberAt(3) ?? 0.001,
            matrixArray.getNumberAt(4) ?? 0,
            matrixArray.getNumberAt(5) ?? 0,
          )
        : const FxMatrix(0.001, 0, 0, 0.001, 0, 0);
    
    // Parse Widths
    final charWidths = <int, double>{};
    final widthsArray = dict.getArray('Widths');
    final firstChar = dict.getInt('FirstChar') ?? 0;
    if (widthsArray != null) {
      for (int i = 0; i < widthsArray.length; i++) {
        charWidths[firstChar + i] = widthsArray.getNumberAt(i) ?? 0;
      }
    }
    
    return Type3Font(
      dict: dict,
      name: 'Type3',
      fontBBox: fontBBox,
      fontMatrix: fontMatrix,
      charWidths: charWidths,
    );
  }
  
  @override
  double getCharWidth(int charCode) {
    return charWidths[charCode] ?? 0;
  }
  
  @override
  FontDescriptor? get descriptor => null;
}

/// Cache de fontes para evitar recarregar
class FontCache {
  final Map<String, PdfFont> _cache = {};
  
  PdfFont? get(String name) => _cache[name];
  
  void put(String name, PdfFont font) {
    _cache[name] = font;
  }
  
  void clear() {
    _cache.clear();
  }
  
  bool contains(String name) => _cache.containsKey(name);
}
