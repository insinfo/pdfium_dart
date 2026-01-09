// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// PNG Decoder
/// 
/// Port of libpng decoder functionality.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'png_types.dart';
import 'png_filter.dart';

// ==========================================================
//   PNG Result
// ==========================================================

/// Result of PNG operations
class PngResult<T> {
  final T? value;
  final String? error;

  PngResult.success(this.value) : error = null;
  PngResult.failure(this.error) : value = null;

  bool get isSuccess => error == null;
}

// ==========================================================
//   PNG Image
// ==========================================================

/// Decoded PNG image
class PngImage {
  /// Image width
  final int width;

  /// Image height
  final int height;

  /// Bit depth (1, 2, 4, 8, or 16)
  final int bitDepth;

  /// Color type
  final int colorType;

  /// Interlace method
  final int interlaceMethod;

  /// Pixel data (organized by rows)
  final Uint8List data;

  /// Palette (for indexed color)
  final List<int>? palette;

  /// Transparency data
  final Uint8List? transparency;

  /// Gamma value (if present)
  final double? gamma;

  /// ICC profile (if present)
  final Uint8List? iccProfile;

  /// Background color (if present)
  final List<int>? backgroundColor;

  PngImage({
    required this.width,
    required this.height,
    required this.bitDepth,
    required this.colorType,
    required this.interlaceMethod,
    required this.data,
    this.palette,
    this.transparency,
    this.gamma,
    this.iccProfile,
    this.backgroundColor,
  });

  /// Number of color channels
  int get numChannels => PngColorType.numChannels(colorType);

  /// Whether image has alpha
  bool get hasAlpha => PngColorType.hasAlpha(colorType) || transparency != null;

  /// Bytes per pixel (at bit depth)
  int get bytesPerPixel {
    final channels = numChannels;
    if (bitDepth == 16) {
      return channels * 2;
    }
    return channels;
  }

  /// Converts to 8-bit RGB pixels
  Uint8List toRgb() {
    final rgb = Uint8List(width * height * 3);
    _convertToRgb(rgb, false);
    return rgb;
  }

  /// Converts to 8-bit RGBA pixels
  Uint8List toRgba() {
    final rgba = Uint8List(width * height * 4);
    _convertToRgb(rgba, true);
    return rgba;
  }

  void _convertToRgb(Uint8List output, bool includeAlpha) {
    final outChannels = includeAlpha ? 4 : 3;

    switch (colorType) {
      case PngColorType.grayscale:
        _grayscaleToRgb(output, outChannels);
        break;

      case PngColorType.rgb:
        _rgbToOutput(output, outChannels);
        break;

      case PngColorType.indexed:
        _indexedToRgb(output, outChannels);
        break;

      case PngColorType.grayscaleAlpha:
        _grayscaleAlphaToRgb(output, outChannels);
        break;

      case PngColorType.rgba:
        _rgbaToOutput(output, outChannels);
        break;
    }
  }

  void _grayscaleToRgb(Uint8List output, int outChannels) {
    final hasTransparency = transparency != null && transparency!.length >= 2;
    final transGray = hasTransparency
        ? (bitDepth == 16
            ? (transparency![0] << 8) | transparency![1]
            : transparency![1])
        : -1;

    int srcIdx = 0;
    int dstIdx = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int gray;
        if (bitDepth == 16) {
          gray = (data[srcIdx] << 8) | data[srcIdx + 1];
          gray = gray >> 8; // Convert to 8-bit
          srcIdx += 2;
        } else if (bitDepth == 8) {
          gray = data[srcIdx++];
        } else {
          // Sub-byte depths (1, 2, 4)
          final bitsPerRow = width * bitDepth;
          final bytesPerRow = (bitsPerRow + 7) ~/ 8;
          final byteIdx = y * bytesPerRow + (x * bitDepth) ~/ 8;
          final bitOffset = 8 - bitDepth - ((x * bitDepth) % 8);
          gray = (data[byteIdx] >> bitOffset) & ((1 << bitDepth) - 1);
          gray = (gray * 255) ~/ ((1 << bitDepth) - 1);
          srcIdx = (y + 1) * bytesPerRow; // Skip to next row
        }

        output[dstIdx++] = gray;
        output[dstIdx++] = gray;
        output[dstIdx++] = gray;
        if (outChannels == 4) {
          output[dstIdx++] = (gray == transGray) ? 0 : 255;
        }
      }
    }
  }

  void _rgbToOutput(Uint8List output, int outChannels) {
    final hasTransparency = transparency != null && transparency!.length >= 6;
    int transR = -1, transG = -1, transB = -1;
    if (hasTransparency) {
      if (bitDepth == 16) {
        transR = (transparency![0] << 8) | transparency![1];
        transG = (transparency![2] << 8) | transparency![3];
        transB = (transparency![4] << 8) | transparency![5];
      } else {
        transR = transparency![1];
        transG = transparency![3];
        transB = transparency![5];
      }
    }

    int srcIdx = 0;
    int dstIdx = 0;

    for (int i = 0; i < width * height; i++) {
      int r, g, b;
      if (bitDepth == 16) {
        r = (data[srcIdx] << 8) | data[srcIdx + 1];
        g = (data[srcIdx + 2] << 8) | data[srcIdx + 3];
        b = (data[srcIdx + 4] << 8) | data[srcIdx + 5];
        final isTransparent =
            hasTransparency && r == transR && g == transG && b == transB;
        r = r >> 8;
        g = g >> 8;
        b = b >> 8;
        srcIdx += 6;
        output[dstIdx++] = r;
        output[dstIdx++] = g;
        output[dstIdx++] = b;
        if (outChannels == 4) {
          output[dstIdx++] = isTransparent ? 0 : 255;
        }
      } else {
        r = data[srcIdx++];
        g = data[srcIdx++];
        b = data[srcIdx++];
        final isTransparent =
            hasTransparency && r == transR && g == transG && b == transB;
        output[dstIdx++] = r;
        output[dstIdx++] = g;
        output[dstIdx++] = b;
        if (outChannels == 4) {
          output[dstIdx++] = isTransparent ? 0 : 255;
        }
      }
    }
  }

  void _indexedToRgb(Uint8List output, int outChannels) {
    if (palette == null) return;

    int srcIdx = 0;
    int dstIdx = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int index;
        if (bitDepth == 8) {
          index = data[srcIdx++];
        } else {
          // Sub-byte depths
          final bitsPerRow = width * bitDepth;
          final bytesPerRow = (bitsPerRow + 7) ~/ 8;
          final byteIdx = y * bytesPerRow + (x * bitDepth) ~/ 8;
          final bitOffset = 8 - bitDepth - ((x * bitDepth) % 8);
          index = (data[byteIdx] >> bitOffset) & ((1 << bitDepth) - 1);
        }

        if (index * 3 + 2 < palette!.length) {
          output[dstIdx++] = palette![index * 3];
          output[dstIdx++] = palette![index * 3 + 1];
          output[dstIdx++] = palette![index * 3 + 2];
        } else {
          output[dstIdx++] = 0;
          output[dstIdx++] = 0;
          output[dstIdx++] = 0;
        }

        if (outChannels == 4) {
          if (transparency != null && index < transparency!.length) {
            output[dstIdx++] = transparency![index];
          } else {
            output[dstIdx++] = 255;
          }
        }
      }
      if (bitDepth < 8) {
        srcIdx = ((y + 1) * width * bitDepth + 7) ~/ 8;
      }
    }
  }

  void _grayscaleAlphaToRgb(Uint8List output, int outChannels) {
    int srcIdx = 0;
    int dstIdx = 0;

    for (int i = 0; i < width * height; i++) {
      int gray, alpha;
      if (bitDepth == 16) {
        gray = (data[srcIdx] << 8) | data[srcIdx + 1];
        alpha = (data[srcIdx + 2] << 8) | data[srcIdx + 3];
        gray = gray >> 8;
        alpha = alpha >> 8;
        srcIdx += 4;
      } else {
        gray = data[srcIdx++];
        alpha = data[srcIdx++];
      }

      output[dstIdx++] = gray;
      output[dstIdx++] = gray;
      output[dstIdx++] = gray;
      if (outChannels == 4) {
        output[dstIdx++] = alpha;
      }
    }
  }

  void _rgbaToOutput(Uint8List output, int outChannels) {
    int srcIdx = 0;
    int dstIdx = 0;

    for (int i = 0; i < width * height; i++) {
      int r, g, b, a;
      if (bitDepth == 16) {
        r = (data[srcIdx] << 8) | data[srcIdx + 1];
        g = (data[srcIdx + 2] << 8) | data[srcIdx + 3];
        b = (data[srcIdx + 4] << 8) | data[srcIdx + 5];
        a = (data[srcIdx + 6] << 8) | data[srcIdx + 7];
        r = r >> 8;
        g = g >> 8;
        b = b >> 8;
        a = a >> 8;
        srcIdx += 8;
      } else {
        r = data[srcIdx++];
        g = data[srcIdx++];
        b = data[srcIdx++];
        a = data[srcIdx++];
      }

      output[dstIdx++] = r;
      output[dstIdx++] = g;
      output[dstIdx++] = b;
      if (outChannels == 4) {
        output[dstIdx++] = a;
      }
    }
  }
}

// ==========================================================
//   PNG Decoder State
// ==========================================================

class _PngDecoderState {
  // IHDR info
  int width = 0;
  int height = 0;
  int bitDepth = 0;
  int colorType = 0;
  int compressionMethod = 0;
  int filterMethod = 0;
  int interlaceMethod = 0;

  // Chunks
  List<int>? palette;
  Uint8List? transparency;
  double? gamma;
  Uint8List? iccProfile;
  List<int>? backgroundColor;

  // Compressed data
  final idatData = <int>[];

  // Error
  String? errorMessage;
}

// ==========================================================
//   PNG Decoder
// ==========================================================

/// PNG image decoder
class PngDecoder {
  final _PngDecoderState _state = _PngDecoderState();

  /// Decodes PNG data
  PngResult<PngImage> decode(Uint8List data) {
    if (data.length < 8) {
      return PngResult.failure('Data too short for PNG');
    }

    // Check signature
    for (int i = 0; i < 8; i++) {
      if (data[i] != pngSignature[i]) {
        return PngResult.failure('Invalid PNG signature');
      }
    }

    int offset = 8;

    // Read chunks
    while (offset < data.length) {
      if (offset + 12 > data.length) {
        break; // Not enough data for chunk header + CRC
      }

      // Read chunk length (big-endian)
      final length = (data[offset] << 24) |
          (data[offset + 1] << 16) |
          (data[offset + 2] << 8) |
          data[offset + 3];
      offset += 4;

      // Read chunk type
      final type = (data[offset] << 24) |
          (data[offset + 1] << 16) |
          (data[offset + 2] << 8) |
          data[offset + 3];
      offset += 4;

      // Read chunk data
      if (offset + length + 4 > data.length) {
        break; // Not enough data
      }

      final chunkData = Uint8List.sublistView(data, offset, offset + length);
      offset += length;

      // Skip CRC (we could verify it)
      offset += 4;

      // Process chunk
      switch (type) {
        case PngChunk.ihdr:
          if (!_readIhdr(chunkData)) {
            return PngResult.failure(
                _state.errorMessage ?? 'Failed to read IHDR');
          }
          break;

        case PngChunk.plte:
          _readPlte(chunkData);
          break;

        case PngChunk.idat:
          _state.idatData.addAll(chunkData);
          break;

        case PngChunk.iend:
          // End of image
          break;

        case PngChunk.trns:
          _readTrns(chunkData);
          break;

        case PngChunk.gama:
          _readGama(chunkData);
          break;

        case PngChunk.iccp:
          _readIccp(chunkData);
          break;

        case PngChunk.bkgd:
          _readBkgd(chunkData);
          break;

        // Skip other chunks
      }

      if (type == PngChunk.iend) break;
    }

    // Decompress and unfilter image data
    final imageData = _decompressAndUnfilter();
    if (imageData == null) {
      return PngResult.failure(
          _state.errorMessage ?? 'Failed to decompress image data');
    }

    return PngResult.success(PngImage(
      width: _state.width,
      height: _state.height,
      bitDepth: _state.bitDepth,
      colorType: _state.colorType,
      interlaceMethod: _state.interlaceMethod,
      data: imageData,
      palette: _state.palette,
      transparency: _state.transparency,
      gamma: _state.gamma,
      iccProfile: _state.iccProfile,
      backgroundColor: _state.backgroundColor,
    ));
  }

  /// Reads IHDR chunk
  bool _readIhdr(Uint8List data) {
    if (data.length < 13) {
      _state.errorMessage = 'IHDR chunk too short';
      return false;
    }

    _state.width = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
    _state.height =
        (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
    _state.bitDepth = data[8];
    _state.colorType = data[9];
    _state.compressionMethod = data[10];
    _state.filterMethod = data[11];
    _state.interlaceMethod = data[12];

    // Validate
    if (_state.width <= 0 || _state.height <= 0) {
      _state.errorMessage = 'Invalid image dimensions';
      return false;
    }

    if (_state.compressionMethod != 0) {
      _state.errorMessage =
          'Unsupported compression method: ${_state.compressionMethod}';
      return false;
    }

    if (_state.filterMethod != 0) {
      _state.errorMessage = 'Unsupported filter method: ${_state.filterMethod}';
      return false;
    }

    return true;
  }

  /// Reads PLTE chunk
  void _readPlte(Uint8List data) {
    _state.palette = List<int>.from(data);
  }

  /// Reads tRNS chunk
  void _readTrns(Uint8List data) {
    _state.transparency = Uint8List.fromList(data);
  }

  /// Reads gAMA chunk
  void _readGama(Uint8List data) {
    if (data.length >= 4) {
      final gamma =
          (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      _state.gamma = gamma / 100000.0;
    }
  }

  /// Reads iCCP chunk
  void _readIccp(Uint8List data) {
    // Find null terminator for profile name
    int nullIdx = data.indexOf(0);
    if (nullIdx < 0 || nullIdx + 2 >= data.length) return;

    // Skip profile name and compression method
    final compressedProfile = Uint8List.sublistView(data, nullIdx + 2);

    // Decompress profile
    try {
      _state.iccProfile = Uint8List.fromList(zlib.decode(compressedProfile));
    } catch (e) {
      // Ignore ICC profile errors
    }
  }

  /// Reads bKGD chunk
  void _readBkgd(Uint8List data) {
    _state.backgroundColor = List<int>.from(data);
  }

  /// Decompresses IDAT data and unfilters
  Uint8List? _decompressAndUnfilter() {
    if (_state.idatData.isEmpty) {
      _state.errorMessage = 'No IDAT chunks found';
      return null;
    }

    // Decompress
    Uint8List decompressed;
    try {
      decompressed = Uint8List.fromList(zlib.decode(_state.idatData));
    } catch (e) {
      _state.errorMessage = 'Failed to decompress: $e';
      return null;
    }

    if (_state.interlaceMethod == PngInterlace.adam7) {
      return _unfilterAdam7(decompressed);
    } else {
      return _unfilterNonInterlaced(decompressed);
    }
  }

  /// Unfilters non-interlaced image
  Uint8List? _unfilterNonInterlaced(Uint8List compressed) {
    final channels = PngColorType.numChannels(_state.colorType);
    final bitsPerPixel = _state.bitDepth * channels;
    final bytesPerPixel = (bitsPerPixel + 7) ~/ 8;
    final scanlineBytes = (_state.width * bitsPerPixel + 7) ~/ 8;

    final output = Uint8List(scanlineBytes * _state.height);
    Uint8List? previousRow;

    int srcIdx = 0;

    for (int y = 0; y < _state.height; y++) {
      if (srcIdx >= compressed.length) {
        _state.errorMessage = 'Unexpected end of compressed data';
        return null;
      }

      // Filter type byte
      final filterType = compressed[srcIdx++];

      // Current row
      if (srcIdx + scanlineBytes > compressed.length) {
        _state.errorMessage = 'Incomplete scanline';
        return null;
      }

      final currentRow = Uint8List(scanlineBytes);
      currentRow.setRange(0, scanlineBytes, compressed, srcIdx);
      srcIdx += scanlineBytes;

      // Unfilter
      PngFilters.unfilterRow(filterType, currentRow, previousRow, bytesPerPixel);

      // Copy to output
      output.setRange(y * scanlineBytes, (y + 1) * scanlineBytes, currentRow);

      previousRow = currentRow;
    }

    return output;
  }

  /// Unfilters Adam7 interlaced image
  Uint8List? _unfilterAdam7(Uint8List compressed) {
    final channels = PngColorType.numChannels(_state.colorType);
    final bitsPerPixel = _state.bitDepth * channels;
    final bytesPerPixel = (bitsPerPixel + 7) ~/ 8;

    // Final output
    final scanlineBytes = (_state.width * bitsPerPixel + 7) ~/ 8;
    final output = Uint8List(scanlineBytes * _state.height);

    int srcIdx = 0;

    // Process each pass
    for (int pass = 0; pass < 7; pass++) {
      final (passWidth, passHeight) =
          adam7PassDimensions(pass, _state.width, _state.height);

      if (passWidth == 0 || passHeight == 0) continue;

      final passScanlineBytes = (passWidth * bitsPerPixel + 7) ~/ 8;
      Uint8List? previousRow;

      for (int y = 0; y < passHeight; y++) {
        if (srcIdx >= compressed.length) {
          _state.errorMessage = 'Unexpected end of compressed data in pass';
          return null;
        }

        final filterType = compressed[srcIdx++];

        if (srcIdx + passScanlineBytes > compressed.length) {
          _state.errorMessage = 'Incomplete scanline in pass';
          return null;
        }

        final currentRow = Uint8List(passScanlineBytes);
        currentRow.setRange(0, passScanlineBytes, compressed, srcIdx);
        srcIdx += passScanlineBytes;

        PngFilters.unfilterRow(
            filterType, currentRow, previousRow, bytesPerPixel);

        // Scatter pixels to output
        _scatterAdam7Row(output, scanlineBytes, currentRow, pass, y, bitsPerPixel);

        previousRow = currentRow;
      }
    }

    return output;
  }

  /// Scatters Adam7 pass row to final image
  void _scatterAdam7Row(
    Uint8List output,
    int outputScanlineBytes,
    Uint8List passRow,
    int pass,
    int passY,
    int bitsPerPixel,
  ) {
    final p = adam7Passes[pass];
    final destY = p.yStart + passY * p.yStep;

    if (destY >= _state.height) return;

    final bytesPerPixel = (bitsPerPixel + 7) ~/ 8;
    final (passWidth, _) = adam7PassDimensions(pass, _state.width, _state.height);

    for (int passX = 0; passX < passWidth; passX++) {
      final destX = p.xStart + passX * p.xStep;
      if (destX >= _state.width) continue;

      // Copy pixel
      if (bitsPerPixel >= 8) {
        final srcOffset = passX * bytesPerPixel;
        final destOffset = destY * outputScanlineBytes + destX * bytesPerPixel;
        for (int b = 0; b < bytesPerPixel; b++) {
          output[destOffset + b] = passRow[srcOffset + b];
        }
      } else {
        // Sub-byte pixels
        final srcBitOffset = passX * bitsPerPixel;
        final srcByteOffset = srcBitOffset ~/ 8;
        final srcBitShift = 8 - bitsPerPixel - (srcBitOffset % 8);
        final pixel =
            (passRow[srcByteOffset] >> srcBitShift) & ((1 << bitsPerPixel) - 1);

        final destBitOffset = destX * bitsPerPixel;
        final destByteOffset = destY * outputScanlineBytes + destBitOffset ~/ 8;
        final destBitShift = 8 - bitsPerPixel - (destBitOffset % 8);

        output[destByteOffset] =
            (output[destByteOffset] & ~(((1 << bitsPerPixel) - 1) << destBitShift)) |
                (pixel << destBitShift);
      }
    }
  }
}

// ==========================================================
//   Utility Functions
// ==========================================================

/// Checks if data appears to be a PNG
bool isPng(Uint8List data) {
  if (data.length < 8) return false;
  for (int i = 0; i < 8; i++) {
    if (data[i] != pngSignature[i]) return false;
  }
  return true;
}

/// Decodes PNG data to an image
PngResult<PngImage> decodePng(Uint8List data) {
  return PngDecoder().decode(data);
}
