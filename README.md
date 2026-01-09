# PDFium Dart

A pure Dart port of the PDFium library for PDF parsing and rendering.

## Features

- 📄 Parse and load PDF documents from files or memory
- 🖼️ Render PDF pages to bitmap images
- 📝 Extract text content from pages
- 📊 Access document metadata and structure
- 🎨 Full color space support (RGB, CMYK, Lab, ICC, etc.)
- 🖌️ Pattern and shading support
- 📐 Form XObjects and transparency groups
- 🔤 Font rendering (Type1, TrueType, CID)

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  pdfium_dart:
    git:
      url: https://github.com/your-username/pdfium_dart.git
```

Or for local development:

```yaml
dependencies:
  pdfium_dart:
    path: ../pdfium_dart
```

## Quick Start

### Initialize the Library

```dart
import 'package:pdfium_dart/pdfium_dart.dart';

void main() {
  // Initialize PDFium (call once at app start)
  PdfiumLibrary.init();
  
  try {
    // Your PDF operations here
  } finally {
    // Clean up when done
    PdfiumLibrary.destroy();
  }
}
```

### Load a PDF Document

```dart
// From file
final result = await Fpdf.loadDocument('path/to/document.pdf');

if (result.isSuccess) {
  final doc = result.document!;
  print('Pages: ${doc.pageCount}');
  
  // Don't forget to close when done
  doc.close();
} else {
  print('Error: ${result.error}');
}

// From memory
final bytes = File('document.pdf').readAsBytesSync();
final memResult = PdfDocument.fromMemory(bytes);

if (memResult.isSuccess) {
  final doc = memResult.value;
  // Use the document...
  doc.close();
}
```

### Access Document Metadata

```dart
final doc = result.document!;

print('Title: ${doc.title}');
print('Author: ${doc.author}');
print('Subject: ${doc.subject}');
print('Creator: ${doc.creator}');
print('Producer: ${doc.producer}');
print('Creation Date: ${doc.creationDate}');

// Or get all metadata at once
final metadata = doc.metadata;
if (metadata != null) {
  metadata.forEach((key, value) => print('$key: $value'));
}
```

### Get Page Information

```dart
for (int i = 0; i < doc.pageCount; i++) {
  final page = doc.getPage(i);
  if (page != null) {
    print('Page ${i + 1}:');
    print('  Size: ${page.width} x ${page.height}');
    print('  Rotation: ${page.rotation.name}');
    print('  Media Box: ${page.mediaBox}');
    print('  Crop Box: ${page.cropBox ?? page.mediaBox}');
  }
}
```

### Render a Page to Bitmap

```dart
final doc = result.document!;

// Render page 0 to a bitmap
final bitmap = doc.renderPage(
  0, // page index (0-based)
  width: 800,
  height: 1000,
  backgroundColor: FxColor.white,
  flags: RenderFlags.annotations,
);

if (bitmap != null) {
  print('Rendered: ${bitmap.width}x${bitmap.height}');
  
  // Get raw RGB bytes
  final rgbBytes = bitmap.toRgbBytes();
  
  // Get raw RGBA bytes
  final rgbaBytes = bitmap.toRgbaBytes();
  
  // Save to file (raw RGB data)
  File('page0.rgb').writeAsBytesSync(rgbBytes);
}
```

### Working with Colors

```dart
// Create colors
const red = FxColor.fromRGB(255, 0, 0);
const green = FxColor(0xFF00FF00); // ARGB
const blue = FxColor.fromRGBA(0, 0, 255, 255);

// Predefined colors
final white = FxColor.white;
final black = FxColor.black;
final transparent = FxColor.transparent;

// Access components
print('R: ${red.red}, G: ${red.green}, B: ${red.blue}, A: ${red.alpha}');
```

### Working with Bitmaps

```dart
// Create a new bitmap
final bitmap = FxDIBitmap(800, 600, BitmapFormat.bgra);

// Clear to white
bitmap.clear(FxColor.white);

// Fill a rectangle
bitmap.fillRect(
  const FxRectInt(10, 10, 100, 100),
  const FxColor.fromRGB(255, 0, 0),
);

// Draw a line
bitmap.drawLine(0, 0, 800, 600, FxColor.black);

// Get pixel
final color = bitmap.getPixel(50, 50);

// Set pixel
bitmap.setPixel(100, 100, FxColor.blue);
```

### Parse PDF Content Streams

```dart
// Parse a content stream
final contentBytes = Uint8List.fromList(contentString.codeUnits);
final parser = ContentStreamParser(contentBytes);
final operations = parser.parseAll();

for (final op in operations) {
  print('${op.operator.name}: ${op.operands.length} operands');
}
```

### Working with Transforms

```dart
// Identity matrix
const identity = FxMatrix.identity();

// Translation
final translate = FxMatrix.translate(100, 200);

// Scaling
final scale = FxMatrix.scale(2.0, 2.0);

// Rotation (degrees)
final rotate = FxMatrix.rotateAt(45, const FxPoint(100, 100));

// Combine transforms
final combined = translate * scale * rotate;

// Transform a point
final point = const FxPoint(50, 50);
final transformed = combined.transformPoint(point);
```

## Architecture

The library is structured following the original PDFium architecture:

```
lib/
├── src/
│   ├── fxcrt/          # Core runtime types (coordinates, streams, etc.)
│   ├── fxge/           # Graphics engine (bitmaps, DIB)
│   ├── fpdfapi/
│   │   ├── parser/     # PDF document parsing
│   │   ├── page/       # Page objects and rendering
│   │   └── font/       # Font handling
│   └── public/         # Public API (fpdf_view.dart)
└── pdfium_dart.dart    # Main library export
```

### Core Components

| Module | Description |
|--------|-------------|
| `FxPoint`, `FxRect`, `FxMatrix` | Geometric primitives |
| `FxColor`, `FxDIBitmap` | Color and bitmap handling |
| `PdfDocument` | PDF document container |
| `PdfPage` | PDF page representation |
| `PdfParser` | PDF file format parser |
| `ContentStreamParser` | Page content stream parser |
| `ContentStreamInterpreter` | Content stream executor |
| `PdfFont` | Font metrics and glyph handling |
| `PdfColorSpace` | Color space conversions |

## Supported PDF Features

### Object Types
- ✅ Boolean, Number, String, Name
- ✅ Array, Dictionary, Stream
- ✅ Indirect references
- ✅ Null

### Document Structure
- ✅ Cross-reference tables
- ✅ Cross-reference streams
- ✅ Linearized PDFs
- ✅ Object streams
- ✅ Document encryption (partial)

### Page Content
- ✅ Path operations (moveto, lineto, curveto, rect, fill, stroke)
- ✅ Text rendering (show string, show array, positioning)
- ✅ Color operations (RGB, CMYK, Gray, Pattern)
- ✅ Graphics state (CTM, line width, line cap, dash pattern)
- ✅ Image XObjects
- ✅ Form XObjects
- ✅ Clipping paths

### Color Spaces
- ✅ DeviceGray, DeviceRGB, DeviceCMYK
- ✅ CalGray, CalRGB, Lab
- ✅ ICCBased
- ✅ Indexed (palette)
- ✅ Separation, DeviceN
- ✅ Pattern

### Fonts
- ✅ Type1, TrueType
- ✅ CIDFont (Type 0, Type 2)
- ✅ Composite fonts
- ✅ Standard 14 fonts
- ✅ Embedded fonts
- ✅ ToUnicode mapping

## Examples

### Full Example: PDF to Image Converter

```dart
import 'dart:io';
import 'package:pdfium_dart/pdfium_dart.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run example.dart <pdf_file>');
    return;
  }
  
  PdfiumLibrary.init();
  
  try {
    final result = await Fpdf.loadDocument(args[0]);
    
    if (result.isFailure) {
      print('Failed to load: ${result.error}');
      return;
    }
    
    final doc = result.document!;
    
    for (int i = 0; i < doc.pageCount; i++) {
      final page = doc.getPage(i);
      if (page == null) continue;
      
      // Calculate output size (300 DPI)
      final dpi = 300;
      final width = (page.width * dpi / 72).round();
      final height = (page.height * dpi / 72).round();
      
      final bitmap = doc.renderPage(
        i,
        width: width,
        height: height,
      );
      
      if (bitmap != null) {
        final outFile = '${args[0]}_page${i + 1}.rgb';
        File(outFile).writeAsBytesSync(bitmap.toRgbBytes());
        print('Saved: $outFile (${bitmap.width}x${bitmap.height})');
      }
    }
    
    doc.close();
  } finally {
    PdfiumLibrary.destroy();
  }
}
```

## Testing

```bash
# Run all tests
dart test

# Run with coverage
dart test --coverage

# Run specific test file
dart test test/pdfium_dart_test.dart
```

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## License

This project is licensed under the same terms as the original PDFium project - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [PDFium](https://pdfium.googlesource.com/pdfium/) - Original C++ implementation
- [Chromium Project](https://www.chromium.org/) - PDFium maintainers
- All contributors to this Dart port

## Roadmap

- [ ] Complete encryption support (AES-256)
- [ ] Annotation support
- [ ] Form filling
- [ ] JavaScript execution
- [ ] PDF/A validation
- [ ] Digital signatures
- [ ] SVG output
- [ ] Web worker support for Flutter Web
