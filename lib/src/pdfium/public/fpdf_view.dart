/// PDFium Public API
/// 
/// Port of public/fpdfview.h

import 'dart:typed_data';

import '../fpdfapi/page/pdf_page.dart';
import '../fpdfapi/page/content_stream_interpreter.dart';
import '../fpdfapi/parser/pdf_document.dart';
import '../fxcrt/fx_types.dart';
import '../fxcrt/fx_coordinates.dart';
import '../fxge/fx_dib.dart';

/// PDFium Library initialization and management
class PdfiumLibrary {
  static bool _initialized = false;
  
  /// Initialize the PDFium library
  /// 
  /// Must be called before any other PDFium function
  static void init() {
    if (_initialized) return;
    _initialized = true;
    // Initialization code here
  }
  
  /// Destroy the PDFium library and release resources
  static void destroy() {
    if (!_initialized) return;
    _initialized = false;
    // Cleanup code here
  }
  
  /// Check if library is initialized
  static bool get isInitialized => _initialized;
}

/// Render flags for page rendering
class RenderFlags {
  final int value;
  
  const RenderFlags._(this.value);
  
  /// No special rendering flags
  static const none = RenderFlags._(0);
  
  /// Set if annotations are to be rendered
  static const annotations = RenderFlags._(0x01);
  
  /// Set if using text rendering optimized for LCD display
  static const lcdText = RenderFlags._(0x02);
  
  /// Don't use native text rendering
  static const noNativeText = RenderFlags._(0x04);
  
  /// Grayscale output
  static const grayscale = RenderFlags._(0x08);
  
  /// Limit image cache size
  static const limitImageCache = RenderFlags._(0x200);
  
  /// Always use halftone for image stretching
  static const forceHalftone = RenderFlags._(0x400);
  
  /// Render for printing
  static const printing = RenderFlags._(0x800);
  
  /// Disable anti-aliasing on text
  static const noSmoothText = RenderFlags._(0x1000);
  
  /// Disable anti-aliasing on images
  static const noSmoothImage = RenderFlags._(0x2000);
  
  /// Disable anti-aliasing on paths
  static const noSmoothPath = RenderFlags._(0x4000);
  
  /// Combine flags
  RenderFlags operator |(RenderFlags other) => RenderFlags._(value | other.value);
  
  /// Check if flag is set
  bool has(RenderFlags flag) => (value & flag.value) != 0;
}

/// High-level PDF rendering functions
class PdfRenderer {
  final PdfDocument _document;
  
  PdfRenderer(this._document);
  
  /// Render a page to a bitmap
  /// 
  /// [pageIndex] - 0-based page index
  /// [width] - target bitmap width
  /// [height] - target bitmap height
  /// [rotation] - rotation to apply
  /// [flags] - rendering flags
  /// [backgroundColor] - background color (default white)
  FxDIBitmap? renderPage(
    int pageIndex, {
    required int width,
    required int height,
    PageRotation rotation = PageRotation.none,
    RenderFlags flags = RenderFlags.none,
    FxColor backgroundColor = FxColor.white,
  }) {
    final page = _document.getPage(pageIndex);
    if (page == null) return null;
    
    // Create bitmap
    final format = flags.has(RenderFlags.grayscale) 
        ? BitmapFormat.gray 
        : BitmapFormat.bgra;
    
    final bitmap = FxDIBitmap(width, height, format);
    bitmap.clear(backgroundColor);
    
    // Render using content stream interpreter
    final interpreter = ContentStreamInterpreter(page, bitmap, page.resources);
    interpreter.render();
    
    return bitmap;
  }
  
  /// Render a page to RGB bytes
  Uint8List? renderPageToRgb(
    int pageIndex, {
    required int width,
    required int height,
    PageRotation rotation = PageRotation.none,
    RenderFlags flags = RenderFlags.none,
    FxColor backgroundColor = FxColor.white,
  }) {
    final bitmap = renderPage(
      pageIndex,
      width: width,
      height: height,
      rotation: rotation,
      flags: flags,
      backgroundColor: backgroundColor,
    );
    
    return bitmap?.toRgbBytes();
  }
  
  /// Render a page to RGBA bytes
  Uint8List? renderPageToRgba(
    int pageIndex, {
    required int width,
    required int height,
    PageRotation rotation = PageRotation.none,
    RenderFlags flags = RenderFlags.none,
    FxColor backgroundColor = FxColor.white,
  }) {
    final bitmap = renderPage(
      pageIndex,
      width: width,
      height: height,
      rotation: rotation,
      flags: flags,
      backgroundColor: backgroundColor,
    );
    
    return bitmap?.toRgbaBytes();
  }
}

/// Extension methods for PdfDocument
extension PdfDocumentRendering on PdfDocument {
  /// Create a renderer for this document
  PdfRenderer get renderer => PdfRenderer(this);
  
  /// Render a page to bitmap
  FxDIBitmap? renderPage(
    int pageIndex, {
    required int width,
    required int height,
    PageRotation rotation = PageRotation.none,
    RenderFlags flags = RenderFlags.none,
    FxColor backgroundColor = FxColor.white,
  }) {
    return renderer.renderPage(
      pageIndex,
      width: width,
      height: height,
      rotation: rotation,
      flags: flags,
      backgroundColor: backgroundColor,
    );
  }
}

/// PDF document loading result
class PdfLoadResult {
  final PdfDocument? document;
  final PdfError error;
  
  PdfLoadResult.success(PdfDocument doc) 
      : document = doc, error = PdfError.success;
  
  PdfLoadResult.failure(this.error) : document = null;
  
  bool get isSuccess => error == PdfError.success;
  bool get isFailure => error != PdfError.success;
}

/// Convenience functions for document loading
class Fpdf {
  Fpdf._();
  
  /// Load a PDF document from file
  static Future<PdfLoadResult> loadDocument(String path, {String? password}) async {
    final result = await PdfDocument.fromFile(path, password: password);
    if (result.isSuccess) {
      return PdfLoadResult.success(result.value);
    }
    return PdfLoadResult.failure(result.error);
  }
  
  /// Load a PDF document from memory
  static PdfLoadResult loadMemDocument(Uint8List data, {String? password}) {
    final result = PdfDocument.fromMemory(data, password: password);
    if (result.isSuccess) {
      return PdfLoadResult.success(result.value);
    }
    return PdfLoadResult.failure(result.error);
  }
  
  /// Get number of pages in a document
  static int getPageCount(PdfDocument doc) => doc.pageCount;
  
  /// Get page width
  static double getPageWidth(PdfDocument doc, int pageIndex) {
    return doc.getPage(pageIndex)?.width ?? 0;
  }
  
  /// Get page height
  static double getPageHeight(PdfDocument doc, int pageIndex) {
    return doc.getPage(pageIndex)?.height ?? 0;
  }
  
  /// Close a document
  static void closeDocument(PdfDocument doc) => doc.close();
}
