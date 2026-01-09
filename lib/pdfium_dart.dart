/// PDFium Dart - High-performance PDF rendering library
/// 
/// A pure Dart port of the PDFium library for PDF parsing and rendering.
/// 
/// ## Features
/// - Parse and load PDF documents from files or memory
/// - Render PDF pages to bitmap images
/// - Extract text content from pages
/// - Access document metadata and structure
/// 
/// ## Usage
/// ```dart
/// import 'package:pdfium_dart/pdfium_dart.dart';
/// 
/// void main() async {
///   // Initialize the library
///   PdfiumLibrary.init();
///   
///   // Load a document
///   final doc = await PdfDocument.fromFile('document.pdf');
///   
///   // Get page count
///   print('Pages: ${doc.pageCount}');
///   
///   // Render first page
///   final page = doc.getPage(0);
///   final bitmap = page.render(width: 800, height: 600);
///   
///   // Clean up
///   page.close();
///   doc.close();
///   PdfiumLibrary.destroy();
/// }
/// ```
library pdfium_dart;

// Core runtime types
export 'src/pdfium/fxcrt/fx_types.dart' hide AnnotationSubtype;
export 'src/pdfium/fxcrt/fx_coordinates.dart';
export 'src/pdfium/fxcrt/fx_string.dart';
export 'src/pdfium/fxcrt/fx_stream.dart';
export 'src/pdfium/fxcrt/binary_buffer.dart';

// PDF object types
export 'src/pdfium/fpdfapi/parser/pdf_object.dart';
export 'src/pdfium/fpdfapi/parser/pdf_array.dart';
export 'src/pdfium/fpdfapi/parser/pdf_dictionary.dart';
export 'src/pdfium/fpdfapi/parser/pdf_stream.dart';
export 'src/pdfium/fpdfapi/parser/pdf_string.dart';
export 'src/pdfium/fpdfapi/parser/pdf_number.dart';
export 'src/pdfium/fpdfapi/parser/pdf_name.dart';
export 'src/pdfium/fpdfapi/parser/pdf_boolean.dart';
export 'src/pdfium/fpdfapi/parser/pdf_null.dart';
export 'src/pdfium/fpdfapi/parser/pdf_reference.dart';

// PDF parser
export 'src/pdfium/fpdfapi/parser/pdf_syntax_parser.dart';
export 'src/pdfium/fpdfapi/parser/pdf_parser.dart';
export 'src/pdfium/fpdfapi/parser/pdf_document.dart';
export 'src/pdfium/fpdfapi/parser/pdf_cross_ref_table.dart';

// PDF page
export 'src/pdfium/fpdfapi/page/pdf_page.dart';
export 'src/pdfium/fpdfapi/page/pdf_page_object.dart' hide LineCap, LineJoin;
export 'src/pdfium/fpdfapi/page/graphics_state.dart';
export 'src/pdfium/fpdfapi/page/content_stream_parser.dart';
export 'src/pdfium/fpdfapi/page/content_stream_interpreter.dart';
export 'src/pdfium/fpdfapi/page/text_renderer.dart';
export 'src/pdfium/fpdfapi/page/colorspace.dart' hide ColorSpaceType;
export 'src/pdfium/fpdfapi/page/pdf_image.dart';
export 'src/pdfium/fpdfapi/page/pdf_form_xobject.dart';

// PDF fonts
export 'src/pdfium/fpdfapi/font/pdf_font.dart';

// PDF document features
export 'src/pdfium/fpdfdoc/pdf_annotation.dart';
export 'src/pdfium/fpdfdoc/pdf_form.dart';

// Graphics engine
export 'src/pdfium/fxge/fx_dib.dart';

// Cryptography
export 'src/pdfium/fdrm/pdf_crypt.dart';

// Public API
export 'src/pdfium/public/fpdf_view.dart';