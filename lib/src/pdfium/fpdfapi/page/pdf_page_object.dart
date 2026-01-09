/// PDF Page Object
/// 
/// Port of core/fpdfapi/page/cpdf_pageobject.h

import '../../fxcrt/fx_coordinates.dart';
import '../../fxcrt/fx_types.dart';
import '../parser/pdf_dictionary.dart';

/// Types of page objects
enum PageObjectType {
  text,
  path,
  image,
  shading,
  form,
}

/// Base class for page objects
/// 
/// Equivalent to CPDF_PageObject in PDFium
abstract class PdfPageObject {
  /// Object type
  PageObjectType get type;
  
  /// Transformation matrix
  FxMatrix matrix = const FxMatrix.identity();
  
  /// Bounding rectangle
  FxRect get bounds;
  
  /// Check if point is inside this object
  bool containsPoint(FxPoint point) {
    return bounds.contains(point);
  }
}

/// Text object on a page
class PdfTextObject extends PdfPageObject {
  @override
  PageObjectType get type => PageObjectType.text;
  
  /// Text content
  String text = '';
  
  /// Font name
  String fontName = '';
  
  /// Font size
  double fontSize = 12.0;
  
  /// Text position
  FxPoint position = const FxPoint.zero();
  
  /// Character positions
  List<FxPoint> charPositions = [];
  
  /// Fill color (ARGB)
  int fillColor = 0xFF000000;
  
  /// Stroke color (ARGB)
  int strokeColor = 0xFF000000;
  
  /// Text rendering mode
  TextRenderMode renderMode = TextRenderMode.fill;
  
  @override
  FxRect get bounds {
    // Simple bounds calculation
    final width = text.length * fontSize * 0.5; // Approximate
    final height = fontSize;
    return FxRect.fromLTWH(position.x, position.y - height, width, height);
  }
}

/// Path/shape object on a page
class PdfPathObject extends PdfPageObject {
  @override
  PageObjectType get type => PageObjectType.path;
  
  /// Path segments
  List<PathSegment> segments = [];
  
  /// Fill color (ARGB), null for no fill
  int? fillColor;
  
  /// Stroke color (ARGB), null for no stroke
  int? strokeColor;
  
  /// Stroke width
  double strokeWidth = 1.0;
  
  /// Fill rule (true = even-odd, false = non-zero winding)
  bool evenOddFill = false;
  
  /// Line cap style
  LineCap lineCap = LineCap.butt;
  
  /// Line join style
  LineJoin lineJoin = LineJoin.miter;
  
  /// Miter limit
  double miterLimit = 10.0;
  
  /// Dash pattern
  List<double>? dashPattern;
  
  /// Dash phase
  double dashPhase = 0.0;
  
  @override
  FxRect get bounds {
    if (segments.isEmpty) return const FxRect.zero();
    
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    
    for (final segment in segments) {
      for (final point in segment.points) {
        if (point.x < minX) minX = point.x;
        if (point.y < minY) minY = point.y;
        if (point.x > maxX) maxX = point.x;
        if (point.y > maxY) maxY = point.y;
      }
    }
    
    return FxRect(minX, minY, maxX, maxY);
  }
}

/// Path segment types
enum PathSegmentType {
  moveTo,
  lineTo,
  bezierTo,
  close,
}

/// A segment of a path
class PathSegment {
  final PathSegmentType type;
  final List<FxPoint> points;
  
  PathSegment.moveTo(FxPoint point) 
      : type = PathSegmentType.moveTo, 
        points = [point];
  
  PathSegment.lineTo(FxPoint point)
      : type = PathSegmentType.lineTo,
        points = [point];
  
  PathSegment.bezierTo(FxPoint control1, FxPoint control2, FxPoint end)
      : type = PathSegmentType.bezierTo,
        points = [control1, control2, end];
  
  PathSegment.close()
      : type = PathSegmentType.close,
        points = [];
}

/// Line cap styles
enum LineCap {
  butt,
  round,
  square,
}

/// Line join styles
enum LineJoin {
  miter,
  round,
  bevel,
}

/// Image object on a page
class PdfImageObject extends PdfPageObject {
  @override
  PageObjectType get type => PageObjectType.image;
  
  /// Image dictionary
  PdfDictionary? imageDict;
  
  /// Image width
  int width = 0;
  
  /// Image height
  int height = 0;
  
  /// Bits per component
  int bitsPerComponent = 8;
  
  /// Color space name
  String colorSpace = 'DeviceRGB';
  
  @override
  FxRect get bounds {
    // Transform unit square by matrix
    return matrix.transformRect(const FxRect(0, 0, 1, 1));
  }
}

/// Shading object on a page
class PdfShadingObject extends PdfPageObject {
  @override
  PageObjectType get type => PageObjectType.shading;
  
  /// Shading dictionary
  PdfDictionary? shadingDict;
  
  /// Shading type (1-7)
  int shadingType = 1;
  
  @override
  FxRect get bounds {
    // Shading bounds depend on type
    return const FxRect(0, 0, 1, 1);
  }
}

/// Form XObject on a page
class PdfFormObject extends PdfPageObject {
  @override
  PageObjectType get type => PageObjectType.form;
  
  /// Form dictionary
  PdfDictionary? formDict;
  
  /// Nested page objects
  List<PdfPageObject> objects = [];
  
  /// Form bounding box
  FxRect formBBox = const FxRect.zero();
  
  @override
  FxRect get bounds {
    return matrix.transformRect(formBBox);
  }
}
