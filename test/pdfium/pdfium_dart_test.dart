import 'dart:typed_data';

import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FxTypes', () {
    test('PdfObjectType values', () {
      expect(PdfObjectType.boolean.value, 1);
      expect(PdfObjectType.number.value, 2);
      expect(PdfObjectType.string.value, 3);
      expect(PdfObjectType.dictionary.value, 6);
    });
    
    test('PageRotation', () {
      expect(PageRotation.none.degrees, 0);
      expect(PageRotation.rotate90.degrees, 90);
      expect(PageRotation.rotate180.degrees, 180);
      expect(PageRotation.rotate270.degrees, 270);
      
      expect(PageRotation.fromDegrees(0), PageRotation.none);
      expect(PageRotation.fromDegrees(90), PageRotation.rotate90);
      expect(PageRotation.fromDegrees(180), PageRotation.rotate180);
      expect(PageRotation.fromDegrees(270), PageRotation.rotate270);
      expect(PageRotation.fromDegrees(360), PageRotation.none);
    });
    
    test('ByteSpan', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final span = ByteSpan(data);
      
      expect(span.length, 5);
      expect(span[0], 1);
      expect(span[4], 5);
      
      final sub = span.subspan(1, 3);
      expect(sub.length, 3);
      expect(sub[0], 2);
    });
    
    test('Result', () {
      final success = Result.success(42);
      expect(success.isSuccess, true);
      expect(success.value, 42);
      
      final failure = Result<int>.failure(PdfError.format);
      expect(failure.isFailure, true);
      expect(failure.error, PdfError.format);
    });
  });
  
  group('FxCoordinates', () {
    test('FxPoint', () {
      const p1 = FxPoint(10, 20);
      const p2 = FxPoint(5, 10);
      
      final sum = p1 + p2;
      expect(sum.x, 15);
      expect(sum.y, 30);
      
      final diff = p1 - p2;
      expect(diff.x, 5);
      expect(diff.y, 10);
      
      final scaled = p1 * 2;
      expect(scaled.x, 20);
      expect(scaled.y, 40);
    });
    
    test('FxRect', () {
      const rect = FxRect(10, 20, 100, 80);
      
      expect(rect.width, 90);
      expect(rect.height, 60);
      expect(rect.area, 5400);
      
      expect(rect.contains(const FxPoint(50, 50)), true);
      expect(rect.contains(const FxPoint(0, 0)), false);
    });
    
    test('FxMatrix', () {
      const identity = FxMatrix.identity();
      expect(identity.isIdentity, true);
      
      final translate = FxMatrix.translate(10, 20);
      final transformed = translate.transformPoint(const FxPoint(5, 5));
      expect(transformed.x, 15);
      expect(transformed.y, 25);
      
      final scale = FxMatrix.scale(2, 3);
      final scaled = scale.transformPoint(const FxPoint(10, 10));
      expect(scaled.x, 20);
      expect(scaled.y, 30);
    });
  });
  
  group('FxString', () {
    test('ByteString', () {
      final bs = ByteString.fromString('Hello');
      expect(bs.length, 5);
      expect(bs.toLatin1String(), 'Hello');
      expect(bs[0], 72); // 'H'
      
      expect(bs.startsWith(ByteString.fromString('He')), true);
      expect(bs.endsWith(ByteString.fromString('lo')), true);
    });
    
    test('WideString', () {
      final ws = WideString.fromString('Hello World');
      expect(ws.length, 11);
      expect(ws.toString(), 'Hello World');
      
      expect(ws.contains('World'), true);
      expect(ws.indexOf('World'), 6);
    });
    
    test('PdfStringCodec hex', () {
      final hex = PdfStringCodec.encodeHex([0x48, 0x65, 0x6C, 0x6C, 0x6F]);
      expect(hex, '48656c6c6f');
      
      final decoded = PdfStringCodec.decodeHex('48656C6C6F');
      expect(decoded, [0x48, 0x65, 0x6C, 0x6C, 0x6F]);
    });
  });
  
  group('PDF Objects', () {
    test('PdfBoolean', () {
      final t = PdfBoolean(true);
      final f = PdfBoolean(false);
      
      expect(t.value, true);
      expect(f.value, false);
      expect(t.type, PdfObjectType.boolean);
    });
    
    test('PdfNumber integer', () {
      final n = PdfNumber.integer(42);
      expect(n.intValue, 42);
      expect(n.numberValue, 42.0);
      expect(n.isInteger, true);
    });
    
    test('PdfNumber real', () {
      final n = PdfNumber.real(3.14159);
      expect(n.numberValue, closeTo(3.14159, 0.0001));
      expect(n.isInteger, false);
    });
    
    test('PdfString', () {
      final s = PdfString('Hello');
      expect(s.text, 'Hello');
      expect(s.type, PdfObjectType.string);
    });
    
    test('PdfName', () {
      final n = PdfName('Type');
      expect(n.name, 'Type');
      expect(n.type, PdfObjectType.name);
    });
    
    test('PdfNull', () {
      final n = PdfNull();
      expect(n.type, PdfObjectType.nullObj);
      expect(n, PdfNull()); // Singleton
    });
    
    test('PdfArray', () {
      final arr = PdfArray();
      arr.addInt(1);
      arr.addInt(2);
      arr.addInt(3);
      
      expect(arr.length, 3);
      expect(arr.getIntAt(0), 1);
      expect(arr.getIntAt(2), 3);
    });
    
    test('PdfDictionary', () {
      final dict = PdfDictionary();
      dict.setName('Type', 'Page');
      dict.setInt('Width', 612);
      dict.setInt('Height', 792);
      
      expect(dict.getName('Type'), 'Page');
      expect(dict.getInt('Width'), 612);
      expect(dict.has('Height'), true);
      expect(dict.has('Missing'), false);
    });
    
    test('PdfReference', () {
      final ref = PdfReference(10, 0);
      expect(ref.refObjNum, 10);
      expect(ref.refGenNum, 0);
      expect(ref.type, PdfObjectType.reference);
    });
  });
  
  group('PDF Parser', () {
    test('Parse number', () {
      final parser = PdfSyntaxParser.fromBytes(
        Uint8List.fromList('42'.codeUnits),
      );
      final num = parser.readNumber();
      expect(num?.intValue, 42);
    });
    
    test('Parse real number', () {
      final parser = PdfSyntaxParser.fromBytes(
        Uint8List.fromList('3.14159'.codeUnits),
      );
      final num = parser.readNumber();
      expect(num?.numberValue, closeTo(3.14159, 0.0001));
    });
    
    test('Parse name', () {
      final parser = PdfSyntaxParser.fromBytes(
        Uint8List.fromList('/Type'.codeUnits),
      );
      final name = parser.readName();
      expect(name?.name, 'Type');
    });
    
    test('Parse literal string', () {
      final parser = PdfSyntaxParser.fromBytes(
        Uint8List.fromList('(Hello World)'.codeUnits),
      );
      final str = parser.readLiteralString();
      expect(str?.text, 'Hello World');
    });
    
    test('Parse hex string', () {
      final parser = PdfSyntaxParser.fromBytes(
        Uint8List.fromList('<48656C6C6F>'.codeUnits),
      );
      final str = parser.readHexString();
      expect(str?.text, 'Hello');
    });
    
    test('Parse array', () {
      final parser = PdfSyntaxParser.fromBytes(
        Uint8List.fromList('[1 2 3]'.codeUnits),
      );
      final arr = parser.readArray();
      expect(arr?.length, 3);
      expect(arr?.getIntAt(0), 1);
      expect(arr?.getIntAt(2), 3);
    });
    
    test('Parse dictionary', () {
      final parser = PdfSyntaxParser.fromBytes(
        Uint8List.fromList('<< /Type /Page /Width 612 >>'.codeUnits),
      );
      final dict = parser.readDictionary();
      expect(dict?.getName('Type'), 'Page');
      expect(dict?.getInt('Width'), 612);
    });
    
    test('Parse reference', () {
      final parser = PdfSyntaxParser.fromBytes(
        Uint8List.fromList('10 0 R'.codeUnits),
      );
      final obj = parser.readObject();
      expect(obj, isA<PdfReference>());
      expect((obj as PdfReference).refObjNum, 10);
    });
  });
  
  group('FxDIBitmap', () {
    test('Create bitmap', () {
      final bmp = FxDIBitmap(100, 100, BitmapFormat.bgra);
      expect(bmp.width, 100);
      expect(bmp.height, 100);
      expect(bmp.format, BitmapFormat.bgra);
    });
    
    test('Clear and get/set pixel', () {
      final bmp = FxDIBitmap(10, 10, BitmapFormat.bgra);
      bmp.clear(FxColor.white);
      
      expect(bmp.getPixel(5, 5).value, FxColor.white.value);
      
      bmp.setPixel(5, 5, FxColor.colorRed);
      expect(bmp.getPixel(5, 5).value, FxColor.colorRed.value);
    });
    
    test('Fill rect', () {
      final bmp = FxDIBitmap(100, 100, BitmapFormat.bgra);
      bmp.clear(FxColor.white);
      bmp.fillRect(const FxRectInt(10, 10, 50, 50), FxColor.colorBlue);
      
      expect(bmp.getPixel(25, 25).value, FxColor.colorBlue.value);
      expect(bmp.getPixel(5, 5).value, FxColor.white.value);
    });
    
    test('Convert to RGB bytes', () {
      final bmp = FxDIBitmap(2, 2, BitmapFormat.bgra);
      bmp.setPixel(0, 0, const FxColor.fromRGB(255, 0, 0));
      bmp.setPixel(1, 0, const FxColor.fromRGB(0, 255, 0));
      bmp.setPixel(0, 1, const FxColor.fromRGB(0, 0, 255));
      bmp.setPixel(1, 1, const FxColor.fromRGB(255, 255, 255));
      
      final rgb = bmp.toRgbBytes();
      expect(rgb.length, 12); // 2x2x3 bytes
      expect(rgb[0], 255); // Red
      expect(rgb[1], 0);
      expect(rgb[2], 0);
    });
  });
}
