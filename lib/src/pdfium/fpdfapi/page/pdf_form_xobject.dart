

/// PDF Form XObjects
/// 
/// Port of core/fpdfapi/page/cpdf_form.h

import 'dart:typed_data';

import '../../fxcrt/fx_coordinates.dart';
import '../parser/pdf_array.dart';
import '../parser/pdf_boolean.dart';
import '../parser/pdf_dictionary.dart';
import '../parser/pdf_stream.dart';
import 'content_stream_parser.dart';

/// PDF Form XObject
/// 
/// Form XObjects are self-contained graphic content that can be 
/// referenced multiple times in a document.
/// 
/// Equivalent to CPDF_Form in PDFium
class PdfFormXObject {
  final PdfStream _stream;
  final PdfDictionary _dict;
  final PdfDictionary? _resources;
  final PdfDictionary? _parentResources;
  
  FxRect? _bBox;
  FxMatrix _matrix = const FxMatrix.identity();
  List<ContentOperation>? _operations;
  
  /// Create from stream
  PdfFormXObject(
    this._stream, {
    PdfDictionary? parentResources,
  }) : _dict = _stream.dict,
       _resources = _stream.dict.getDict('Resources'),
       _parentResources = parentResources {
    _parseBBox();
    _parseMatrix();
  }
  
  void _parseBBox() {
    final bbox = _dict.getArray('BBox');
    if (bbox != null && bbox.length >= 4) {
      _bBox = FxRect(
        bbox.getNumberAt(0),
        bbox.getNumberAt(1),
        bbox.getNumberAt(2),
        bbox.getNumberAt(3),
      );
    }
  }
  
  void _parseMatrix() {
    final matrixArray = _dict.getArray('Matrix');
    if (matrixArray != null && matrixArray.length >= 6) {
      _matrix = FxMatrix(
        matrixArray.getNumberAt(0),
        matrixArray.getNumberAt(1),
        matrixArray.getNumberAt(2),
        matrixArray.getNumberAt(3),
        matrixArray.getNumberAt(4),
        matrixArray.getNumberAt(5),
      );
    }
  }
  
  /// Stream dictionary
  PdfDictionary get dict => _dict;
  
  /// Form resources
  PdfDictionary? get resources => _resources;
  
  /// Effective resources (form or parent)
  PdfDictionary? get effectiveResources => _resources ?? _parentResources;
  
  /// Bounding box
  FxRect? get bBox => _bBox;
  
  /// Form matrix
  FxMatrix get matrix => _matrix;
  
  /// Group attributes (for transparency)
  PdfDictionary? get group => _dict.getDict('Group');
  
  /// Is this a transparency group?
  bool get isTransparencyGroup {
    final g = group;
    if (g == null) return false;
    return g.getName('S') == 'Transparency';
  }
  
  /// Soft mask reference
  PdfStream? get softMask => _dict.getStream('SMask');
  
  /// Form stream data
  Uint8List get data => _stream.decodedData;
  
  /// Parse content operations
  List<ContentOperation> parseContent() {
    if (_operations != null) return _operations!;
    
    final parser = ContentStreamParser(data, effectiveResources);
    _operations = parser.parseAll();
    return _operations!;
  }
  
  /// Execute the form with the given interpreter callback
  void execute(void Function(ContentOperation op) handler) {
    final ops = parseContent();
    for (final op in ops) {
      handler(op);
    }
  }
  
  /// Calculate bounding box of actual content
  FxRect? calcContentBBox() {
    // Would need to actually parse and render content to calculate this
    // For now, return the declared BBox
    return _bBox;
  }
  
  /// Get form dimensions
  FxSize get size {
    if (_bBox != null) {
      return FxSize(_bBox!.width, _bBox!.height);
    }
    return const FxSize(0, 0);
  }
  
  @override
  String toString() => 'PdfFormXObject(${size.width}x${size.height})';
}

/// Pattern types
enum PatternType {
  tiling(1),
  shading(2);
  
  const PatternType(this.value);
  final int value;
}

/// Tiling types
enum TilingType {
  constantSpacing(1),
  noDistortion(2),
  constantSpacingFaster(3);
  
  const TilingType(this.value);
  final int value;
}

/// PDF Pattern
/// 
/// Equivalent to CPDF_Pattern in PDFium
abstract class PdfPattern {
  PatternType get type;
  FxMatrix get matrix;
}

/// Tiling Pattern
/// 
/// A tiling pattern consists of a small graphical figure 
/// (called a pattern cell) that is replicated at fixed horizontal 
/// and vertical intervals to fill the area to be painted.
class PdfTilingPattern extends PdfPattern {
  final PdfStream _stream;
  final PdfDictionary _dict;
  final int paintType;
  final TilingType tilingType;
  final FxRect bBox;
  final double xStep;
  final double yStep;
  final FxMatrix _matrix;
  final PdfDictionary? resources;
  
  PdfTilingPattern({
    required PdfStream stream,
    required this.paintType,
    required this.tilingType,
    required this.bBox,
    required this.xStep,
    required this.yStep,
    required FxMatrix matrix,
    this.resources,
  }) : _stream = stream,
       _dict = stream.dict,
       _matrix = matrix;
  
  factory PdfTilingPattern.fromStream(PdfStream stream) {
    final dict = stream.dict;
    
    final paintType = dict.getInt('PaintType', 1);
    final tilingTypeValue = dict.getInt('TilingType', 1);
    final tilingType = TilingType.values.firstWhere(
      (t) => t.value == tilingTypeValue,
      orElse: () => TilingType.constantSpacing,
    );
    
    final bboxArray = dict.getArray('BBox');
    final bBox = bboxArray?.toRect() ?? const FxRect(0, 0, 1, 1);
    
    final xStep = dict.getNumber('XStep', 1);
    final yStep = dict.getNumber('YStep', 1);
    
    final matrixArray = dict.getArray('Matrix');
    final matrix = matrixArray?.toMatrix() ?? const FxMatrix.identity();
    
    final resources = dict.getDict('Resources');
    
    return PdfTilingPattern(
      stream: stream,
      paintType: paintType,
      tilingType: tilingType,
      bBox: bBox,
      xStep: xStep,
      yStep: yStep,
      matrix: matrix,
      resources: resources,
    );
  }
  
  @override
  PatternType get type => PatternType.tiling;
  
  @override
  FxMatrix get matrix => _matrix;
  
  /// Is this a colored pattern?
  bool get isColored => paintType == 1;
  
  /// Is this an uncolored pattern?
  bool get isUncolored => paintType == 2;
  
  /// Get pattern cell content
  Uint8List get data => _stream.decodedData;
  
  /// Create form XObject from pattern cell
  PdfFormXObject toFormXObject() {
    return PdfFormXObject(_stream);
  }
  
  @override
  String toString() => 'PdfTilingPattern(${bBox.width}x${bBox.height}, step: $xStep,$yStep)';
}

/// Shading types
enum ShadingType {
  functionBased(1),
  axial(2),
  radial(3),
  freeFormGouraud(4),
  latticeFormGouraud(5),
  coonsPatch(6),
  tensorProduct(7);
  
  const ShadingType(this.value);
  final int value;
  
  static ShadingType? fromValue(int value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// PDF Shading Pattern
/// 
/// Provides continuous color gradients
class PdfShadingPattern extends PdfPattern {
  final PdfDictionary shading;
  final FxMatrix _matrix;
  final ShadingType shadingType;
  
  PdfShadingPattern({
    required this.shading,
    required FxMatrix matrix,
    required this.shadingType,
  }) : _matrix = matrix;
  
  factory PdfShadingPattern.fromDict(PdfDictionary dict) {
    final shadingObj = dict.get('Shading');
    PdfDictionary shadingDict;
    
    if (shadingObj is PdfStream) {
      shadingDict = shadingObj.dict;
    } else if (shadingObj is PdfDictionary) {
      shadingDict = shadingObj;
    } else {
      shadingDict = PdfDictionary();
    }
    
    final typeValue = shadingDict.getInt('ShadingType', 1);
    final shadingType = ShadingType.fromValue(typeValue) ?? ShadingType.functionBased;
    
    final matrixArray = dict.getArray('Matrix');
    final matrix = matrixArray?.toMatrix() ?? const FxMatrix.identity();
    
    return PdfShadingPattern(
      shading: shadingDict,
      matrix: matrix,
      shadingType: shadingType,
    );
  }
  
  @override
  PatternType get type => PatternType.shading;
  
  @override
  FxMatrix get matrix => _matrix;
  
  /// Color space for shading
  String? get colorSpaceName => shading.getName('ColorSpace');
  
  /// Background color
  PdfArray? get background => shading.getArray('Background');
  
  /// Bounding box
  FxRect? get bBox => shading.getArray('BBox')?.toRect();
  
  /// Is antialiasing enabled
  bool get antiAlias => shading.getBool('AntiAlias', false);
  
  @override
  String toString() => 'PdfShadingPattern($shadingType)';
}

/// Axial (linear) shading data
class AxialShadingData {
  final FxPoint start;
  final FxPoint end;
  final bool extendStart;
  final bool extendEnd;
  // Function would go here
  
  AxialShadingData({
    required this.start,
    required this.end,
    this.extendStart = false,
    this.extendEnd = false,
  });
  
  factory AxialShadingData.fromShading(PdfDictionary shading) {
    final coords = shading.getArray('Coords');
    FxPoint start = const FxPoint(0, 0);
    FxPoint end = const FxPoint(1, 0);
    
    if (coords != null && coords.length >= 4) {
      start = FxPoint(coords.getNumberAt(0), coords.getNumberAt(1));
      end = FxPoint(coords.getNumberAt(2), coords.getNumberAt(3));
    }
    
    final extend = shading.getArray('Extend');
    bool extendStart = false;
    bool extendEnd = false;
    
    if (extend != null && extend.length >= 2) {
      final startObj = extend.getAt(0);
      final endObj = extend.getAt(1);
      if (startObj is PdfBoolean) extendStart = startObj.value;
      if (endObj is PdfBoolean) extendEnd = endObj.value;
    }
    
    return AxialShadingData(
      start: start,
      end: end,
      extendStart: extendStart,
      extendEnd: extendEnd,
    );
  }
}

/// Radial shading data
class RadialShadingData {
  final FxPoint start;
  final double startRadius;
  final FxPoint end;
  final double endRadius;
  final bool extendStart;
  final bool extendEnd;
  
  RadialShadingData({
    required this.start,
    required this.startRadius,
    required this.end,
    required this.endRadius,
    this.extendStart = false,
    this.extendEnd = false,
  });
  
  factory RadialShadingData.fromShading(PdfDictionary shading) {
    final coords = shading.getArray('Coords');
    FxPoint start = const FxPoint(0, 0);
    double startRadius = 0;
    FxPoint end = const FxPoint(1, 1);
    double endRadius = 1;
    
    if (coords != null && coords.length >= 6) {
      start = FxPoint(coords.getNumberAt(0), coords.getNumberAt(1));
      startRadius = coords.getNumberAt(2);
      end = FxPoint(coords.getNumberAt(3), coords.getNumberAt(4));
      endRadius = coords.getNumberAt(5);
    }
    
    final extend = shading.getArray('Extend');
    bool extendStart = false;
    bool extendEnd = false;
    
    if (extend != null && extend.length >= 2) {
      final startObj = extend.getAt(0);
      final endObj = extend.getAt(1);
      if (startObj is PdfBoolean) extendStart = startObj.value;
      if (endObj is PdfBoolean) extendEnd = endObj.value;
    }
    
    return RadialShadingData(
      start: start,
      startRadius: startRadius,
      end: end,
      endRadius: endRadius,
      extendStart: extendStart,
      extendEnd: extendEnd,
    );
  }
}
