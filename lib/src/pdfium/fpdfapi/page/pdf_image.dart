

/// PDF Image handling
/// 
/// Port of core/fpdfapi/page/cpdf_image.h and cpdf_dib.h

import 'dart:typed_data';

import '../../fxcrt/fx_coordinates.dart';
import '../../fxcrt/fx_types.dart' show BitmapFormat;
import '../../fxge/fx_dib.dart' show FxColor, FxDIBitmap;
import '../parser/pdf_array.dart';
import '../parser/pdf_dictionary.dart';
import '../parser/pdf_name.dart';
import '../parser/pdf_stream.dart';
import 'colorspace.dart';

/// Tipo de compressão de imagem
enum ImageCompression {
  none,
  flate,        // FlateDecode
  lzw,          // LZWDecode
  runLength,    // RunLengthDecode
  ccittFax,     // CCITTFaxDecode
  jbig2,        // JBIG2Decode
  dct,          // DCTDecode (JPEG)
  jpx,          // JPXDecode (JPEG2000)
  ascii85,      // ASCII85Decode
  asciiHex,     // ASCIIHexDecode
}

/// Representa uma imagem PDF
/// 
/// Equivalent to CPDF_Image in PDFium
class PdfImage {
  final PdfStream _stream;
  final PdfDictionary _dict;
  
  int _width = 0;
  int _height = 0;
  int _bitsPerComponent = 8;
  bool _isMask = false;
  bool _interpolate = false;
  FxColor? _matteColor;
  PdfColorSpace? _colorSpace;
  FxDIBitmap? _bitmap;
  FxDIBitmap? _mask;
  
  /// Create from stream
  PdfImage(this._stream) : _dict = _stream.dict {
    _parseImageDict();
  }
  
  /// Create inline image from dictionary and data
  PdfImage.inline(this._dict, Uint8List data) 
      : _stream = PdfStream(_dict, data) {
    _parseImageDict();
  }
  
  void _parseImageDict() {
    _width = _dict.getInt('Width', _dict.getInt('W', 0));
    _height = _dict.getInt('Height', _dict.getInt('H', 0));
    _bitsPerComponent = _dict.getInt('BitsPerComponent', _dict.getInt('BPC', 8));
    _isMask = _dict.getBool('ImageMask', _dict.getBool('IM', false));
    _interpolate = _dict.getBool('Interpolate', _dict.getBool('I', false));
    
    // Parse colorspace
    final csObj = _dict.get('ColorSpace') ?? _dict.get('CS');
    if (csObj != null && !_isMask) {
      _colorSpace = PdfColorSpace.fromPdfObject(csObj);
    }
    
    // Parse matte color for soft mask
    final matteArray = _dict.getArray('Matte');
    if (matteArray != null && matteArray.length >= 3) {
      _matteColor = FxColor.fromRGB(
        (matteArray.getNumberAt(0) * 255).round(),
        (matteArray.getNumberAt(1) * 255).round(),
        (matteArray.getNumberAt(2) * 255).round(),
      );
    }
  }
  
  /// Image width in pixels
  int get width => _width;
  
  /// Image height in pixels
  int get height => _height;
  
  /// Bits per component
  int get bitsPerComponent => _bitsPerComponent;
  
  /// Is this a mask image
  bool get isMask => _isMask;
  
  /// Should interpolation be used
  bool get interpolate => _interpolate;
  
  /// Matte color for soft mask
  FxColor? get matteColor => _matteColor;
  
  /// Color space
  PdfColorSpace? get colorSpace => _colorSpace;
  
  /// Stream dictionary
  PdfDictionary get dict => _dict;
  
  /// Get compression type
  ImageCompression get compression {
    final filters = _stream.filters;
    if (filters.isEmpty) return ImageCompression.none;
    
    final lastFilter = filters.last;
    switch (lastFilter) {
      case 'FlateDecode':
      case 'Fl':
        return ImageCompression.flate;
      case 'LZWDecode':
      case 'LZW':
        return ImageCompression.lzw;
      case 'RunLengthDecode':
      case 'RL':
        return ImageCompression.runLength;
      case 'CCITTFaxDecode':
      case 'CCF':
        return ImageCompression.ccittFax;
      case 'JBIG2Decode':
        return ImageCompression.jbig2;
      case 'DCTDecode':
      case 'DCT':
        return ImageCompression.dct;
      case 'JPXDecode':
        return ImageCompression.jpx;
      case 'ASCII85Decode':
      case 'A85':
        return ImageCompression.ascii85;
      case 'ASCIIHexDecode':
      case 'AHx':
        return ImageCompression.asciiHex;
      default:
        return ImageCompression.none;
    }
  }
  
  /// Load and decode image to bitmap
  FxDIBitmap? loadBitmap() {
    if (_bitmap != null) return _bitmap;
    
    try {
      final data = _stream.decodedData;
      
      if (_isMask) {
        _bitmap = _loadMaskImage(data);
      } else if (compression == ImageCompression.dct) {
        _bitmap = _loadJpegImage(data);
      } else if (compression == ImageCompression.jpx) {
        _bitmap = _loadJpxImage(data);
      } else {
        _bitmap = _loadRawImage(data);
      }
      
      // Load soft mask if present
      final smask = _dict.getStream('SMask');
      if (smask != null) {
        final maskImage = PdfImage(smask);
        _mask = maskImage.loadBitmap();
      }
      
      return _bitmap;
    } catch (e) {
      print('Error loading image: $e');
      return null;
    }
  }
  
  /// Get mask bitmap
  FxDIBitmap? get mask => _mask;
  
  FxDIBitmap _loadMaskImage(Uint8List data) {
    final bitmap = FxDIBitmap(_width, _height, BitmapFormat.gray);
    final pitch = bitmap.pitch;
    
    final srcBytesPerRow = (_width * _bitsPerComponent + 7) ~/ 8;
    
    for (int y = 0; y < _height; y++) {
      final srcRow = y * srcBytesPerRow;
      final dstRow = y * pitch;
      
      if (_bitsPerComponent == 1) {
        // 1-bit mask
        for (int x = 0; x < _width; x++) {
          if (srcRow + (x >> 3) < data.length) {
            final bit = (data[srcRow + (x >> 3)] >> (7 - (x & 7))) & 1;
            bitmap.buffer[dstRow + x] = bit == 1 ? 0xFF : 0x00;
          }
        }
      } else if (_bitsPerComponent == 8) {
        // 8-bit mask
        for (int x = 0; x < _width; x++) {
          if (srcRow + x < data.length) {
            bitmap.buffer[dstRow + x] = data[srcRow + x];
          }
        }
      }
    }
    
    return bitmap;
  }
  
  FxDIBitmap? _loadJpegImage(Uint8List data) {
    // JPEG decoding would require a JPEG decoder library
    // For now, return raw data wrapped in DIB
    // TODO: Implement proper JPEG decoding
    
    // This is a placeholder - in production, use a JPEG decoder
    final bitmap = FxDIBitmap(_width, _height, BitmapFormat.bgr);
    _fillPlaceholder(bitmap, const FxColor.fromRGB(200, 200, 200));
    return bitmap;
  }
  
  FxDIBitmap? _loadJpxImage(Uint8List data) {
    // JPEG 2000 decoding would require a JPX decoder library
    // For now, return placeholder
    // TODO: Implement proper JPEG 2000 decoding
    
    final bitmap = FxDIBitmap(_width, _height, BitmapFormat.bgr);
    _fillPlaceholder(bitmap, const FxColor.fromRGB(180, 180, 200));
    return bitmap;
  }
  
  FxDIBitmap _loadRawImage(Uint8List data) {
    final components = _colorSpace?.componentCount ?? 1;
    BitmapFormat format;
    
    if (_isMask || _colorSpace?.type == ColorSpaceType.deviceGray) {
      format = BitmapFormat.gray;
    } else if (components == 3) {
      format = BitmapFormat.bgr;
    } else if (components == 4) {
      format = BitmapFormat.bgra;
    } else {
      format = BitmapFormat.gray;
    }
    
    final bitmap = FxDIBitmap(_width, _height, format);
    
    // Decode based on bits per component and color space
    if (_bitsPerComponent == 8 && components == 3) {
      _decodeRgb8(data, bitmap);
    } else if (_bitsPerComponent == 8 && components == 4) {
      _decodeCmyk8(data, bitmap);
    } else if (_bitsPerComponent == 8 && components == 1) {
      _decodeGray8(data, bitmap);
    } else if (_bitsPerComponent == 1) {
      _decode1Bit(data, bitmap);
    } else if (_bitsPerComponent == 4) {
      _decode4Bit(data, bitmap);
    } else {
      // Generic decode
      _decodeGeneric(data, bitmap, components);
    }
    
    return bitmap;
  }
  
  void _decodeRgb8(Uint8List src, FxDIBitmap dst) {
    final pitch = dst.pitch;
    final srcPitch = _width * 3;
    
    for (int y = 0; y < _height; y++) {
      final srcRow = y * srcPitch;
      final dstRow = y * pitch;
      
      for (int x = 0; x < _width; x++) {
        final srcIdx = srcRow + x * 3;
        final dstIdx = dstRow + x * 3;
        
        if (srcIdx + 2 < src.length && dstIdx + 2 < dst.buffer.length) {
          dst.buffer[dstIdx] = src[srcIdx];       // R
          dst.buffer[dstIdx + 1] = src[srcIdx + 1]; // G
          dst.buffer[dstIdx + 2] = src[srcIdx + 2]; // B
        }
      }
    }
  }
  
  void _decodeCmyk8(Uint8List src, FxDIBitmap dst) {
    final pitch = dst.pitch;
    final srcPitch = _width * 4;
    
    for (int y = 0; y < _height; y++) {
      final srcRow = y * srcPitch;
      final dstRow = y * pitch;
      
      for (int x = 0; x < _width; x++) {
        final srcIdx = srcRow + x * 4;
        final dstIdx = dstRow + x * 4;
        
        if (srcIdx + 3 < src.length && dstIdx + 3 < dst.buffer.length) {
          // CMYK to BGRA conversion
          final c = src[srcIdx];
          final m = src[srcIdx + 1];
          final yy = src[srcIdx + 2];
          final k = src[srcIdx + 3];
          
          // Convert CMYK to RGB
          final r = 255 - _min(255, c + k);
          final g = 255 - _min(255, m + k);
          final b = 255 - _min(255, yy + k);
          
          dst.buffer[dstIdx] = b;       // B
          dst.buffer[dstIdx + 1] = g;   // G
          dst.buffer[dstIdx + 2] = r;   // R
          dst.buffer[dstIdx + 3] = 255; // A
        }
      }
    }
  }
  
  void _decodeGray8(Uint8List src, FxDIBitmap dst) {
    final pitch = dst.pitch;
    
    for (int y = 0; y < _height; y++) {
      final srcRow = y * _width;
      final dstRow = y * pitch;
      
      for (int x = 0; x < _width; x++) {
        if (srcRow + x < src.length && dstRow + x < dst.buffer.length) {
          dst.buffer[dstRow + x] = src[srcRow + x];
        }
      }
    }
  }
  
  void _decode1Bit(Uint8List src, FxDIBitmap dst) {
    final pitch = dst.pitch;
    final srcBytesPerRow = (_width + 7) ~/ 8;
    
    for (int y = 0; y < _height; y++) {
      final srcRow = y * srcBytesPerRow;
      final dstRow = y * pitch;
      
      for (int x = 0; x < _width; x++) {
        final srcIdx = srcRow + (x >> 3);
        if (srcIdx < src.length) {
          final bit = (src[srcIdx] >> (7 - (x & 7))) & 1;
          dst.buffer[dstRow + x] = bit == 1 ? 0xFF : 0x00;
        }
      }
    }
  }
  
  void _decode4Bit(Uint8List src, FxDIBitmap dst) {
    final pitch = dst.pitch;
    final srcBytesPerRow = (_width + 1) ~/ 2;
    
    for (int y = 0; y < _height; y++) {
      final srcRow = y * srcBytesPerRow;
      final dstRow = y * pitch;
      
      for (int x = 0; x < _width; x++) {
        final srcIdx = srcRow + (x >> 1);
        if (srcIdx < src.length) {
          int value;
          if ((x & 1) == 0) {
            value = (src[srcIdx] >> 4) & 0x0F;
          } else {
            value = src[srcIdx] & 0x0F;
          }
          dst.buffer[dstRow + x] = (value * 255) ~/ 15;
        }
      }
    }
  }
  
  void _decodeGeneric(Uint8List src, FxDIBitmap dst, int components) {
    // Generic decoder for other bit depths
    final pitch = dst.pitch;
    final maxValue = (1 << _bitsPerComponent) - 1;
    
    int srcBit = 0;
    int srcByte = 0;
    
    for (int y = 0; y < _height; y++) {
      final dstRow = y * pitch;
      
      for (int x = 0; x < _width; x++) {
        for (int c = 0; c < components; c++) {
          // Read value
          int value = 0;
          for (int b = 0; b < _bitsPerComponent; b++) {
            if (srcByte < src.length) {
              final bit = (src[srcByte] >> (7 - srcBit)) & 1;
              value = (value << 1) | bit;
              srcBit++;
              if (srcBit >= 8) {
                srcBit = 0;
                srcByte++;
              }
            }
          }
          
          // Scale to 8-bit
          final scaled = (value * 255) ~/ maxValue;
          final dstIdx = dstRow + x * components + c;
          if (dstIdx < dst.buffer.length) {
            dst.buffer[dstIdx] = scaled;
          }
        }
      }
      
      // Align to byte boundary at end of row
      if (srcBit > 0) {
        srcBit = 0;
        srcByte++;
      }
    }
  }
  
  void _fillPlaceholder(FxDIBitmap bitmap, FxColor color) {
    bitmap.clear(color);
  }
  
  int _min(int a, int b) => a < b ? a : b;
  
  /// Get raw decoded image data
  Uint8List get decodedData => _stream.decodedData;
  
  /// Get image bounds
  FxRect get bounds => FxRect(0, 0, _width.toDouble(), _height.toDouble());
  
  @override
  String toString() => 'PdfImage(${_width}x$_height, $compression)';
}

/// Image mask types
enum MaskType {
  none,
  colorKey,
  softMask,
  hardMask,
}

/// Color key mask definition
class ColorKeyMask {
  final List<int> mins;
  final List<int> maxs;
  
  const ColorKeyMask(this.mins, this.maxs);
  
  /// Check if a color matches the mask
  bool matches(List<int> components) {
    if (components.length != mins.length) return false;
    
    for (int i = 0; i < components.length; i++) {
      if (components[i] < mins[i] || components[i] > maxs[i]) {
        return false;
      }
    }
    return true;
  }
  
  /// Parse from PDF array [min1 max1 min2 max2 ...]
  factory ColorKeyMask.fromArray(PdfArray array) {
    final mins = <int>[];
    final maxs = <int>[];
    
    for (int i = 0; i < array.length; i += 2) {
      mins.add(array.getIntAt(i));
      maxs.add(array.getIntAt(i + 1));
    }
    
    return ColorKeyMask(mins, maxs);
  }
}

/// Decode parameters for image filters
class ImageDecodeParams {
  final double min;
  final double max;
  
  const ImageDecodeParams(this.min, this.max);
  
  /// Apply decode to a value
  double apply(double normalized) {
    return min + normalized * (max - min);
  }
  
  /// Parse from PDF array
  static List<ImageDecodeParams> fromArray(PdfArray array) {
    final result = <ImageDecodeParams>[];
    
    for (int i = 0; i < array.length; i += 2) {
      result.add(ImageDecodeParams(
        array.getNumberAt(i),
        array.getNumberAt(i + 1),
      ));
    }
    
    return result;
  }
}
