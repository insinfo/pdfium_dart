import '../fxcrt/fx_coordinates.dart';
import '../fpdfapi/font/pdf_font.dart';
import 'fx_dib.dart';

class CFX_RenderDevice {
  FxDIBitmap? _bitmap;
  int _width = 0;
  int _height = 0;

  int get width => _width;
  int get height => _height;
  FxDIBitmap? get bitmap => _bitmap;

  void setBitmap(FxDIBitmap bitmap) {
    _bitmap = bitmap;
    _width = bitmap.width;
    _height = bitmap.height;
    // Reset state
  }
  
  // Basic drawing operations (Device Coordinates)
  void fillRect(FxRect rect, int color) {
    if (_bitmap == null) return;
    
    // Convert FxRect (double) to FxRectInt
    final rectInt = FxRectInt(
        rect.left.round(), 
        rect.top.round(), 
        rect.right.round(), 
        rect.bottom.round()
    );
    
    final colorObj = FxColor(color);
    _bitmap!.fillRect(rectInt, colorObj);
  }

  void drawChar(PdfFont font, int charCode, FxMatrix matrix, int color) {
    if (_bitmap == null) return;
    
    // Calculate approximate bounds of the glyph in device space
    final origin = matrix.transformPoint(const FxPoint(0, 0));
    
    // Let's just draw a small box at origin
    final x = origin.x.round();
    final y = origin.y.round();
    
    // Draw 2x2 dot
    final dotRect = FxRectInt(x, y - 2, x + 2, y);
    
    _bitmap!.fillRect(dotRect, FxColor(color));
  }
}
