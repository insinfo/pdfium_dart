/// PDFium Dart Example
/// 
/// Demonstrates basic usage of the PDFium Dart library

import 'dart:io';
import 'package:pdfium_dart/pdfium_dart.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run bin/example.dart <pdf_file>');
    print('');
    print('Example: dart run bin/example.dart document.pdf');
    exit(1);
  }
  
  final pdfPath = args[0];
  
  // Initialize the library
  PdfiumLibrary.init();
  
  try {
    // Load the PDF document
    print('Loading PDF: $pdfPath');
    final result = await Fpdf.loadDocument(pdfPath);
    
    if (result.isFailure) {
      print('Error loading PDF: ${result.error.message}');
      exit(1);
    }
    
    final doc = result.document!;
    
    // Print document info
    print('');
    print('=== Document Information ===');
    print('Version: ${doc.version}');
    print('Pages: ${doc.pageCount}');
    print('Title: ${doc.title ?? "(none)"}');
    print('Author: ${doc.author ?? "(none)"}');
    print('Subject: ${doc.subject ?? "(none)"}');
    print('Creator: ${doc.creator ?? "(none)"}');
    print('Producer: ${doc.producer ?? "(none)"}');
    print('');
    
    // Print page information
    print('=== Page Information ===');
    for (var i = 0; i < doc.pageCount; i++) {
      final page = doc.getPage(i);
      if (page != null) {
        print('Page ${i + 1}:');
        print('  Size: ${page.width.toStringAsFixed(2)} x ${page.height.toStringAsFixed(2)} points');
        print('  Size (inches): ${(page.width / 72).toStringAsFixed(2)} x ${(page.height / 72).toStringAsFixed(2)}');
        print('  Rotation: ${page.rotation.degrees}°');
        print('  MediaBox: ${page.mediaBox}');
        print('  CropBox: ${page.cropBox}');
      }
    }
    print('');
    
    // Render first page (if available)
    if (doc.pageCount > 0) {
      print('=== Rendering First Page ===');
      final page = doc.getPage(0);
      if (page != null) {
        // Calculate render size (fit within 800x600)
        final maxWidth = 800.0;
        final maxHeight = 600.0;
        final scale = (maxWidth / page.width) < (maxHeight / page.height)
            ? maxWidth / page.width
            : maxHeight / page.height;
        
        final renderWidth = (page.width * scale).round();
        final renderHeight = (page.height * scale).round();
        
        print('Rendering at ${renderWidth}x$renderHeight...');
        
        final bitmap = doc.renderPage(
          0,
          width: renderWidth,
          height: renderHeight,
          backgroundColor: FxColor.white,
        );
        
        if (bitmap != null) {
          print('Rendered successfully!');
          print('Bitmap format: ${bitmap.format}');
          print('Bitmap size: ${bitmap.width}x${bitmap.height}');
          print('Buffer size: ${bitmap.bufferSize} bytes');
          
          // Optionally save as raw image data
          // final rgbData = bitmap.toRgbBytes();
          // File('output.rgb').writeAsBytesSync(rgbData);
        }
      }
    }
    
    // Clean up
    doc.close();
    
  } finally {
    // Destroy the library
    PdfiumLibrary.destroy();
  }
  
  print('');
  print('Done!');
}
