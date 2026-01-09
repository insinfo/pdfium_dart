/// Device Independent Bitmap
/// 
/// Port of core/fxge/fx_dib.h

import 'dart:typed_data';

import '../fxcrt/fx_coordinates.dart';
import '../fxcrt/fx_types.dart';

/// ARGB Color representation
class FxColor {
  final int value;
  
  const FxColor(this.value);
  
  /// Create from ARGB components
  const FxColor.fromARGB(int a, int r, int g, int b)
      : value = ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | 
                ((g & 0xFF) << 8) | (b & 0xFF);
  
  /// Create from RGB with full opacity
  const FxColor.fromRGB(int r, int g, int b)
      : value = 0xFF000000 | ((r & 0xFF) << 16) | 
                ((g & 0xFF) << 8) | (b & 0xFF);
  
  /// Common colors
  static const transparent = FxColor(0x00000000);
  static const black = FxColor(0xFF000000);
  static const white = FxColor(0xFFFFFFFF);
  static const colorRed = FxColor(0xFFFF0000);
  static const colorGreen = FxColor(0xFF00FF00);
  static const colorBlue = FxColor(0xFF0000FF);
  
  int get alpha => (value >> 24) & 0xFF;
  int get r => (value >> 16) & 0xFF;
  int get g => (value >> 8) & 0xFF;
  int get b => value & 0xFF;
  
  // Aliases for compatibility
  int get red => r;
  int get green => g;
  int get blue => b;
  
  /// Convert to BGR (for bitmap storage)
  int get bgr => (b << 16) | (g << 8) | r;
  
  /// Convert to BGRA (for bitmap storage)
  int get bgra => (alpha << 24) | (b << 16) | (g << 8) | r;
  
  /// Blend with another color using alpha
  FxColor blend(FxColor other, int blendAlpha) {
    final a = blendAlpha / 255.0;
    final oneMinusA = 1.0 - a;
    
    return FxColor.fromARGB(
      255,
      (r * oneMinusA + other.r * a).round(),
      (g * oneMinusA + other.g * a).round(),
      (b * oneMinusA + other.b * a).round(),
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FxColor && value == other.value;
  
  @override
  int get hashCode => value.hashCode;
  
  @override
  String toString() => 'FxColor(0x${value.toRadixString(16).padLeft(8, '0')})';
}

/// Device Independent Bitmap
/// 
/// Equivalent to CFX_DIBitmap in PDFium
class FxDIBitmap {
  final int _width;
  final int _height;
  final BitmapFormat _format;
  final Uint8List _buffer;
  final int _pitch; // Bytes per row (may include padding)
  
  FxDIBitmap._(this._width, this._height, this._format, this._buffer, this._pitch);
  
  /// Create a new bitmap
  factory FxDIBitmap(int width, int height, BitmapFormat format) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid bitmap dimensions: $width x $height');
    }
    
    final bytesPerPixel = format.bytesPerPixel;
    if (bytesPerPixel == 0) {
      throw ArgumentError('Invalid bitmap format: $format');
    }
    
    // Calculate pitch (row stride) with 4-byte alignment
    final pitch = ((width * bytesPerPixel + 3) ~/ 4) * 4;
    final bufferSize = pitch * height;
    
    return FxDIBitmap._(
      width,
      height,
      format,
      Uint8List(bufferSize),
      pitch,
    );
  }
  
  /// Create a bitmap from existing data
  factory FxDIBitmap.fromData(int width, int height, BitmapFormat format, Uint8List data) {
    final bytesPerPixel = format.bytesPerPixel;
    final pitch = ((width * bytesPerPixel + 3) ~/ 4) * 4;
    
    if (data.length < pitch * height) {
      throw ArgumentError('Data buffer too small');
    }
    
    return FxDIBitmap._(width, height, format, data, pitch);
  }
  
  /// Width in pixels
  int get width => _width;
  
  /// Height in pixels
  int get height => _height;
  
  /// Pixel format
  BitmapFormat get format => _format;
  
  /// Bytes per row
  int get pitch => _pitch;
  
  /// Total buffer size
  int get bufferSize => _buffer.length;
  
  /// Bytes per pixel
  int get bytesPerPixel => _format.bytesPerPixel;
  
  /// Raw buffer access
  Uint8List get buffer => _buffer;
  
  /// Get size
  FxSizeInt get size => FxSizeInt(_width, _height);
  
  /// Clear bitmap with a color
  void clear(FxColor color) {
    switch (_format) {
      case BitmapFormat.gray:
        final gray = (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114).round();
        _buffer.fillRange(0, _buffer.length, gray);
        break;
        
      case BitmapFormat.bgr:
        for (var y = 0; y < _height; y++) {
          var offset = y * _pitch;
          for (var x = 0; x < _width; x++) {
            _buffer[offset++] = color.blue;
            _buffer[offset++] = color.green;
            _buffer[offset++] = color.red;
          }
        }
        break;
        
      case BitmapFormat.bgrx:
      case BitmapFormat.bgra:
        for (var y = 0; y < _height; y++) {
          var offset = y * _pitch;
          for (var x = 0; x < _width; x++) {
            _buffer[offset++] = color.blue;
            _buffer[offset++] = color.green;
            _buffer[offset++] = color.red;
            _buffer[offset++] = color.alpha;
          }
        }
        break;
        
      default:
        break;
    }
  }
  
  /// Get pixel color at position
  FxColor getPixel(int x, int y) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return FxColor.transparent;
    }
    
    final offset = y * _pitch + x * bytesPerPixel;
    
    switch (_format) {
      case BitmapFormat.gray:
        final gray = _buffer[offset];
        return FxColor.fromRGB(gray, gray, gray);
        
      case BitmapFormat.bgr:
        return FxColor.fromRGB(
          _buffer[offset + 2],
          _buffer[offset + 1],
          _buffer[offset],
        );
        
      case BitmapFormat.bgrx:
        return FxColor.fromRGB(
          _buffer[offset + 2],
          _buffer[offset + 1],
          _buffer[offset],
        );
        
      case BitmapFormat.bgra:
        return FxColor.fromARGB(
          _buffer[offset + 3],
          _buffer[offset + 2],
          _buffer[offset + 1],
          _buffer[offset],
        );
        
      default:
        return FxColor.transparent;
    }
  }
  
  /// Set pixel color at position
  void setPixel(int x, int y, FxColor color) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return;
    }
    
    final offset = y * _pitch + x * bytesPerPixel;
    
    switch (_format) {
      case BitmapFormat.gray:
        _buffer[offset] = (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114).round();
        break;
        
      case BitmapFormat.bgr:
        _buffer[offset] = color.blue;
        _buffer[offset + 1] = color.green;
        _buffer[offset + 2] = color.red;
        break;
        
      case BitmapFormat.bgrx:
        _buffer[offset] = color.blue;
        _buffer[offset + 1] = color.green;
        _buffer[offset + 2] = color.red;
        _buffer[offset + 3] = 255;
        break;
        
      case BitmapFormat.bgra:
        _buffer[offset] = color.blue;
        _buffer[offset + 1] = color.green;
        _buffer[offset + 2] = color.red;
        _buffer[offset + 3] = color.alpha;
        break;
        
      default:
        break;
    }
  }
  
  /// Get grayscale value at position (for gray bitmaps or converted)
  int getPixelGray(int x, int y) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return 0;
    }
    
    final offset = y * _pitch + x * bytesPerPixel;
    
    switch (_format) {
      case BitmapFormat.gray:
        return _buffer[offset];
        
      case BitmapFormat.bgr:
        // Convert BGR to grayscale
        return (((_buffer[offset + 2] * 299) + 
                 (_buffer[offset + 1] * 587) + 
                 (_buffer[offset] * 114)) ~/ 1000);
        
      case BitmapFormat.bgrx:
      case BitmapFormat.bgra:
        // Convert BGRA to grayscale
        return (((_buffer[offset + 2] * 299) + 
                 (_buffer[offset + 1] * 587) + 
                 (_buffer[offset] * 114)) ~/ 1000);
        
      default:
        return 0;
    }
  }
  
  /// Set grayscale value at position (for gray bitmaps)
  void setPixelGray(int x, int y, int gray) {
    if (x < 0 || x >= _width || y < 0 || y >= _height) {
      return;
    }
    
    final offset = y * _pitch + x * bytesPerPixel;
    final g = gray.clamp(0, 255);
    
    switch (_format) {
      case BitmapFormat.gray:
        _buffer[offset] = g;
        break;
        
      case BitmapFormat.bgr:
        _buffer[offset] = g;
        _buffer[offset + 1] = g;
        _buffer[offset + 2] = g;
        break;
        
      case BitmapFormat.bgrx:
      case BitmapFormat.bgra:
        _buffer[offset] = g;
        _buffer[offset + 1] = g;
        _buffer[offset + 2] = g;
        _buffer[offset + 3] = 255;
        break;
        
      default:
        break;
    }
  }
  
  /// Draw a filled rectangle
  void fillRect(FxRectInt rect, FxColor color) {
    final left = rect.left.clamp(0, _width);
    final top = rect.top.clamp(0, _height);
    final right = rect.right.clamp(0, _width);
    final bottom = rect.bottom.clamp(0, _height);
    
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        setPixel(x, y, color);
      }
    }
  }
  
  /// Draw a line
  void drawLine(int x1, int y1, int x2, int y2, FxColor color) {
    // Bresenham's line algorithm
    var dx = (x2 - x1).abs();
    var dy = -(y2 - y1).abs();
    var sx = x1 < x2 ? 1 : -1;
    var sy = y1 < y2 ? 1 : -1;
    var err = dx + dy;
    
    var x = x1;
    var y = y1;
    
    while (true) {
      setPixel(x, y, color);
      
      if (x == x2 && y == y2) break;
      
      var e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y += sy;
      }
    }
  }
  
  /// Copy a region from another bitmap
  void copyFrom(FxDIBitmap source, int destX, int destY, {FxRectInt? sourceRect}) {
    final srcRect = sourceRect ?? FxRectInt(0, 0, source.width, source.height);
    
    for (var sy = srcRect.top; sy < srcRect.bottom; sy++) {
      final dy = destY + sy - srcRect.top;
      if (dy < 0 || dy >= _height) continue;
      
      for (var sx = srcRect.left; sx < srcRect.right; sx++) {
        final dx = destX + sx - srcRect.left;
        if (dx < 0 || dx >= _width) continue;
        
        setPixel(dx, dy, source.getPixel(sx, sy));
      }
    }
  }
  
  /// Convert to RGB byte array (for export)
  Uint8List toRgbBytes() {
    final result = Uint8List(_width * _height * 3);
    var i = 0;
    
    for (var y = 0; y < _height; y++) {
      for (var x = 0; x < _width; x++) {
        final color = getPixel(x, y);
        result[i++] = color.red;
        result[i++] = color.green;
        result[i++] = color.blue;
      }
    }
    
    return result;
  }
  
  /// Convert to RGBA byte array (for export)
  Uint8List toRgbaBytes() {
    final result = Uint8List(_width * _height * 4);
    var i = 0;
    
    for (var y = 0; y < _height; y++) {
      for (var x = 0; x < _width; x++) {
        final color = getPixel(x, y);
        result[i++] = color.red;
        result[i++] = color.green;
        result[i++] = color.blue;
        result[i++] = color.alpha;
      }
    }
    
    return result;
  }
  
  @override
  String toString() => 'FxDIBitmap($_width x $_height, $_format)';
}

/// Bitmap stretch options
enum StretchMode {
  /// No interpolation
  none,
  /// Linear interpolation
  linear,
  /// Bicubic interpolation
  bicubic,
}

/// Extension for bitmap operations
extension FxDIBitmapOps on FxDIBitmap {
  /// Create a scaled copy of the bitmap
  FxDIBitmap scale(int newWidth, int newHeight, {StretchMode mode = StretchMode.linear}) {
    final result = FxDIBitmap(newWidth, newHeight, format);
    
    final scaleX = width / newWidth;
    final scaleY = height / newHeight;
    
    for (var y = 0; y < newHeight; y++) {
      for (var x = 0; x < newWidth; x++) {
        final srcX = (x * scaleX).floor();
        final srcY = (y * scaleY).floor();
        result.setPixel(x, y, getPixel(srcX, srcY));
      }
    }
    
    return result;
  }
  
  /// Create a rotated copy (90, 180, or 270 degrees)
  FxDIBitmap rotate(PageRotation rotation) {
    switch (rotation) {
      case PageRotation.none:
        return this;
        
      case PageRotation.rotate90:
        final result = FxDIBitmap(height, width, format);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            result.setPixel(height - 1 - y, x, getPixel(x, y));
          }
        }
        return result;
        
      case PageRotation.rotate180:
        final result = FxDIBitmap(width, height, format);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            result.setPixel(width - 1 - x, height - 1 - y, getPixel(x, y));
          }
        }
        return result;
        
      case PageRotation.rotate270:
        final result = FxDIBitmap(height, width, format);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            result.setPixel(y, width - 1 - x, getPixel(x, y));
          }
        }
        return result;
    }
  }
}
