import '../fxcrt/fx_coordinates.dart';
import '../fpdfapi/page/pdf_page.dart';
import '../fpdfapi/page/pdf_page_object.dart';

enum CharType { normal, generated, notUnicode, hyphen, piece }

class CharInfo {
  CharType charType;
  int charCode;
  int unicode;
  FxPointF origin;
  FxRect charBox;
  FxMatrix matrix;
  PdfTextObject? textObject;

  CharInfo({
    this.charType = CharType.normal,
    this.charCode = 0,
    this.unicode = 0,
    required this.origin,
    required this.charBox,
    required this.matrix,
    this.textObject,
  });
}

class PdfTextPage {
  final PdfPage page;
  final List<CharInfo> _charList = [];
  String _textBuf = '';

  PdfTextPage(this.page) {
    _parseTextPage();
  }

  void _parseTextPage() {
    _charList.clear();
    final buffer = StringBuffer();
    
    for (final obj in page.objects) {
      if (obj is PdfTextObject) {
         final text = obj.text;
         final matrix = obj.matrix;
         final fontSize = obj.fontSize;
         final font = obj.font;
         
         for (int i = 0; i < text.length; i++) {
            final charCode = text.codeUnitAt(i);
            
            // Unicode mapping
            int unicode = charCode;
            if (font != null) {
                final u = font.getUnicode(charCode);
                if (u != null) unicode = u;
            }
            
            FxPoint origin = obj.position; 
            if (obj.charPositions.length > i) {
               origin = obj.charPositions[i];
            }
            
            double charWidth = 0;
            if (font != null) {
                charWidth = font.getCharWidth(charCode) / 1000.0 * fontSize;
            } else {
                charWidth = fontSize * 0.5; // Fallback
            }
            
            // Box approximate (Horizontal LTR)
            // PDF Y is up
            final charBox = FxRect(
                origin.x, 
                origin.y, // Bottom (Baseline)
                origin.x + charWidth, 
                origin.y + fontSize // Top
            );
            
            _charList.add(CharInfo(
                charType: CharType.normal,
                charCode: charCode,
                unicode: unicode,
                origin: FxPointF(origin.x, origin.y),
                charBox: charBox,
                matrix: matrix,
                textObject: obj
            ));
            
            if (unicode != 0) {
              buffer.writeCharCode(unicode);
            }
         }
      }
    }
    _textBuf = buffer.toString();
  }

  int countChars() => _charList.length;

  int charIndexFromTextIndex(int textIndex) {
    // Handle synthetic chars (hyphens, line breaks) mapping
    return textIndex; // Simplified
  }

  int textIndexFromCharIndex(int charIndex) {
    return charIndex; // Simplified
  }

  String getText(int start, [int count = -1]) {
    if (start < 0) start = 0;
    if (count < 0) count = _charList.length - start;
    
    // In strict PDFium this constructs string from CharInfo list
    // handling generated characters.
    // For now we assume _textBuf is populated.
    if (start >= _textBuf.length) return '';
    int end = start + count;
    if (end > _textBuf.length) end = _textBuf.length;
    return _textBuf.substring(start, end);
  }
  
  List<FxRect> getRectArray(int start, int count) {
    List<FxRect> rects = [];
    if (start < 0 || count <= 0) return rects;
    if (start + count > _charList.length) count = _charList.length - start;

    for (int i = 0; i < count; i++) {
        int index = start + i;
        if (index >= _charList.length) break;
        rects.add(_charList[index].charBox);
    }
    return rects; 
  }
  
  // Search support
  int getIndexAtPos(FxPointF point, double tolerance) {
    // Linear search or quadtree
    return -1;
  }
}
