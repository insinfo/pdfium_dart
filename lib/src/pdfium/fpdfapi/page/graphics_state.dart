

import '../../fxcrt/fx_coordinates.dart';
import '../../fxge/fx_dib.dart';

/// Estado de cor
class ColorState {
  String fillColorSpace;
  String strokeColorSpace;
  List<double> fillColor;
  List<double> strokeColor;
  
  ColorState()
      : fillColorSpace = 'DeviceGray',
        strokeColorSpace = 'DeviceGray',
        fillColor = [0.0],
        strokeColor = [0.0];
  
  ColorState.copy(ColorState other)
      : fillColorSpace = other.fillColorSpace,
        strokeColorSpace = other.strokeColorSpace,
        fillColor = List.from(other.fillColor),
        strokeColor = List.from(other.strokeColor);
  
  FxColor get fillFxColor => _toFxColor(fillColorSpace, fillColor);
  FxColor get strokeFxColor => _toFxColor(strokeColorSpace, strokeColor);
  
  FxColor _toFxColor(String colorSpace, List<double> values) {
    switch (colorSpace) {
      case 'DeviceGray':
      case 'G':
        final gray = ((values.isNotEmpty ? values[0] : 0.0) * 255).round().clamp(0, 255);
        return FxColor.fromRGB(gray, gray, gray);
        
      case 'DeviceRGB':
      case 'RGB':
        final r = ((values.isNotEmpty ? values[0] : 0.0) * 255).round().clamp(0, 255);
        final g = ((values.length > 1 ? values[1] : 0.0) * 255).round().clamp(0, 255);
        final b = ((values.length > 2 ? values[2] : 0.0) * 255).round().clamp(0, 255);
        return FxColor.fromRGB(r, g, b);
        
      case 'DeviceCMYK':
      case 'CMYK':
        final c = values.isNotEmpty ? values[0] : 0.0;
        final m = values.length > 1 ? values[1] : 0.0;
        final y = values.length > 2 ? values[2] : 0.0;
        final k = values.length > 3 ? values[3] : 0.0;
        // CMYK para RGB
        final r = ((1 - c) * (1 - k) * 255).round().clamp(0, 255);
        final g = ((1 - m) * (1 - k) * 255).round().clamp(0, 255);
        final b = ((1 - y) * (1 - k) * 255).round().clamp(0, 255);
        return FxColor.fromRGB(r, g, b);
        
      default:
        return FxColor.black;
    }
  }
  
  void setFillGray(double gray) {
    fillColorSpace = 'DeviceGray';
    fillColor = [gray.clamp(0.0, 1.0)];
  }
  
  void setStrokeGray(double gray) {
    strokeColorSpace = 'DeviceGray';
    strokeColor = [gray.clamp(0.0, 1.0)];
  }
  
  void setFillRGB(double r, double g, double b) {
    fillColorSpace = 'DeviceRGB';
    fillColor = [r.clamp(0.0, 1.0), g.clamp(0.0, 1.0), b.clamp(0.0, 1.0)];
  }
  
  void setStrokeRGB(double r, double g, double b) {
    strokeColorSpace = 'DeviceRGB';
    strokeColor = [r.clamp(0.0, 1.0), g.clamp(0.0, 1.0), b.clamp(0.0, 1.0)];
  }
  
  void setFillCMYK(double c, double m, double y, double k) {
    fillColorSpace = 'DeviceCMYK';
    fillColor = [
      c.clamp(0.0, 1.0), 
      m.clamp(0.0, 1.0), 
      y.clamp(0.0, 1.0), 
      k.clamp(0.0, 1.0)
    ];
  }
  
  void setStrokeCMYK(double c, double m, double y, double k) {
    strokeColorSpace = 'DeviceCMYK';
    strokeColor = [
      c.clamp(0.0, 1.0), 
      m.clamp(0.0, 1.0), 
      y.clamp(0.0, 1.0), 
      k.clamp(0.0, 1.0)
    ];
  }
}

/// Estado de texto
class TextState {
  double charSpace = 0.0;
  double wordSpace = 0.0;
  double horizontalScale = 100.0;
  double leading = 0.0;
  String? fontName;
  double fontSize = 0.0;
  int renderMode = 0;
  double rise = 0.0;
  
  TextState();
  
  TextState.copy(TextState other)
      : charSpace = other.charSpace,
        wordSpace = other.wordSpace,
        horizontalScale = other.horizontalScale,
        leading = other.leading,
        fontName = other.fontName,
        fontSize = other.fontSize,
        renderMode = other.renderMode,
        rise = other.rise;
}

/// Estilo de linha
enum LineCap {
  butt(0),
  round(1),
  square(2);
  
  final int value;
  const LineCap(this.value);
  
  static LineCap fromValue(int v) {
    switch (v) {
      case 1: return LineCap.round;
      case 2: return LineCap.square;
      default: return LineCap.butt;
    }
  }
}

enum LineJoin {
  miter(0),
  round(1),
  bevel(2);
  
  final int value;
  const LineJoin(this.value);
  
  static LineJoin fromValue(int v) {
    switch (v) {
      case 1: return LineJoin.round;
      case 2: return LineJoin.bevel;
      default: return LineJoin.miter;
    }
  }
}

/// Estado da linha
class LineState {
  double width = 1.0;
  LineCap cap = LineCap.butt;
  LineJoin join = LineJoin.miter;
  double miterLimit = 10.0;
  List<double> dashArray = [];
  double dashPhase = 0.0;
  
  LineState();
  
  LineState.copy(LineState other)
      : width = other.width,
        cap = other.cap,
        join = other.join,
        miterLimit = other.miterLimit,
        dashArray = List.from(other.dashArray),
        dashPhase = other.dashPhase;
}

/// Estado gráfico completo
class GraphicsState {
  FxMatrix ctm;
  ColorState color;
  TextState text;
  LineState line;
  FxRect? clipRect;
  double flatness = 1.0;
  String renderingIntent = 'RelativeColorimetric';
  
  GraphicsState()
      : ctm = const FxMatrix.identity(),
        color = ColorState(),
        text = TextState(),
        line = LineState();
  
  GraphicsState.copy(GraphicsState other)
      : ctm = other.ctm,
        color = ColorState.copy(other.color),
        text = TextState.copy(other.text),
        line = LineState.copy(other.line),
        clipRect = other.clipRect,
        flatness = other.flatness,
        renderingIntent = other.renderingIntent;
  
  /// Concatena matriz ao CTM
  void concatMatrix(FxMatrix matrix) {
    ctm = ctm.concat(matrix);
  }
}

/// Pilha de estados gráficos
class GraphicsStateStack {
  final List<GraphicsState> _stack = [];
  GraphicsState _current = GraphicsState();
  
  GraphicsState get current => _current;
  
  /// Salva o estado atual (q)
  void save() {
    _stack.add(GraphicsState.copy(_current));
  }
  
  /// Restaura o estado anterior (Q)
  void restore() {
    if (_stack.isNotEmpty) {
      _current = _stack.removeLast();
    }
  }
  
  /// Limpa a pilha
  void reset() {
    _stack.clear();
    _current = GraphicsState();
  }
  
  int get depth => _stack.length;
}

/// Ponto no caminho
class PathPoint {
  final double x;
  final double y;
  final PathPointType type;
  
  const PathPoint(this.x, this.y, this.type);
  
  PathPoint transform(FxMatrix matrix) {
    final p = matrix.transformPoint(FxPoint(x, y));
    return PathPoint(p.x, p.y, type);
  }
}

enum PathPointType {
  moveTo,
  lineTo,
  curveTo,   // Ponto de controle 1
  curveToC2, // Ponto de controle 2
  curveToEnd, // Ponto final da curva
  closePath,
}

/// Caminho gráfico
class GraphicsPath {
  final List<PathPoint> points = [];
  bool _hasCurrentPoint = false;
  double _currentX = 0.0;
  double _currentY = 0.0;
  double _startX = 0.0;
  double _startY = 0.0;
  
  bool get isEmpty => points.isEmpty;
  bool get hasCurrentPoint => _hasCurrentPoint;
  double get currentX => _currentX;
  double get currentY => _currentY;
  
  void moveTo(double x, double y) {
    points.add(PathPoint(x, y, PathPointType.moveTo));
    _currentX = x;
    _currentY = y;
    _startX = x;
    _startY = y;
    _hasCurrentPoint = true;
  }
  
  void lineTo(double x, double y) {
    if (!_hasCurrentPoint) {
      moveTo(x, y);
      return;
    }
    points.add(PathPoint(x, y, PathPointType.lineTo));
    _currentX = x;
    _currentY = y;
  }
  
  void curveTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    if (!_hasCurrentPoint) {
      moveTo(x1, y1);
    }
    points.add(PathPoint(x1, y1, PathPointType.curveTo));
    points.add(PathPoint(x2, y2, PathPointType.curveToC2));
    points.add(PathPoint(x3, y3, PathPointType.curveToEnd));
    _currentX = x3;
    _currentY = y3;
  }
  
  /// Curva de Bezier com primeiro ponto de controle = ponto atual
  void curveToV(double x2, double y2, double x3, double y3) {
    curveTo(_currentX, _currentY, x2, y2, x3, y3);
  }
  
  /// Curva de Bezier com último ponto de controle = ponto final
  void curveToY(double x1, double y1, double x3, double y3) {
    curveTo(x1, y1, x3, y3, x3, y3);
  }
  
  void closePath() {
    if (_hasCurrentPoint) {
      points.add(PathPoint(_startX, _startY, PathPointType.closePath));
      _currentX = _startX;
      _currentY = _startY;
    }
  }
  
  void rect(double x, double y, double w, double h) {
    moveTo(x, y);
    lineTo(x + w, y);
    lineTo(x + w, y + h);
    lineTo(x, y + h);
    closePath();
  }
  
  void clear() {
    points.clear();
    _hasCurrentPoint = false;
    _currentX = 0.0;
    _currentY = 0.0;
    _startX = 0.0;
    _startY = 0.0;
  }
  
  /// Calcula bounding box
  FxRect? get bounds {
    if (points.isEmpty) return null;
    
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    
    return FxRect(minX, minY, maxX, maxY);
  }
  
  /// Transforma o caminho pela matriz
  GraphicsPath transform(FxMatrix matrix) {
    final newPath = GraphicsPath();
    for (final p in points) {
      final tp = p.transform(matrix);
      newPath.points.add(tp);
    }
    if (_hasCurrentPoint) {
      final cp = matrix.transformPoint(FxPoint(_currentX, _currentY));
      newPath._currentX = cp.x;
      newPath._currentY = cp.y;
      newPath._hasCurrentPoint = true;
      
      final sp = matrix.transformPoint(FxPoint(_startX, _startY));
      newPath._startX = sp.x;
      newPath._startY = sp.y;
    }
    return newPath;
  }
}

/// Posição de texto
class TextPosition {
  FxMatrix textMatrix;
  FxMatrix lineMatrix;
  
  TextPosition()
      : textMatrix = const FxMatrix.identity(),
        lineMatrix = const FxMatrix.identity();
  
  TextPosition.copy(TextPosition other)
      : textMatrix = other.textMatrix,
        lineMatrix = other.lineMatrix;
  
  /// Move para nova posição (Td)
  void moveBy(double tx, double ty) {
    lineMatrix = FxMatrix.translate(tx, ty).concat(lineMatrix);
    textMatrix = lineMatrix;
  }
  
  /// Move e define leading (TD)
  void moveBySetLeading(double tx, double ty, TextState textState) {
    textState.leading = -ty;
    moveBy(tx, ty);
  }
  
  /// Define matriz de texto (Tm)
  void setMatrix(double a, double b, double c, double d, double e, double f) {
    textMatrix = FxMatrix(a, b, c, d, e, f);
    lineMatrix = textMatrix;
  }
  
  /// Move para próxima linha (T*)
  void nextLine(TextState textState) {
    moveBy(0, -textState.leading);
  }
  
  /// Avança posição horizontal
  void advance(double dx) {
    textMatrix = FxMatrix.translate(dx, 0).concat(textMatrix);
  }
}
