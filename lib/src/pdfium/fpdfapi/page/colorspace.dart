

/// PDF ColorSpace system
/// 
/// Port of core/fpdfapi/page/cpdf_colorspace.h

import 'dart:typed_data';

import '../../fxge/fx_dib.dart';
import '../parser/pdf_array.dart';
import '../parser/pdf_dictionary.dart';
import '../parser/pdf_name.dart';
import '../parser/pdf_object.dart';
import '../parser/pdf_stream.dart';

/// Color space type
enum ColorSpaceType {
  unknown,
  deviceGray,
  deviceRGB,
  deviceCMYK,
  calGray,
  calRGB,
  lab,
  iccBased,
  separation,
  deviceN,
  indexed,
  pattern,
}

/// Base class for PDF color spaces
/// 
/// Equivalent to CPDF_ColorSpace in PDFium
abstract class PdfColorSpace {
  ColorSpaceType get type;
  
  /// Number of color components
  int get componentCount;
  
  /// Convert color components to RGB
  FxColor toRgb(List<double> components);
  
  /// Get default color value
  List<double> getDefaultValue() {
    return List.filled(componentCount, 0.0);
  }
  
  /// Create color space from PDF object
  static PdfColorSpace? fromPdfObject(PdfObject? obj) {
    if (obj == null) return null;
    
    if (obj is PdfName) {
      return _fromName(obj.name);
    }
    
    if (obj is PdfArray) {
      return _fromArray(obj);
    }
    
    return null;
  }
  
  static PdfColorSpace? _fromName(String name) {
    switch (name) {
      case 'DeviceGray':
      case 'G':
        return DeviceGrayColorSpace();
      case 'DeviceRGB':
      case 'RGB':
        return DeviceRGBColorSpace();
      case 'DeviceCMYK':
      case 'CMYK':
        return DeviceCMYKColorSpace();
      case 'Pattern':
        return PatternColorSpace(null);
      default:
        return null;
    }
  }
  
  static PdfColorSpace? _fromArray(PdfArray array) {
    if (array.isEmpty) return null;
    
    final typeObj = array.getAt(0);
    if (typeObj is! PdfName) return null;
    
    final typeName = typeObj.name;
    
    switch (typeName) {
      case 'CalGray':
        return CalGrayColorSpace.fromArray(array);
      case 'CalRGB':
        return CalRGBColorSpace.fromArray(array);
      case 'Lab':
        return LabColorSpace.fromArray(array);
      case 'ICCBased':
        return ICCBasedColorSpace.fromArray(array);
      case 'Indexed':
      case 'I':
        return IndexedColorSpace.fromArray(array);
      case 'Separation':
        return SeparationColorSpace.fromArray(array);
      case 'DeviceN':
        return DeviceNColorSpace.fromArray(array);
      case 'Pattern':
        if (array.length > 1) {
          final baseCS = PdfColorSpace.fromPdfObject(array.getAt(1));
          return PatternColorSpace(baseCS);
        }
        return PatternColorSpace(null);
      default:
        return null;
    }
  }
  
  /// Stock device gray color space
  static final deviceGray = DeviceGrayColorSpace();
  
  /// Stock device RGB color space
  static final deviceRGB = DeviceRGBColorSpace();
  
  /// Stock device CMYK color space
  static final deviceCMYK = DeviceCMYKColorSpace();
}

/// Device Gray color space
class DeviceGrayColorSpace extends PdfColorSpace {
  @override
  ColorSpaceType get type => ColorSpaceType.deviceGray;
  
  @override
  int get componentCount => 1;
  
  @override
  FxColor toRgb(List<double> components) {
    final gray = (components.isNotEmpty ? components[0] : 0.0).clamp(0.0, 1.0);
    final value = (gray * 255).round();
    return FxColor.fromRGB(value, value, value);
  }
}

/// Device RGB color space
class DeviceRGBColorSpace extends PdfColorSpace {
  @override
  ColorSpaceType get type => ColorSpaceType.deviceRGB;
  
  @override
  int get componentCount => 3;
  
  @override
  FxColor toRgb(List<double> components) {
    final r = (components.length > 0 ? components[0] : 0.0).clamp(0.0, 1.0);
    final g = (components.length > 1 ? components[1] : 0.0).clamp(0.0, 1.0);
    final b = (components.length > 2 ? components[2] : 0.0).clamp(0.0, 1.0);
    
    return FxColor.fromRGB(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }
}

/// Device CMYK color space
class DeviceCMYKColorSpace extends PdfColorSpace {
  @override
  ColorSpaceType get type => ColorSpaceType.deviceCMYK;
  
  @override
  int get componentCount => 4;
  
  @override
  FxColor toRgb(List<double> components) {
    final c = (components.length > 0 ? components[0] : 0.0).clamp(0.0, 1.0);
    final m = (components.length > 1 ? components[1] : 0.0).clamp(0.0, 1.0);
    final y = (components.length > 2 ? components[2] : 0.0).clamp(0.0, 1.0);
    final k = (components.length > 3 ? components[3] : 0.0).clamp(0.0, 1.0);
    
    // Simple CMYK to RGB conversion
    final r = (1 - c) * (1 - k);
    final g = (1 - m) * (1 - k);
    final b = (1 - y) * (1 - k);
    
    return FxColor.fromRGB(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }
}

/// CalGray calibrated grayscale color space
class CalGrayColorSpace extends PdfColorSpace {
  final List<double> whitePoint;
  final List<double> blackPoint;
  final double gamma;
  
  CalGrayColorSpace({
    this.whitePoint = const [1.0, 1.0, 1.0],
    this.blackPoint = const [0.0, 0.0, 0.0],
    this.gamma = 1.0,
  });
  
  factory CalGrayColorSpace.fromArray(PdfArray array) {
    if (array.length < 2) return CalGrayColorSpace();
    
    final dict = array.getDictAt(1);
    if (dict == null) return CalGrayColorSpace();
    
    final wp = dict.getArray('WhitePoint');
    final bp = dict.getArray('BlackPoint');
    final gamma = dict.getNumber('Gamma', 1.0);
    
    return CalGrayColorSpace(
      whitePoint: wp != null 
          ? [wp.getNumberAt(0), wp.getNumberAt(1), wp.getNumberAt(2)]
          : [1.0, 1.0, 1.0],
      blackPoint: bp != null
          ? [bp.getNumberAt(0), bp.getNumberAt(1), bp.getNumberAt(2)]
          : [0.0, 0.0, 0.0],
      gamma: gamma,
    );
  }
  
  @override
  ColorSpaceType get type => ColorSpaceType.calGray;
  
  @override
  int get componentCount => 1;
  
  @override
  FxColor toRgb(List<double> components) {
    final a = (components.isNotEmpty ? components[0] : 0.0).clamp(0.0, 1.0);
    final ag = _pow(a, gamma);
    
    // Convert through XYZ
    final x = whitePoint[0] * ag;
    final y = whitePoint[1] * ag;
    final z = whitePoint[2] * ag;
    
    // XYZ to sRGB
    return _xyzToRgb(x, y, z);
  }
  
  double _pow(double base, double exp) {
    if (base <= 0) return 0;
    return _fastPow(base, exp);
  }
  
  double _fastPow(double base, double exp) {
    // Simple power implementation
    if (exp == 1.0) return base;
    if (exp == 2.0) return base * base;
    if (exp == 2.2) {
      // Gamma 2.2 approximation
      return base * base * _sqrt(base);
    }
    // Fallback to dart:math
    return _expLog(base, exp);
  }
  
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 10; i++) {
      r = (r + x / r) / 2;
    }
    return r;
  }
  
  double _expLog(double base, double exp) {
    // Using Taylor series approximation
    if (base <= 0) return 0;
    // ln(base) approximation
    double ln = 0;
    double term = (base - 1) / (base + 1);
    double term2 = term * term;
    double power = term;
    for (int i = 1; i < 20; i += 2) {
      ln += power / i;
      power *= term2;
    }
    ln *= 2;
    
    // exp(ln * exp) approximation
    double result = exp * ln;
    double factorial = 1;
    double expResult = 1;
    double powerN = 1;
    for (int n = 1; n < 20; n++) {
      factorial *= n;
      powerN *= result;
      expResult += powerN / factorial;
    }
    return expResult;
  }
  
  FxColor _xyzToRgb(double x, double y, double z) {
    // sRGB conversion matrix
    var r = 3.2406 * x - 1.5372 * y - 0.4986 * z;
    var g = -0.9689 * x + 1.8758 * y + 0.0415 * z;
    var b = 0.0557 * x - 0.2040 * y + 1.0570 * z;
    
    // Gamma correction
    r = _gammaCorrect(r);
    g = _gammaCorrect(g);
    b = _gammaCorrect(b);
    
    return FxColor.fromRGB(
      (r.clamp(0.0, 1.0) * 255).round(),
      (g.clamp(0.0, 1.0) * 255).round(),
      (b.clamp(0.0, 1.0) * 255).round(),
    );
  }
  
  double _gammaCorrect(double v) {
    if (v <= 0.0031308) {
      return 12.92 * v;
    }
    return 1.055 * _pow(v, 1 / 2.4) - 0.055;
  }
}

/// CalRGB calibrated RGB color space
class CalRGBColorSpace extends PdfColorSpace {
  final List<double> whitePoint;
  final List<double> blackPoint;
  final List<double> gamma;
  final List<double> matrix;
  
  CalRGBColorSpace({
    this.whitePoint = const [1.0, 1.0, 1.0],
    this.blackPoint = const [0.0, 0.0, 0.0],
    this.gamma = const [1.0, 1.0, 1.0],
    this.matrix = const [1, 0, 0, 0, 1, 0, 0, 0, 1],
  });
  
  factory CalRGBColorSpace.fromArray(PdfArray array) {
    if (array.length < 2) return CalRGBColorSpace();
    
    final dict = array.getDictAt(1);
    if (dict == null) return CalRGBColorSpace();
    
    final wp = dict.getArray('WhitePoint');
    final bp = dict.getArray('BlackPoint');
    final g = dict.getArray('Gamma');
    final m = dict.getArray('Matrix');
    
    return CalRGBColorSpace(
      whitePoint: wp != null 
          ? [wp.getNumberAt(0), wp.getNumberAt(1), wp.getNumberAt(2)]
          : [1.0, 1.0, 1.0],
      blackPoint: bp != null
          ? [bp.getNumberAt(0), bp.getNumberAt(1), bp.getNumberAt(2)]
          : [0.0, 0.0, 0.0],
      gamma: g != null
          ? [g.getNumberAt(0), g.getNumberAt(1), g.getNumberAt(2)]
          : [1.0, 1.0, 1.0],
      matrix: m != null && m.length >= 9
          ? List.generate(9, (i) => m.getNumberAt(i))
          : [1, 0, 0, 0, 1, 0, 0, 0, 1],
    );
  }
  
  @override
  ColorSpaceType get type => ColorSpaceType.calRGB;
  
  @override
  int get componentCount => 3;
  
  @override
  FxColor toRgb(List<double> components) {
    final r = (components.length > 0 ? components[0] : 0.0).clamp(0.0, 1.0);
    final g = (components.length > 1 ? components[1] : 0.0).clamp(0.0, 1.0);
    final b = (components.length > 2 ? components[2] : 0.0).clamp(0.0, 1.0);
    
    // Simplified - just return as is for now
    return FxColor.fromRGB(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }
}

/// Lab color space
class LabColorSpace extends PdfColorSpace {
  final List<double> whitePoint;
  final List<double> blackPoint;
  final List<double> range;
  
  LabColorSpace({
    this.whitePoint = const [1.0, 1.0, 1.0],
    this.blackPoint = const [0.0, 0.0, 0.0],
    this.range = const [-100, 100, -100, 100],
  });
  
  factory LabColorSpace.fromArray(PdfArray array) {
    if (array.length < 2) return LabColorSpace();
    
    final dict = array.getDictAt(1);
    if (dict == null) return LabColorSpace();
    
    final wp = dict.getArray('WhitePoint');
    final bp = dict.getArray('BlackPoint');
    final r = dict.getArray('Range');
    
    return LabColorSpace(
      whitePoint: wp != null 
          ? [wp.getNumberAt(0), wp.getNumberAt(1), wp.getNumberAt(2)]
          : [1.0, 1.0, 1.0],
      blackPoint: bp != null
          ? [bp.getNumberAt(0), bp.getNumberAt(1), bp.getNumberAt(2)]
          : [0.0, 0.0, 0.0],
      range: r != null && r.length >= 4
          ? [r.getNumberAt(0), r.getNumberAt(1), r.getNumberAt(2), r.getNumberAt(3)]
          : [-100, 100, -100, 100],
    );
  }
  
  @override
  ColorSpaceType get type => ColorSpaceType.lab;
  
  @override
  int get componentCount => 3;
  
  @override
  FxColor toRgb(List<double> components) {
    // L* is in range [0, 100]
    // a* and b* are in range specified by Range array
    final l = (components.length > 0 ? components[0] : 0.0);
    final a = (components.length > 1 ? components[1] : 0.0);
    final b = (components.length > 2 ? components[2] : 0.0);
    
    // Lab to XYZ
    final fy = (l + 16) / 116;
    final fx = a / 500 + fy;
    final fz = fy - b / 200;
    
    final xr = _fInverse(fx);
    final yr = _fInverse(fy);
    final zr = _fInverse(fz);
    
    final x = xr * whitePoint[0];
    final y = yr * whitePoint[1];
    final z = zr * whitePoint[2];
    
    // XYZ to sRGB
    var rr = 3.2406 * x - 1.5372 * y - 0.4986 * z;
    var gg = -0.9689 * x + 1.8758 * y + 0.0415 * z;
    var bb = 0.0557 * x - 0.2040 * y + 1.0570 * z;
    
    return FxColor.fromRGB(
      (rr.clamp(0.0, 1.0) * 255).round(),
      (gg.clamp(0.0, 1.0) * 255).round(),
      (bb.clamp(0.0, 1.0) * 255).round(),
    );
  }
  
  double _fInverse(double t) {
    const delta = 6.0 / 29.0;
    if (t > delta) {
      return t * t * t;
    }
    return 3 * delta * delta * (t - 4.0 / 29.0);
  }
}

/// ICC-based color space
class ICCBasedColorSpace extends PdfColorSpace {
  final int components;
  final PdfColorSpace? alternate;
  final Uint8List? iccData;
  
  ICCBasedColorSpace({
    required this.components,
    this.alternate,
    this.iccData,
  });
  
  factory ICCBasedColorSpace.fromArray(PdfArray array) {
    if (array.length < 2) {
      return ICCBasedColorSpace(components: 3);
    }
    
    final streamObj = array.getAt(1);
    if (streamObj is! PdfStream) {
      return ICCBasedColorSpace(components: 3);
    }
    
    final dict = streamObj.dict;
    final n = dict.getInt('N', 3);
    
    // Get alternate color space
    final altObj = dict.get('Alternate');
    final alternate = altObj != null ? PdfColorSpace.fromPdfObject(altObj) : null;
    
    // Get ICC profile data
    final iccData = streamObj.decodedData;
    
    return ICCBasedColorSpace(
      components: n,
      alternate: alternate,
      iccData: iccData,
    );
  }
  
  @override
  ColorSpaceType get type => ColorSpaceType.iccBased;
  
  @override
  int get componentCount => components;
  
  @override
  FxColor toRgb(List<double> components) {
    // If we have an alternate, use it
    if (alternate != null) {
      return alternate!.toRgb(components);
    }
    
    // Default based on component count
    switch (this.components) {
      case 1:
        return DeviceGrayColorSpace().toRgb(components);
      case 3:
        return DeviceRGBColorSpace().toRgb(components);
      case 4:
        return DeviceCMYKColorSpace().toRgb(components);
      default:
        return FxColor.black;
    }
  }
}

/// Indexed (palette) color space
class IndexedColorSpace extends PdfColorSpace {
  final PdfColorSpace base;
  final int maxIndex;
  final Uint8List lookupTable;
  
  IndexedColorSpace({
    required this.base,
    required this.maxIndex,
    required this.lookupTable,
  });
  
  factory IndexedColorSpace.fromArray(PdfArray array) {
    if (array.length < 4) {
      return IndexedColorSpace(
        base: DeviceRGBColorSpace(),
        maxIndex: 255,
        lookupTable: Uint8List(0),
      );
    }
    
    final baseCS = PdfColorSpace.fromPdfObject(array.getAt(1)) ?? DeviceRGBColorSpace();
    final hival = array.getIntAt(2);
    
    // Lookup table can be string or stream
    Uint8List lookup;
    final lookupObj = array.getAt(3);
    if (lookupObj is PdfStream) {
      lookup = lookupObj.decodedData;
    } else {
      lookup = Uint8List(0);
    }
    
    return IndexedColorSpace(
      base: baseCS,
      maxIndex: hival,
      lookupTable: lookup,
    );
  }
  
  @override
  ColorSpaceType get type => ColorSpaceType.indexed;
  
  @override
  int get componentCount => 1;
  
  @override
  FxColor toRgb(List<double> components) {
    final index = (components.isNotEmpty ? components[0] : 0.0).round();
    final clampedIndex = index.clamp(0, maxIndex);
    
    // Look up color in table
    final baseComponents = base.componentCount;
    final offset = clampedIndex * baseComponents;
    
    if (offset + baseComponents <= lookupTable.length) {
      final baseComps = <double>[];
      for (int i = 0; i < baseComponents; i++) {
        baseComps.add(lookupTable[offset + i] / 255.0);
      }
      return base.toRgb(baseComps);
    }
    
    return FxColor.black;
  }
}

/// Separation color space
class SeparationColorSpace extends PdfColorSpace {
  final String colorantName;
  final PdfColorSpace alternate;
  final TintTransform? tintTransform;
  
  SeparationColorSpace({
    required this.colorantName,
    required this.alternate,
    this.tintTransform,
  });
  
  factory SeparationColorSpace.fromArray(PdfArray array) {
    if (array.length < 4) {
      return SeparationColorSpace(
        colorantName: 'None',
        alternate: DeviceGrayColorSpace(),
      );
    }
    
    final nameObj = array.getAt(1);
    final colorantName = nameObj is PdfName ? nameObj.name : 'None';
    
    final altCS = PdfColorSpace.fromPdfObject(array.getAt(2)) ?? DeviceGrayColorSpace();
    
    // Tint transform function (simplified)
    // TODO: Implement proper PDF function parsing
    
    return SeparationColorSpace(
      colorantName: colorantName,
      alternate: altCS,
    );
  }
  
  @override
  ColorSpaceType get type => ColorSpaceType.separation;
  
  @override
  int get componentCount => 1;
  
  @override
  FxColor toRgb(List<double> components) {
    final tint = (components.isNotEmpty ? components[0] : 0.0).clamp(0.0, 1.0);
    
    // Special colorant names
    if (colorantName == 'None') {
      return const FxColor.fromARGB(0, 0, 0, 0); // Transparent
    }
    if (colorantName == 'All') {
      final gray = (1 - tint) * 255;
      return FxColor.fromRGB(gray.round(), gray.round(), gray.round());
    }
    
    // Use alternate color space with tint
    // For now, simple grayscale based on tint
    if (tintTransform != null) {
      final altComps = tintTransform!.apply([tint]);
      return alternate.toRgb(altComps);
    }
    
    // Default: use tint as gray value
    final altComps = List<double>.filled(alternate.componentCount, tint);
    return alternate.toRgb(altComps);
  }
}

/// DeviceN color space
class DeviceNColorSpace extends PdfColorSpace {
  final List<String> colorants;
  final PdfColorSpace alternate;
  final TintTransform? tintTransform;
  
  DeviceNColorSpace({
    required this.colorants,
    required this.alternate,
    this.tintTransform,
  });
  
  factory DeviceNColorSpace.fromArray(PdfArray array) {
    if (array.length < 4) {
      return DeviceNColorSpace(
        colorants: [],
        alternate: DeviceGrayColorSpace(),
      );
    }
    
    final namesArray = array.getArrayAt(1);
    final colorants = <String>[];
    if (namesArray != null) {
      for (final obj in namesArray) {
        if (obj is PdfName) {
          colorants.add(obj.name);
        }
      }
    }
    
    final altCS = PdfColorSpace.fromPdfObject(array.getAt(2)) ?? DeviceGrayColorSpace();
    
    return DeviceNColorSpace(
      colorants: colorants,
      alternate: altCS,
    );
  }
  
  @override
  ColorSpaceType get type => ColorSpaceType.deviceN;
  
  @override
  int get componentCount => colorants.length;
  
  @override
  FxColor toRgb(List<double> components) {
    // Use tint transform if available
    if (tintTransform != null) {
      final altComps = tintTransform!.apply(components);
      return alternate.toRgb(altComps);
    }
    
    // Simplified: average of components as gray
    if (components.isEmpty) return FxColor.black;
    
    final avg = components.reduce((a, b) => a + b) / components.length;
    final altComps = List<double>.filled(alternate.componentCount, avg);
    return alternate.toRgb(altComps);
  }
}

/// Pattern color space
class PatternColorSpace extends PdfColorSpace {
  final PdfColorSpace? underlyingColorSpace;
  
  PatternColorSpace(this.underlyingColorSpace);
  
  @override
  ColorSpaceType get type => ColorSpaceType.pattern;
  
  @override
  int get componentCount => underlyingColorSpace?.componentCount ?? 0;
  
  @override
  FxColor toRgb(List<double> components) {
    if (underlyingColorSpace != null) {
      return underlyingColorSpace!.toRgb(components);
    }
    return FxColor.black;
  }
}

/// Tint transform for Separation/DeviceN
abstract class TintTransform {
  List<double> apply(List<double> input);
}

/// Identity tint transform
class IdentityTintTransform implements TintTransform {
  @override
  List<double> apply(List<double> input) => input;
}
