// PDFium Dart - Example usage
// This example demonstrates how to use the pdfium_dart library
// for parsing and rendering PDF documents.

import 'dart:io';
import 'dart:typed_data';

import 'package:pdfium_dart/pdfium_dart.dart';

void main(List<String> arguments) async {
  // Initialize the library
  PdfiumLibrary.init();
  
  try {
    if (arguments.isEmpty) {
      // Run demo with synthetic PDF
      runDemo();
    } else {
      // Process PDF file from argument
      final pdfPath = arguments[0];
      await processFile(pdfPath);
    }
  } finally {
    // Clean up
    PdfiumLibrary.destroy();
  }
}

/// Run demo with a simple PDF structure
void runDemo() {
  print('=== PDFium Dart Demo ===');
  print('');
  
  // Demonstrate core types
  demoFxTypes();
  
  // Demonstrate PDF parsing
  demoPdfParsing();
  
  // Demonstrate content stream parsing
  demoContentStream();
  
  print('');
  print('=== Demo Complete ===');
}

/// Demonstrate core FX types
void demoFxTypes() {
  print('--- Core Types ---');
  
  // Points
  const p1 = FxPoint(10, 20);
  const p2 = FxPoint(30, 40);
  final dist = p1.distanceTo(p2);
  print('Point distance: $dist');
  
  // Rectangles
  final rect = FxRect.fromLTWH(0, 0, 100, 100);
  print('Rectangle: ${rect.width}x${rect.height}');
  
  // Matrices
  final translate = FxMatrix.translate(10, 20);
  final scale = FxMatrix.scale(2, 2);
  final combined = translate * scale;
  print('Combined matrix: $combined');
  
  // Colors
  const color = FxColor.fromRGB(255, 128, 64);
  print('Color ARGB: ${color.alpha}, ${color.red}, ${color.green}, ${color.blue}');
  
  // Bitmaps
  final bitmap = FxDIBitmap(100, 100, BitmapFormat.bgra);
  bitmap.clear(FxColor.white);
  bitmap.fillRect(const FxRectInt(10, 10, 50, 50), FxColor.colorRed);
  print('Bitmap created: ${bitmap.width}x${bitmap.height}');
  
  print('');
}

/// Demonstrate PDF parsing
void demoPdfParsing() {
  print('--- PDF Parsing ---');
  
  // Create a minimal PDF in memory
  final pdfBytes = _createMinimalPdf();
  print('Created minimal PDF: ${pdfBytes.length} bytes');
  
  // Parse the PDF
  final result = PdfDocument.fromMemory(pdfBytes);
  
  if (result.isSuccess) {
    final doc = result.value;
    print('PDF Version: ${doc.version}');
    print('Page count: ${doc.pageCount}');
    
    // Get page info
    final page = doc.getPage(0);
    if (page != null) {
      print('Page 1 size: ${page.width}x${page.height}');
      print('Page 1 rotation: ${page.rotation}');
    }
    
    doc.close();
  } else {
    print('Failed to parse PDF: ${result.error}');
  }
  
  print('');
}

/// Demonstrate content stream parsing
void demoContentStream() {
  print('--- Content Stream ---');
  
  // Sample content stream (draws a red rectangle)
  const contentStream = '''
q
1 0 0 rg
100 100 200 150 re
f
Q
''';
  
  final parser = ContentStreamParser(
    Uint8List.fromList(contentStream.codeUnits),
  );
  
  final operations = parser.parseAll();
  
  print('Parsed ${operations.length} operations:');
  for (final op in operations) {
    print('  ${op.operator.name}: ${op.operands.length} operands');
  }
  
  print('');
}

/// Process a PDF file
Future<void> processFile(String path) async {
  print('Processing: $path');
  
  // Load document
  final result = await Fpdf.loadDocument(path);
  
  if (result.isFailure) {
    print('Failed to load PDF: ${result.error}');
    return;
  }
  
  final doc = result.document!;
  
  try {
    print('PDF loaded successfully');
    print('Pages: ${doc.pageCount}');
    print('Version: ${doc.version}');
    
    // Get metadata
    final metadata = doc.metadata;
    if (metadata != null) {
      print('Title: ${metadata['Title'] ?? 'N/A'}');
      print('Author: ${metadata['Author'] ?? 'N/A'}');
      print('Subject: ${metadata['Subject'] ?? 'N/A'}');
    }
    
    // Process each page
    for (int i = 0; i < doc.pageCount; i++) {
      final page = doc.getPage(i);
      if (page == null) continue;
      
      print('\nPage ${i + 1}:');
      print('  Size: ${page.width.toStringAsFixed(2)} x ${page.height.toStringAsFixed(2)}');
      print('  Rotation: ${page.rotation.name}');
      
      // Render page to bitmap
      final bitmap = doc.renderPage(
        i,
        width: 800,
        height: (800 * page.height / page.width).round(),
      );
      
      if (bitmap != null) {
        print('  Rendered to ${bitmap.width}x${bitmap.height} bitmap');
        
        // Save as raw RGB (could convert to PNG with image package)
        final outPath = '${path}_page${i + 1}.rgb';
        final rgbBytes = bitmap.toRgbBytes();
        await File(outPath).writeAsBytes(rgbBytes);
        print('  Saved to $outPath');
      }
    }
  } finally {
    doc.close();
  }
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
  buffer.writeln('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>');
  buffer.writeln('endobj');
  
  // Content stream (object 4)
  const content = 'BT /F1 12 Tf 100 700 Td (Hello, PDFium Dart!) Tj ET';
  final obj4Start = buffer.length;
  buffer.writeln('4 0 obj');
  buffer.writeln('<< /Length ${content.length} >>');
  buffer.writeln('stream');
  buffer.write(content);
  buffer.writeln();
  buffer.writeln('endstream');
  buffer.writeln('endobj');
  
  // Cross-reference table
  final xrefStart = buffer.length;
  buffer.writeln('xref');
  buffer.writeln('0 5');
  buffer.writeln('0000000000 65535 f ');
  buffer.writeln('${obj1Start.toString().padLeft(10, '0')} 00000 n ');
  buffer.writeln('${obj2Start.toString().padLeft(10, '0')} 00000 n ');
  buffer.writeln('${obj3Start.toString().padLeft(10, '0')} 00000 n ');
  buffer.writeln('${obj4Start.toString().padLeft(10, '0')} 00000 n ');
  
  // Trailer
  buffer.writeln('trailer');
  buffer.writeln('<< /Size 5 /Root 1 0 R >>');
  buffer.writeln('startxref');
  buffer.writeln(xrefStart);
  buffer.writeln('%%EOF');
  
  return Uint8List.fromList(buffer.toString().codeUnits);
}
