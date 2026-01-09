import '../fxcrt/fx_coordinates.dart';
import 'fx_dib.dart';

class CFX_RenderDevice {
  CFX_DIBitmap? _bitmap;
  int _width = 0;
  int _height = 0;
  bool _clipResult = true; // Simplified clip state

  int get width => _width;
  int get height => _height;
  CFX_DIBitmap? get bitmap => _bitmap;

  void setBitmap(CFX_DIBitmap bitmap) {
    _bitmap = bitmap;
    _width = bitmap.width;
    _height = bitmap.height;
    // Reset state
  }
  
  // Basic drawing operations (Device Coordinates)
  void fillRect(FxRect rect, int color) {
    if (_bitmap == null) return;
    // Coordinate conversion or direct?
    // Usually Rect is int or fixed point for device.
    // FxRect is generally int? No, FxRect is likely generic or double based on previous files.
    // fx_dib methods operate on int coordinates usually.
    
    // Simplification:
    _bitmap!.compositeRect(
      rect.left.round(), 
      rect.top.round(), 
      rect.width.round(), 
      rect.height.round(), 
      color
    );
  }
  
  // TODO: Add Path drawing, Text drawing interfaces
}
