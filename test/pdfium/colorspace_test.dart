import 'dart:typed_data';

import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:test/test.dart';

void main() {
  group('ColorSpace', () {
    group('DeviceGray', () {
      test('converts gray to RGB', () {
        final cs = DeviceGrayColorSpace();
        
        expect(cs.componentCount, 1);
        
        // Black
        final black = cs.toRgb([0.0]);
        expect(black.red, 0);
        expect(black.green, 0);
        expect(black.blue, 0);
        
        // White
        final white = cs.toRgb([1.0]);
        expect(white.red, 255);
        expect(white.green, 255);
        expect(white.blue, 255);
        
        // 50% gray
        final gray = cs.toRgb([0.5]);
        expect(gray.red, 128);
        expect(gray.green, 128);
        expect(gray.blue, 128);
      });
      
      test('clamps values', () {
        final cs = DeviceGrayColorSpace();
        
        final overWhite = cs.toRgb([1.5]);
        expect(overWhite.red, 255);
        
        final underBlack = cs.toRgb([-0.5]);
        expect(underBlack.red, 0);
      });
    });
    
    group('DeviceRGB', () {
      test('converts RGB correctly', () {
        final cs = DeviceRGBColorSpace();
        
        expect(cs.componentCount, 3);
        
        // Pure red
        final red = cs.toRgb([1.0, 0.0, 0.0]);
        expect(red.red, 255);
        expect(red.green, 0);
        expect(red.blue, 0);
        
        // Pure green
        final green = cs.toRgb([0.0, 1.0, 0.0]);
        expect(green.red, 0);
        expect(green.green, 255);
        expect(green.blue, 0);
        
        // Pure blue
        final blue = cs.toRgb([0.0, 0.0, 1.0]);
        expect(blue.red, 0);
        expect(blue.green, 0);
        expect(blue.blue, 255);
        
        // Mixed
        final mixed = cs.toRgb([0.5, 0.25, 0.75]);
        expect(mixed.red, 128);
        expect(mixed.green, 64);
        expect(mixed.blue, 191);
      });
    });
    
    group('DeviceCMYK', () {
      test('converts CMYK to RGB', () {
        final cs = DeviceCMYKColorSpace();
        
        expect(cs.componentCount, 4);
        
        // Cyan = Blue+Green
        final cyan = cs.toRgb([1.0, 0.0, 0.0, 0.0]);
        expect(cyan.red, 0);
        expect(cyan.green, 255);
        expect(cyan.blue, 255);
        
        // Magenta = Red+Blue
        final magenta = cs.toRgb([0.0, 1.0, 0.0, 0.0]);
        expect(magenta.red, 255);
        expect(magenta.green, 0);
        expect(magenta.blue, 255);
        
        // Yellow = Red+Green
        final yellow = cs.toRgb([0.0, 0.0, 1.0, 0.0]);
        expect(yellow.red, 255);
        expect(yellow.green, 255);
        expect(yellow.blue, 0);
        
        // Black (K=1)
        final black = cs.toRgb([0.0, 0.0, 0.0, 1.0]);
        expect(black.red, 0);
        expect(black.green, 0);
        expect(black.blue, 0);
        
        // White (all 0)
        final white = cs.toRgb([0.0, 0.0, 0.0, 0.0]);
        expect(white.red, 255);
        expect(white.green, 255);
        expect(white.blue, 255);
      });
    });
    
    group('fromPdfObject', () {
      test('parses DeviceGray name', () {
        final cs = PdfColorSpace.fromPdfObject(PdfName('DeviceGray'));
        expect(cs, isA<DeviceGrayColorSpace>());
      });
      
      test('parses DeviceRGB name', () {
        final cs = PdfColorSpace.fromPdfObject(PdfName('DeviceRGB'));
        expect(cs, isA<DeviceRGBColorSpace>());
      });
      
      test('parses DeviceCMYK name', () {
        final cs = PdfColorSpace.fromPdfObject(PdfName('DeviceCMYK'));
        expect(cs, isA<DeviceCMYKColorSpace>());
      });
      
      test('parses short names', () {
        expect(PdfColorSpace.fromPdfObject(PdfName('G')), isA<DeviceGrayColorSpace>());
        expect(PdfColorSpace.fromPdfObject(PdfName('RGB')), isA<DeviceRGBColorSpace>());
        expect(PdfColorSpace.fromPdfObject(PdfName('CMYK')), isA<DeviceCMYKColorSpace>());
      });
      
      test('returns null for unknown', () {
        expect(PdfColorSpace.fromPdfObject(PdfName('Unknown')), isNull);
        expect(PdfColorSpace.fromPdfObject(null), isNull);
      });
    });
    
    group('stock instances', () {
      test('provides stock color spaces', () {
        expect(PdfColorSpace.deviceGray, isA<DeviceGrayColorSpace>());
        expect(PdfColorSpace.deviceRGB, isA<DeviceRGBColorSpace>());
        expect(PdfColorSpace.deviceCMYK, isA<DeviceCMYKColorSpace>());
      });
    });
  });
  
  group('ContentStreamParser', () {
    test('parses path operations', () {
      final content = '100 200 m 300 400 l h S';
      final parser = ContentStreamParser(Uint8List.fromList(content.codeUnits));
      final ops = parser.parseAll();
      
      expect(ops.length, 4);
      
      expect(ops[0].operator, ContentOperator.moveTo);
      expect(ops[0].operands.length, 2);
      expect((ops[0].operands[0] as PdfNumber).numberValue, 100);
      expect((ops[0].operands[1] as PdfNumber).numberValue, 200);
      
      expect(ops[1].operator, ContentOperator.lineTo);
      expect(ops[2].operator, ContentOperator.closePath);
      expect(ops[3].operator, ContentOperator.stroke);
    });
    
    test('parses color operations', () {
      final content = '1 0 0 RG 0.5 g';
      final parser = ContentStreamParser(Uint8List.fromList(content.codeUnits));
      final ops = parser.parseAll();
      
      expect(ops.length, 2);
      
      // RG = set RGB stroke color
      expect(ops[0].operator, ContentOperator.strokeRGB);
      expect(ops[0].operands.length, 3);
      
      // g = set gray fill color
      expect(ops[1].operator, ContentOperator.fillGray);
      expect(ops[1].operands.length, 1);
    });
    
    test('parses text operations', () {
      final content = 'BT /F1 12 Tf 100 700 Td (Hello) Tj ET';
      final parser = ContentStreamParser(Uint8List.fromList(content.codeUnits));
      final ops = parser.parseAll();
      
      expect(ops.length, 5);
      
      expect(ops[0].operator, ContentOperator.beginText);
      expect(ops[1].operator, ContentOperator.font);
      expect(ops[2].operator, ContentOperator.textMove);
      expect(ops[3].operator, ContentOperator.showText);
      expect(ops[4].operator, ContentOperator.endText);
    });
    
    test('parses graphics state operations', () {
      final content = 'q 2 0 0 2 100 200 cm Q';
      final parser = ContentStreamParser(Uint8List.fromList(content.codeUnits));
      final ops = parser.parseAll();
      
      expect(ops.length, 3);
      
      expect(ops[0].operator, ContentOperator.gsave);
      expect(ops[1].operator, ContentOperator.ctm);
      expect(ops[1].operands.length, 6);
      expect(ops[2].operator, ContentOperator.grestore);
    });
    
    test('parses rectangle operation', () {
      final content = '10 20 100 50 re';
      final parser = ContentStreamParser(Uint8List.fromList(content.codeUnits));
      final ops = parser.parseAll();
      
      expect(ops.length, 1);
      expect(ops[0].operator, ContentOperator.rect);
      expect(ops[0].operands.length, 4);
      expect((ops[0].operands[0] as PdfNumber).numberValue, 10);
      expect((ops[0].operands[1] as PdfNumber).numberValue, 20);
      expect((ops[0].operands[2] as PdfNumber).numberValue, 100);
      expect((ops[0].operands[3] as PdfNumber).numberValue, 50);
    });
    
    test('parses fill and stroke operations', () {
      final content = 'f f* B B* b b* n';
      final parser = ContentStreamParser(Uint8List.fromList(content.codeUnits));
      final ops = parser.parseAll();
      
      expect(ops.length, 7);
      expect(ops[0].operator, ContentOperator.fill);
      expect(ops[1].operator, ContentOperator.fillEvenOdd);
      expect(ops[2].operator, ContentOperator.fillStroke);
      expect(ops[3].operator, ContentOperator.fillStrokeEvenOdd);
      expect(ops[4].operator, ContentOperator.closeFillStroke);
      expect(ops[5].operator, ContentOperator.closeFillStrokeEvenOdd);
      expect(ops[6].operator, ContentOperator.endPath);
    });
  });
  
  group('GraphicsState', () {
    test('initializes with defaults', () {
      final state = GraphicsState();
      
      expect(state.ctm.isIdentity, true);
      expect(state.color.fillFxColor, FxColor.black);
      expect(state.color.strokeFxColor, FxColor.black);
      expect(state.line.width, 1.0);
      expect(state.line.cap, LineCap.butt);
      expect(state.line.join, LineJoin.miter);
    });
    
    test('ColorState converts gray', () {
      final colorState = ColorState();
      
      colorState.setFillGray(0.5);
      final gray = colorState.fillFxColor;
      expect(gray.red, 128);
      expect(gray.green, 128);
      expect(gray.blue, 128);
    });
    
    test('ColorState converts RGB', () {
      final colorState = ColorState();
      
      colorState.setFillRGB(1.0, 0.0, 0.0);
      final red = colorState.fillFxColor;
      expect(red.red, 255);
      expect(red.green, 0);
      expect(red.blue, 0);
    });
    
    test('ColorState converts CMYK', () {
      final colorState = ColorState();
      
      colorState.setFillCMYK(1.0, 0.0, 0.0, 0.0); // Cyan
      final cyan = colorState.fillFxColor;
      expect(cyan.red, 0);
      expect(cyan.green, 255);
      expect(cyan.blue, 255);
    });
  });
  
  group('PdfDocument', () {
    test('parses minimal PDF', () {
      final pdfBytes = _createMinimalPdf();
      final result = PdfDocument.fromMemory(pdfBytes);
      
      expect(result.isSuccess, true);
      
      final doc = result.value;
      expect(doc.version, '1.4');
      expect(doc.pageCount, 1);
      
      doc.close();
    });
    
    test('gets page dimensions', () {
      final pdfBytes = _createMinimalPdf();
      final result = PdfDocument.fromMemory(pdfBytes);
      final doc = result.value;
      
      final page = doc.getPage(0);
      expect(page, isNotNull);
      expect(page!.width, 612.0);
      expect(page.height, 792.0);
      
      doc.close();
    });
    
    test('returns null for invalid page index', () {
      final pdfBytes = _createMinimalPdf();
      final result = PdfDocument.fromMemory(pdfBytes);
      final doc = result.value;
      
      expect(doc.getPage(-1), isNull);
      expect(doc.getPage(100), isNull);
      
      doc.close();
    });
    
    test('fails on invalid PDF', () {
      final invalidData = Uint8List.fromList('Not a PDF'.codeUnits);
      final result = PdfDocument.fromMemory(invalidData);
      
      expect(result.isFailure, true);
    });
  });
  
  group('FxMatrix extended', () {
    test('identity matrix', () {
      const m = FxMatrix.identity();
      expect(m.isIdentity, true);
      expect(m.a, 1.0);
      expect(m.b, 0.0);
      expect(m.c, 0.0);
      expect(m.d, 1.0);
      expect(m.e, 0.0);
      expect(m.f, 0.0);
    });
    
    test('translation', () {
      final m = FxMatrix.translate(100, 50);
      final p = m.transformPoint(const FxPoint(0, 0));
      
      expect(p.x, 100);
      expect(p.y, 50);
    });
    
    test('scaling', () {
      final m = FxMatrix.scale(2, 3);
      final p = m.transformPoint(const FxPoint(10, 10));
      
      expect(p.x, 20);
      expect(p.y, 30);
    });
    
    test('inverse', () {
      final m = FxMatrix.translate(100, 200);
      final inv = m.inverse();
      
      expect(inv, isNotNull);
      
      final p = m.transformPoint(const FxPoint(0, 0));
      final pBack = inv!.transformPoint(p);
      
      expect(pBack.x, closeTo(0, 0.0001));
      expect(pBack.y, closeTo(0, 0.0001));
    });
  });
  
  group('FxRect extended', () {
    test('construction methods', () {
      final r1 = const FxRect(0, 0, 100, 100);
      expect(r1.width, 100);
      expect(r1.height, 100);
      
      final r2 = FxRect.fromLTWH(10, 20, 50, 30);
      expect(r2.left, 10);
      expect(r2.top, 20);
      expect(r2.width, 50);
      expect(r2.height, 30);
    });
    
    test('contains point', () {
      final r = const FxRect(0, 0, 100, 100);
      
      expect(r.contains(const FxPoint(50, 50)), true);
      expect(r.contains(const FxPoint(0, 0)), true);
    });
    
    test('union', () {
      final r1 = const FxRect(0, 0, 50, 50);
      final r2 = const FxRect(25, 25, 100, 100);
      
      final union = r1.union(r2);
      expect(union.left, 0);
      expect(union.top, 0);
      expect(union.right, 100);
      expect(union.bottom, 100);
    });
  });
  
  group('PdfiumLibrary', () {
    test('initializes and destroys', () {
      expect(PdfiumLibrary.isInitialized, false);
      
      PdfiumLibrary.init();
      expect(PdfiumLibrary.isInitialized, true);
      
      // Double init is safe
      PdfiumLibrary.init();
      expect(PdfiumLibrary.isInitialized, true);
      
      PdfiumLibrary.destroy();
      expect(PdfiumLibrary.isInitialized, false);
      
      // Double destroy is safe
      PdfiumLibrary.destroy();
      expect(PdfiumLibrary.isInitialized, false);
    });
  });
  
  group('FxDIBitmap advanced', () {
    test('draws line', () {
      final bmp = FxDIBitmap(100, 100, BitmapFormat.bgra);
      bmp.clear(FxColor.white);
      
      bmp.drawLine(0, 0, 99, 99, FxColor.black);
      
      // Check some points on the diagonal
      expect(bmp.getPixel(0, 0).value, FxColor.black.value);
      expect(bmp.getPixel(50, 50).value, FxColor.black.value);
      expect(bmp.getPixel(99, 99).value, FxColor.black.value);
    });
    
    test('converts to RGBA bytes', () {
      final bmp = FxDIBitmap(2, 2, BitmapFormat.bgra);
      bmp.setPixel(0, 0, const FxColor(0x80FF0000)); // Semi-transparent red
      
      final rgba = bmp.toRgbaBytes();
      expect(rgba.length, 16); // 2x2x4 bytes
      expect(rgba[0], 255); // R
      expect(rgba[1], 0);   // G
      expect(rgba[2], 0);   // B
      expect(rgba[3], 128); // A
    });
    
    test('grayscale format', () {
      final bmp = FxDIBitmap(10, 10, BitmapFormat.gray);
      expect(bmp.bytesPerPixel, 1);
      
      bmp.clear(const FxColor.fromRGB(128, 128, 128));
      final pixel = bmp.getPixel(5, 5);
      expect(pixel.red, 128);
    });
  });
  
  group('PdfStream extended', () {
    test('creates and accesses data', () {
      final dict = PdfDictionary();
      dict.setInt('Length', 5);
      
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final stream = PdfStream(dict, data);
      
      expect(stream.length, 5);
      expect(stream.data, data);
      expect(stream.decodedData, data);
    });
    
    test('accesses dictionary properties via dict', () {
      final dict = PdfDictionary();
      dict.setName('Filter', 'FlateDecode');
      dict.setInt('Length', 100);
      
      final stream = PdfStream(dict, Uint8List(100));
      
      // Access via stream's dictionary proxy methods
      expect(stream.dict.getName('Filter'), 'FlateDecode');
      expect(stream.dict.getInt('Length'), 100);
    });
  });
}

/// Create a minimal valid PDF for testing
Uint8List _createMinimalPdf() {
  final buffer = StringBuffer();
  
  // Header
  buffer.writeln('%PDF-1.4');
  buffer.writeln('%âãÏÒ');
  
  // Catalog (object 1)
  final obj1Start = buffer.length;
  buffer.writeln('1 0 obj');
  buffer.writeln('<< /Type /Catalog /Pages 2 0 R >>');
  buffer.writeln('endobj');
  
  // Pages (object 2)
  final obj2Start = buffer.length;
  buffer.writeln('2 0 obj');
  buffer.writeln('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  buffer.writeln('endobj');
  
  // Page (object 3)
  final obj3Start = buffer.length;
  buffer.writeln('3 0 obj');
  buffer.writeln('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>');
  buffer.writeln('endobj');
  
  // Cross-reference table
  final xrefStart = buffer.length;
  buffer.writeln('xref');
  buffer.writeln('0 4');
  buffer.writeln('0000000000 65535 f ');
  buffer.writeln('${obj1Start.toString().padLeft(10, '0')} 00000 n ');
  buffer.writeln('${obj2Start.toString().padLeft(10, '0')} 00000 n ');
  buffer.writeln('${obj3Start.toString().padLeft(10, '0')} 00000 n ');
  
  // Trailer
  buffer.writeln('trailer');
  buffer.writeln('<< /Size 4 /Root 1 0 R >>');
  buffer.writeln('startxref');
  buffer.writeln(xrefStart);
  buffer.writeln('%%EOF');
  
  return Uint8List.fromList(buffer.toString().codeUnits);
}
