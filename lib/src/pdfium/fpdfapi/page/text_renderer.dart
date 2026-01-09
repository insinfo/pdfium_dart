

import 'dart:typed_data';

import '../../fxcrt/fx_coordinates.dart';
import '../../fxge/fx_dib.dart';
import '../font/pdf_font.dart';
import '../parser/pdf_dictionary.dart';
import 'graphics_state.dart';

/// Informações de um glifo renderizado
class RenderedGlyph {
  final int charCode;
  final int? unicode;
  final double x;
  final double y;
  final double width;
  final double fontSize;
  final PdfFont font;
  
  RenderedGlyph({
    required this.charCode,
    this.unicode,
    required this.x,
    required this.y,
    required this.width,
    required this.fontSize,
    required this.font,
  });
  
  String get character => unicode != null ? String.fromCharCode(unicode!) : '?';
}

/// Renderizador de texto
class TextRenderer {
  final FxDIBitmap bitmap;
  final FontCache _fontCache = FontCache();
  
  TextRenderer(this.bitmap);
  
  /// Carrega fonte do dicionário de recursos
  PdfFont? loadFont(String fontName, PdfDictionary? resources) {
    // Verificar cache
    if (_fontCache.contains(fontName)) {
      return _fontCache.get(fontName);
    }
    
    if (resources == null) return null;
    
    final fontResources = resources.getDictionary('Font');
    if (fontResources == null) return null;
    
    final fontDict = fontResources.getDictionary(fontName);
    if (fontDict == null) return null;
    
    final font = PdfFont.fromDictionary(fontDict);
    _fontCache.put(fontName, font);
    return font;
  }
  
  /// Renderiza string de texto
  List<RenderedGlyph> renderText(
    Uint8List bytes,
    TextState textState,
    TextPosition textPosition,
    FxMatrix ctm,
    PdfDictionary? resources,
  ) {
    final glyphs = <RenderedGlyph>[];
    
    if (textState.fontName == null) return glyphs;
    
    final font = loadFont(textState.fontName!, resources);
    if (font == null) return glyphs;
    
    final fontSize = textState.fontSize;
    final hScale = textState.horizontalScale / 100.0;
    final charSpace = textState.charSpace;
    final wordSpace = textState.wordSpace;
    final rise = textState.rise;
    
    // Matriz de renderização de texto completa
    // Trm = [fontSize*Th 0 0; 0 fontSize 0; 0 Trise 1] × Tm × CTM
    
    for (int i = 0; i < bytes.length; i++) {
      final charCode = bytes[i];
      
      // Obter posição do glifo
      final tm = textPosition.textMatrix;
      
      // Calcular posição no espaço do dispositivo
      final textRenderMatrix = FxMatrix(
        fontSize * hScale, 0,
        0, fontSize,
        0, rise,
      );
      
      // Combinar matrizes
      final fullMatrix = textRenderMatrix.concat(tm).concat(ctm);
      
      // Posição do glifo
      final pos = fullMatrix.transformPoint(const FxPoint(0, 0));
      
      // Largura do caractere
      final charWidth = font.getCharWidth(charCode);
      final glyphWidth = (charWidth / 1000.0) * fontSize * hScale;
      
      // Unicode para exibição
      final unicode = font.getUnicode(charCode);
      
      glyphs.add(RenderedGlyph(
        charCode: charCode,
        unicode: unicode,
        x: pos.x,
        y: pos.y,
        width: glyphWidth,
        fontSize: fontSize,
        font: font,
      ));
      
      // Avançar posição do texto
      double advance = glyphWidth;
      
      // Espaçamento de caractere
      advance += charSpace * hScale;
      
      // Espaçamento de palavra (para espaço)
      if (charCode == 32) {
        advance += wordSpace * hScale;
      }
      
      textPosition.advance(advance / (fontSize * hScale) * 1000);
    }
    
    return glyphs;
  }
  
  /// Renderiza glifos no bitmap (versão simplificada)
  void drawGlyphs(
    List<RenderedGlyph> glyphs, 
    FxColor color,
    int renderMode,
  ) {
    // Modo de renderização:
    // 0 = Fill
    // 1 = Stroke
    // 2 = Fill then stroke
    // 3 = Invisible
    // 4-7 = Same as 0-3 but also add to path for clipping
    
    if (renderMode == 3 || renderMode == 7) {
      return; // Invisível
    }
    
    for (final glyph in glyphs) {
      _drawGlyph(glyph, color);
    }
  }
  
  void _drawGlyph(RenderedGlyph glyph, FxColor color) {
    // Renderização simplificada - desenhar um retângulo representando o glifo
    // Uma implementação real usaria rasterização de fontes
    
    final x = glyph.x.round();
    final y = glyph.y.round();
    final w = glyph.width.round().clamp(1, 100);
    final h = glyph.fontSize.round().clamp(1, 100);
    
    // Desenhar um marcador simples para cada caractere
    // (implementação real desenharia o glifo da fonte)
    for (int dy = 0; dy < h; dy++) {
      final py = y - h + dy;
      if (py < 0 || py >= bitmap.height) continue;
      
      for (int dx = 0; dx < w; dx++) {
        final px = x + dx;
        if (px < 0 || px >= bitmap.width) continue;
        
        // Apenas desenhar borda do retângulo
        if (dx == 0 || dx == w - 1 || dy == 0 || dy == h - 1) {
          bitmap.setPixel(px, py, color);
        }
      }
    }
  }
  
  /// Limpa cache de fontes
  void clearCache() {
    _fontCache.clear();
  }
}

/// Extrator de texto de página
class TextExtractor {
  final List<RenderedGlyph> _glyphs = [];
  
  void addGlyph(RenderedGlyph glyph) {
    _glyphs.add(glyph);
  }
  
  void addGlyphs(List<RenderedGlyph> glyphs) {
    _glyphs.addAll(glyphs);
  }
  
  void clear() {
    _glyphs.clear();
  }
  
  /// Obtém texto como string
  String getText() {
    if (_glyphs.isEmpty) return '';
    
    final buffer = StringBuffer();
    double lastX = double.negativeInfinity;
    double lastY = double.negativeInfinity;
    
    // Ordenar glifos por posição (Y primeiro, depois X)
    final sorted = List<RenderedGlyph>.from(_glyphs);
    sorted.sort((a, b) {
      final yDiff = (a.y - b.y).round();
      if (yDiff.abs() > 5) { // Tolerância para mesma linha
        return yDiff;
      }
      return (a.x - b.x).round();
    });
    
    for (final glyph in sorted) {
      // Detectar nova linha
      if (lastY != double.negativeInfinity) {
        final yDiff = (glyph.y - lastY).abs();
        if (yDiff > glyph.fontSize * 0.5) {
          buffer.writeln();
          lastX = double.negativeInfinity;
        } else {
          // Detectar espaço entre palavras
          final xGap = glyph.x - lastX;
          if (xGap > glyph.fontSize * 0.3) {
            buffer.write(' ');
          }
        }
      }
      
      buffer.write(glyph.character);
      lastX = glyph.x + glyph.width;
      lastY = glyph.y;
    }
    
    return buffer.toString();
  }
  
  /// Obtém glifos em uma região
  List<RenderedGlyph> getGlyphsInRect(FxRect rect) {
    return _glyphs.where((g) {
      return g.x >= rect.left && g.x <= rect.right &&
             g.y >= rect.top && g.y <= rect.bottom;
    }).toList();
  }
  
  /// Obtém bounding box de todo o texto
  FxRect? getTextBounds() {
    if (_glyphs.isEmpty) return null;
    
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    
    for (final glyph in _glyphs) {
      if (glyph.x < minX) minX = glyph.x;
      if (glyph.y - glyph.fontSize < minY) minY = glyph.y - glyph.fontSize;
      if (glyph.x + glyph.width > maxX) maxX = glyph.x + glyph.width;
      if (glyph.y > maxY) maxY = glyph.y;
    }
    
    return FxRect(minX, minY, maxX, maxY);
  }
  
  /// Número de glifos
  int get glyphCount => _glyphs.length;
  
  /// Lista de glifos
  List<RenderedGlyph> get glyphs => List.unmodifiable(_glyphs);
}

/// Informações de linha de texto
class TextLine {
  final List<RenderedGlyph> glyphs;
  final FxRect bounds;
  
  TextLine(this.glyphs, this.bounds);
  
  String get text => glyphs.map((g) => g.character).join();
}

/// Segmentador de texto em linhas
class TextSegmenter {
  /// Segmenta glifos em linhas
  static List<TextLine> segmentIntoLines(List<RenderedGlyph> glyphs) {
    if (glyphs.isEmpty) return [];
    
    final lines = <TextLine>[];
    final sorted = List<RenderedGlyph>.from(glyphs);
    sorted.sort((a, b) {
      final yDiff = (a.y - b.y).round();
      if (yDiff.abs() > 5) return yDiff;
      return (a.x - b.x).round();
    });
    
    final currentLine = <RenderedGlyph>[];
    double? lineY;
    
    for (final glyph in sorted) {
      if (lineY != null && (glyph.y - lineY).abs() > glyph.fontSize * 0.5) {
        // Nova linha
        if (currentLine.isNotEmpty) {
          lines.add(_createLine(currentLine));
          currentLine.clear();
        }
      }
      
      currentLine.add(glyph);
      lineY = glyph.y;
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(_createLine(currentLine));
    }
    
    return lines;
  }
  
  static TextLine _createLine(List<RenderedGlyph> glyphs) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    
    for (final g in glyphs) {
      if (g.x < minX) minX = g.x;
      if (g.y - g.fontSize < minY) minY = g.y - g.fontSize;
      if (g.x + g.width > maxX) maxX = g.x + g.width;
      if (g.y > maxY) maxY = g.y;
    }
    
    return TextLine(List.from(glyphs), FxRect(minX, minY, maxX, maxY));
  }
}
