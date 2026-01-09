

import 'dart:typed_data';

import '../../fxcrt/fx_coordinates.dart';
import '../../fxge/fx_dib.dart';
import '../parser/pdf_array.dart';
import '../parser/pdf_dictionary.dart';
import '../parser/pdf_number.dart';
import '../parser/pdf_stream.dart';
import 'pdf_page.dart';
import 'content_stream_parser.dart';
import 'graphics_state.dart';

/// Interpreta content stream e renderiza em bitmap
class ContentStreamInterpreter {
  final PdfPage page;
  final FxDIBitmap bitmap;
  final PdfDictionary? resources;
  final GraphicsStateStack _stateStack = GraphicsStateStack();
  final GraphicsPath _currentPath = GraphicsPath();
  TextPosition _textPosition = TextPosition();
  bool _inTextObject = false;
  
  ContentStreamInterpreter(this.page, this.bitmap, [this.resources]);
  
  GraphicsState get state => _stateStack.current;
  
  /// Renderiza o conteúdo da página
  void render() {
    // Limpar bitmap com branco
    bitmap.clear(FxColor.white);
    
    // Resetar estado
    _stateStack.reset();
    _currentPath.clear();
    _textPosition = TextPosition();
    _inTextObject = false;
    
    // Configurar matriz de transformação inicial (página para bitmap)
    final displayMatrix = page.getDisplayMatrix(bitmap.width, bitmap.height);
    state.ctm = displayMatrix;
    
    // Obter content stream
    final contentStreams = _getContentStreams();
    if (contentStreams.isEmpty) return;
    
    // Parsear e executar
    final parser = ContentStreamParser.fromStreams(
      contentStreams,
      resources ?? page.resources,
    );
    
    final operations = parser.parseAll();
    for (final op in operations) {
      _executeOperation(op);
    }
  }
  
  List<PdfStream> _getContentStreams() {
    final contents = page.dict.get('Contents');
    if (contents == null) return [];
    
    if (contents is PdfStream) {
      return [contents];
    }
    
    if (contents is PdfArray) {
      final streams = <PdfStream>[];
      for (int i = 0; i < contents.length; i++) {
        final item = contents.getDirectAt(i);
        if (item is PdfStream) {
          streams.add(item);
        }
      }
      return streams;
    }
    
    return [];
  }
  
  void _executeOperation(ContentOperation op) {
    switch (op.operator) {
      // Graphics State
      case ContentOperator.gsave:
        _stateStack.save();
        break;
        
      case ContentOperator.grestore:
        _stateStack.restore();
        break;
        
      case ContentOperator.ctm:
        _executeCTM(op);
        break;
        
      case ContentOperator.lineWidth:
        state.line.width = op.getNumber(0, 1.0);
        break;
        
      case ContentOperator.lineCap:
        state.line.cap = LineCap.fromValue(op.getInt(0));
        break;
        
      case ContentOperator.lineJoin:
        state.line.join = LineJoin.fromValue(op.getInt(0));
        break;
        
      case ContentOperator.miterLimit:
        state.line.miterLimit = op.getNumber(0, 10.0);
        break;
        
      case ContentOperator.dashPattern:
        _executeDash(op);
        break;
        
      case ContentOperator.flatness:
        state.flatness = op.getNumber(0, 1.0);
        break;
        
      // Path Construction
      case ContentOperator.moveTo:
        _currentPath.moveTo(op.getNumber(0), op.getNumber(1));
        break;
        
      case ContentOperator.lineTo:
        _currentPath.lineTo(op.getNumber(0), op.getNumber(1));
        break;
        
      case ContentOperator.curveTo:
        _currentPath.curveTo(
          op.getNumber(0), op.getNumber(1),
          op.getNumber(2), op.getNumber(3),
          op.getNumber(4), op.getNumber(5),
        );
        break;
        
      case ContentOperator.curveToV:
        _currentPath.curveToV(
          op.getNumber(0), op.getNumber(1),
          op.getNumber(2), op.getNumber(3),
        );
        break;
        
      case ContentOperator.curveToY:
        _currentPath.curveToY(
          op.getNumber(0), op.getNumber(1),
          op.getNumber(2), op.getNumber(3),
        );
        break;
        
      case ContentOperator.closePath:
        _currentPath.closePath();
        break;
        
      case ContentOperator.rect:
        _currentPath.rect(
          op.getNumber(0), op.getNumber(1),
          op.getNumber(2), op.getNumber(3),
        );
        break;
        
      // Path Painting
      case ContentOperator.stroke:
        _strokePath(close: false);
        break;
        
      case ContentOperator.closeStroke:
        _strokePath(close: true);
        break;
        
      case ContentOperator.fill:
      case ContentOperator.fillOld:
        _fillPath(evenOdd: false);
        break;
        
      case ContentOperator.fillEvenOdd:
        _fillPath(evenOdd: true);
        break;
        
      case ContentOperator.fillStroke:
        _fillPath(evenOdd: false);
        _strokePath(close: false);
        break;
        
      case ContentOperator.fillStrokeEvenOdd:
        _fillPath(evenOdd: true);
        _strokePath(close: false);
        break;
        
      case ContentOperator.closeFillStroke:
        _currentPath.closePath();
        _fillPath(evenOdd: false);
        _strokePath(close: false);
        break;
        
      case ContentOperator.closeFillStrokeEvenOdd:
        _currentPath.closePath();
        _fillPath(evenOdd: true);
        _strokePath(close: false);
        break;
        
      case ContentOperator.endPath:
        _currentPath.clear();
        break;
        
      // Clipping
      case ContentOperator.clip:
        _setClip(evenOdd: false);
        break;
        
      case ContentOperator.clipEvenOdd:
        _setClip(evenOdd: true);
        break;
        
      // Text Object
      case ContentOperator.beginText:
        _inTextObject = true;
        _textPosition = TextPosition();
        break;
        
      case ContentOperator.endText:
        _inTextObject = false;
        break;
        
      // Text State
      case ContentOperator.charSpace:
        state.text.charSpace = op.getNumber(0);
        break;
        
      case ContentOperator.wordSpace:
        state.text.wordSpace = op.getNumber(0);
        break;
        
      case ContentOperator.hScale:
        state.text.horizontalScale = op.getNumber(0);
        break;
        
      case ContentOperator.textLeading:
        state.text.leading = op.getNumber(0);
        break;
        
      case ContentOperator.font:
        _executeFont(op);
        break;
        
      case ContentOperator.textRender:
        state.text.renderMode = op.getInt(0);
        break;
        
      case ContentOperator.textRise:
        state.text.rise = op.getNumber(0);
        break;
        
      // Text Positioning
      case ContentOperator.textMove:
        _textPosition.moveBy(op.getNumber(0), op.getNumber(1));
        break;
        
      case ContentOperator.textMoveSet:
        _textPosition.moveBySetLeading(
          op.getNumber(0), op.getNumber(1), state.text);
        break;
        
      case ContentOperator.textMatrix:
        _textPosition.setMatrix(
          op.getNumber(0), op.getNumber(1),
          op.getNumber(2), op.getNumber(3),
          op.getNumber(4), op.getNumber(5),
        );
        break;
        
      case ContentOperator.textNewLine:
        _textPosition.nextLine(state.text);
        break;
        
      // Text Showing
      case ContentOperator.showText:
        _showText(op.getStringBytes(0));
        break;
        
      case ContentOperator.showTextNewLine:
        _textPosition.nextLine(state.text);
        _showText(op.getStringBytes(0));
        break;
        
      case ContentOperator.showTextSpacing:
        state.text.wordSpace = op.getNumber(0);
        state.text.charSpace = op.getNumber(1);
        _textPosition.nextLine(state.text);
        _showText(op.getStringBytes(2));
        break;
        
      case ContentOperator.showTextArray:
        _showTextArray(op.getArray(0));
        break;
        
      // Color Operators
      case ContentOperator.fillGray:
        state.color.setFillGray(op.getNumber(0));
        break;
        
      case ContentOperator.strokeGray:
        state.color.setStrokeGray(op.getNumber(0));
        break;
        
      case ContentOperator.fillRGB:
        state.color.setFillRGB(
          op.getNumber(0), op.getNumber(1), op.getNumber(2));
        break;
        
      case ContentOperator.strokeRGB:
        state.color.setStrokeRGB(
          op.getNumber(0), op.getNumber(1), op.getNumber(2));
        break;
        
      case ContentOperator.fillCMYK:
        state.color.setFillCMYK(
          op.getNumber(0), op.getNumber(1),
          op.getNumber(2), op.getNumber(3));
        break;
        
      case ContentOperator.strokeCMYK:
        state.color.setStrokeCMYK(
          op.getNumber(0), op.getNumber(1),
          op.getNumber(2), op.getNumber(3));
        break;
        
      case ContentOperator.fillColorSpace:
        state.color.fillColorSpace = op.getName(0) ?? 'DeviceGray';
        break;
        
      case ContentOperator.strokeColorSpace:
        state.color.strokeColorSpace = op.getName(0) ?? 'DeviceGray';
        break;
        
      case ContentOperator.fillColor:
      case ContentOperator.fillColorN:
        _setFillColor(op);
        break;
        
      case ContentOperator.strokeColor:
      case ContentOperator.strokeColorN:
        _setStrokeColor(op);
        break;
        
      // XObject
      case ContentOperator.xobject:
        _executeXObject(op.getName(0));
        break;
        
      // Inline Image
      case ContentOperator.beginImage:
        _executeInlineImage(op);
        break;
        
      default:
        // Operador não implementado - ignorar
        break;
    }
  }
  
  void _executeCTM(ContentOperation op) {
    final matrix = FxMatrix(
      op.getNumber(0, 1), op.getNumber(1, 0),
      op.getNumber(2, 0), op.getNumber(3, 1),
      op.getNumber(4, 0), op.getNumber(5, 0),
    );
    state.concatMatrix(matrix);
  }
  
  void _executeDash(ContentOperation op) {
    final arr = op.getArray(0);
    if (arr != null) {
      state.line.dashArray = [];
      for (int i = 0; i < arr.length; i++) {
        state.line.dashArray.add(arr.getNumberAt(i) ?? 0.0);
      }
    }
    state.line.dashPhase = op.getNumber(1, 0.0);
  }
  
  void _executeFont(ContentOperation op) {
    state.text.fontName = op.getName(0);
    state.text.fontSize = op.getNumber(1, 12.0);
  }
  
  void _setFillColor(ContentOperation op) {
    state.color.fillColor = [];
    for (int i = 0; i < op.operands.length; i++) {
      final n = op.getNumber(i);
      state.color.fillColor.add(n);
    }
  }
  
  void _setStrokeColor(ContentOperation op) {
    state.color.strokeColor = [];
    for (int i = 0; i < op.operands.length; i++) {
      final n = op.getNumber(i);
      state.color.strokeColor.add(n);
    }
  }
  
  // ==========================================================================
  // Renderização de caminhos
  // ==========================================================================
  
  void _strokePath({required bool close}) {
    if (_currentPath.isEmpty) return;
    
    if (close) {
      _currentPath.closePath();
    }
    
    final transformedPath = _currentPath.transform(state.ctm);
    _renderStroke(transformedPath);
    _currentPath.clear();
  }
  
  void _fillPath({required bool evenOdd}) {
    if (_currentPath.isEmpty) return;
    
    final transformedPath = _currentPath.transform(state.ctm);
    _renderFill(transformedPath, evenOdd);
    _currentPath.clear();
  }
  
  void _setClip({required bool evenOdd}) {
    final bounds = _currentPath.bounds;
    if (bounds != null) {
      final transformed = state.ctm.transformRect(bounds);
      state.clipRect = transformed;
    }
  }
  
  /// Renderiza stroke de um caminho
  void _renderStroke(GraphicsPath path) {
    final color = state.color.strokeFxColor;
    final lineWidth = (state.line.width * state.ctm.a).abs().clamp(0.5, 100.0);
    
    // Iterar pelos segmentos do caminho
    double lastX = 0, lastY = 0;
    
    for (final point in path.points) {
      switch (point.type) {
        case PathPointType.moveTo:
          lastX = point.x;
          lastY = point.y;
          break;
          
        case PathPointType.lineTo:
          _drawLine(lastX, lastY, point.x, point.y, color, lineWidth);
          lastX = point.x;
          lastY = point.y;
          break;
          
        case PathPointType.closePath:
          break;
          
        default:
          // Curvas - simplificar para linhas
          lastX = point.x;
          lastY = point.y;
          break;
      }
    }
  }
  
  /// Renderiza fill de um caminho
  void _renderFill(GraphicsPath path, bool evenOdd) {
    final color = state.color.fillFxColor;
    final bounds = path.bounds;
    if (bounds == null) return;
    
    // Scanline fill algorithm simplificado
    final minY = bounds.top.floor().clamp(0, bitmap.height - 1);
    final maxY = bounds.bottom.ceil().clamp(0, bitmap.height - 1);
    
    for (int y = minY; y <= maxY; y++) {
      final intersections = _findIntersections(path, y.toDouble());
      intersections.sort();
      
      // Preencher entre pares de intersecções
      for (int i = 0; i < intersections.length - 1; i += 2) {
        final x1 = intersections[i].floor().clamp(0, bitmap.width - 1);
        final x2 = intersections[i + 1].ceil().clamp(0, bitmap.width - 1);
        
        for (int x = x1; x <= x2; x++) {
          if (_isInClip(x, y)) {
            bitmap.setPixel(x, y, color);
          }
        }
      }
    }
  }
  
  List<double> _findIntersections(GraphicsPath path, double y) {
    final intersections = <double>[];
    double lastX = 0, lastY = 0;
    double startX = 0, startY = 0;
    bool hasStart = false;
    
    for (final point in path.points) {
      switch (point.type) {
        case PathPointType.moveTo:
          lastX = point.x;
          lastY = point.y;
          startX = point.x;
          startY = point.y;
          hasStart = true;
          break;
          
        case PathPointType.lineTo:
          final ix = _lineIntersection(lastX, lastY, point.x, point.y, y);
          if (ix != null) intersections.add(ix);
          lastX = point.x;
          lastY = point.y;
          break;
          
        case PathPointType.closePath:
          if (hasStart) {
            final ix = _lineIntersection(lastX, lastY, startX, startY, y);
            if (ix != null) intersections.add(ix);
          }
          lastX = startX;
          lastY = startY;
          break;
          
        default:
          lastX = point.x;
          lastY = point.y;
          break;
      }
    }
    
    return intersections;
  }
  
  double? _lineIntersection(double x1, double y1, double x2, double y2, double y) {
    if ((y1 <= y && y2 > y) || (y2 <= y && y1 > y)) {
      final t = (y - y1) / (y2 - y1);
      return x1 + t * (x2 - x1);
    }
    return null;
  }
  
  /// Desenha linha usando algoritmo de Bresenham com espessura
  void _drawLine(double x1, double y1, double x2, double y2, FxColor color, double width) {
    final ix1 = x1.round();
    final iy1 = y1.round();
    final ix2 = x2.round();
    final iy2 = y2.round();
    
    final dx = (ix2 - ix1).abs();
    final dy = (iy2 - iy1).abs();
    final sx = ix1 < ix2 ? 1 : -1;
    final sy = iy1 < iy2 ? 1 : -1;
    var err = dx - dy;
    
    var x = ix1;
    var y = iy1;
    final halfWidth = (width / 2).ceil();
    
    while (true) {
      // Desenhar com espessura
      for (int dy = -halfWidth; dy <= halfWidth; dy++) {
        for (int dx = -halfWidth; dx <= halfWidth; dx++) {
          final px = x + dx;
          final py = y + dy;
          if (_isInBounds(px, py) && _isInClip(px, py)) {
            bitmap.setPixel(px, py, color);
          }
        }
      }
      
      if (x == ix2 && y == iy2) break;
      
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }
  
  bool _isInBounds(int x, int y) {
    return x >= 0 && x < bitmap.width && y >= 0 && y < bitmap.height;
  }
  
  bool _isInClip(int x, int y) {
    final clip = state.clipRect;
    if (clip == null) return true;
    return x >= clip.left && x <= clip.right &&
           y >= clip.top && y <= clip.bottom;
  }
  
  // ==========================================================================
  // Renderização de texto
  // ==========================================================================
  
  void _showText(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return;
    
    // TODO: Implementar renderização de texto com fontes
    // Por enquanto, apenas avança a posição
    final advance = bytes.length * state.text.fontSize * 0.6;
    _textPosition.advance(advance * state.text.horizontalScale / 100);
  }
  
  void _showTextArray(PdfArray? array) {
    if (array == null) return;
    
    for (int i = 0; i < array.length; i++) {
      final item = array[i];
      if (item is PdfNumber) {
        // Ajuste de posição (em milésimos de unidade de texto)
        final adjust = item.numberValue / 1000 * state.text.fontSize;
        _textPosition.advance(-adjust * state.text.horizontalScale / 100);
      } else {
        // String de texto
        // _showText vai precisar dos bytes
      }
    }
  }
  
  // ==========================================================================
  // XObjects e imagens
  // ==========================================================================
  
  void _executeXObject(String? name) {
    if (name == null) return;
    
    final xobjects = resources?.getDictionary('XObject') ?? 
                     page.resources?.getDictionary('XObject');
    if (xobjects == null) return;
    
    final xobj = xobjects.getStream(name);
    if (xobj == null) return;
    
    final subtype = xobj.dict.getName('Subtype');
    
    switch (subtype) {
      case 'Image':
        _renderImage(xobj);
        break;
        
      case 'Form':
        _renderForm(xobj);
        break;
    }
  }
  
  void _renderImage(PdfStream imageStream) {
    final width = imageStream.dict.getInt('Width') ?? 0;
    final height = imageStream.dict.getInt('Height') ?? 0;
    if (width <= 0 || height <= 0) return;
    
    final data = imageStream.decodedData;
    if (data == null) return;
    
    final bpc = imageStream.dict.getInt('BitsPerComponent') ?? 8;
    final colorSpace = imageStream.dict.getName('ColorSpace') ?? 'DeviceGray';
    
    // Calcular posição transformada
    final ctm = state.ctm;
    final destRect = ctm.transformRect(const FxRect(0, 0, 1, 1));
    
    // Renderizar imagem escalada
    _blitImage(data, width, height, bpc, colorSpace, destRect);
  }
  
  void _blitImage(Uint8List data, int srcWidth, int srcHeight, 
                  int bpc, String colorSpace, FxRect destRect) {
    final destX = destRect.left.round().clamp(0, bitmap.width - 1);
    final destY = destRect.top.round().clamp(0, bitmap.height - 1);
    final destW = destRect.width.round().clamp(1, bitmap.width - destX);
    final destH = destRect.height.round().clamp(1, bitmap.height - destY);
    
    final bytesPerPixel = colorSpace == 'DeviceRGB' ? 3 : 1;
    
    for (int dy = 0; dy < destH; dy++) {
      final srcY = (dy * srcHeight ~/ destH).clamp(0, srcHeight - 1);
      
      for (int dx = 0; dx < destW; dx++) {
        final srcX = (dx * srcWidth ~/ destW).clamp(0, srcWidth - 1);
        
        final srcIdx = (srcY * srcWidth + srcX) * bytesPerPixel;
        if (srcIdx >= data.length) continue;
        
        FxColor color;
        if (colorSpace == 'DeviceRGB' && srcIdx + 2 < data.length) {
          color = FxColor.fromRGB(data[srcIdx], data[srcIdx + 1], data[srcIdx + 2]);
        } else {
          final gray = data[srcIdx];
          color = FxColor.fromRGB(gray, gray, gray);
        }
        
        final px = destX + dx;
        final py = destY + dy;
        if (_isInBounds(px, py) && _isInClip(px, py)) {
          bitmap.setPixel(px, py, color);
        }
      }
    }
  }
  
  void _renderForm(PdfStream formStream) {
    // Salvar estado
    _stateStack.save();
    
    // Aplicar matriz do form
    final matrix = formStream.dict.getArray('Matrix');
    if (matrix != null && matrix.length >= 6) {
      final m = FxMatrix(
        matrix.getNumberAt(0) ?? 1, matrix.getNumberAt(1) ?? 0,
        matrix.getNumberAt(2) ?? 0, matrix.getNumberAt(3) ?? 1,
        matrix.getNumberAt(4) ?? 0, matrix.getNumberAt(5) ?? 0,
      );
      state.concatMatrix(m);
    }
    
    // Parsear e executar conteúdo do form
    final data = formStream.decodedData;
    if (data != null) {
      final formResources = formStream.dict.getDictionary('Resources') ?? resources;
      final parser = ContentStreamParser(data, formResources);
      final operations = parser.parseAll();
      
      for (final op in operations) {
        _executeOperation(op);
      }
    }
    
    // Restaurar estado
    _stateStack.restore();
  }
  
  void _executeInlineImage(ContentOperation op) {
    final arr = op.getArray(0);
    if (arr == null || arr.length < 2) return;
    
    final dict = arr[0];
    if (dict is! PdfDictionary) return;
    
    // A implementação completa requer decodificar os dados
    // Por enquanto, apenas pulamos inline images
  }
}
