// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG Baseline Decoder
/// 
/// Port of libjpeg baseline decoder functionality.
library;

import 'dart:typed_data';

import 'jpeg_types.dart';
import 'jpeg_bitreader.dart';
import 'jpeg_idct.dart';
import 'jpeg_color.dart';

// ==========================================================
//   JPEG Decoder Result
// ==========================================================

/// Result of JPEG decoding
class JpegResult<T> {
  final T? value;
  final String? error;

  JpegResult.success(this.value) : error = null;
  JpegResult.failure(this.error) : value = null;

  bool get isSuccess => error == null;
}

/// Decoded JPEG image
class JpegImage {
  /// Image width
  final int width;

  /// Image height
  final int height;

  /// Number of components
  final int numComponents;

  /// Color space
  final JpegColorSpace colorSpace;

  /// Component data (one Uint8List per component)
  final List<Uint8List> components;

  /// Bits per sample
  final int bitsPerSample;

  JpegImage({
    required this.width,
    required this.height,
    required this.numComponents,
    required this.colorSpace,
    required this.components,
    this.bitsPerSample = 8,
  });

  /// Converts to RGB pixels
  Uint8List toRgb() {
    final rgb = Uint8List(width * height * 3);

    switch (colorSpace) {
      case JpegColorSpace.grayscale:
        JpegColorConvert.grayscaleToRgb(components[0], rgb, width * height);
        break;

      case JpegColorSpace.ycbcr:
        if (numComponents >= 3) {
          JpegColorConvert.ycbcrToRgb(
            components[0],
            components[1],
            components[2],
            rgb,
            width * height,
          );
        }
        break;

      case JpegColorSpace.rgb:
        // Copy directly
        for (int i = 0, j = 0; i < width * height; i++, j += 3) {
          rgb[j + 0] = components[0][i];
          rgb[j + 1] = components[1][i];
          rgb[j + 2] = components[2][i];
        }
        break;

      case JpegColorSpace.cmyk:
        if (numComponents >= 4) {
          JpegColorConvert.cmykToRgb(
            components[0],
            components[1],
            components[2],
            components[3],
            rgb,
            width * height,
          );
        }
        break;

      case JpegColorSpace.ycck:
        if (numComponents >= 4) {
          JpegColorConvert.ycckToRgb(
            components[0],
            components[1],
            components[2],
            components[3],
            rgb,
            width * height,
          );
        }
        break;

      default:
        // Assume RGB-like
        if (numComponents >= 3) {
          for (int i = 0, j = 0; i < width * height; i++, j += 3) {
            rgb[j + 0] = components[0][i];
            rgb[j + 1] = components[1][i];
            rgb[j + 2] = components[2][i];
          }
        } else if (numComponents == 1) {
          JpegColorConvert.grayscaleToRgb(components[0], rgb, width * height);
        }
    }

    return rgb;
  }

  /// Converts to RGBA pixels
  Uint8List toRgba() {
    final rgba = Uint8List(width * height * 4);

    switch (colorSpace) {
      case JpegColorSpace.grayscale:
        JpegColorConvert.grayscaleToRgba(components[0], rgba, width * height);
        break;

      case JpegColorSpace.ycbcr:
        if (numComponents >= 3) {
          JpegColorConvert.ycbcrToRgba(
            components[0],
            components[1],
            components[2],
            rgba,
            width * height,
          );
        }
        break;

      default:
        final rgb = toRgb();
        for (int i = 0, j = 0; i < width * height; i++, j += 4) {
          rgba[j + 0] = rgb[i * 3 + 0];
          rgba[j + 1] = rgb[i * 3 + 1];
          rgba[j + 2] = rgb[i * 3 + 2];
          rgba[j + 3] = 255;
        }
    }

    return rgba;
  }
}

// ==========================================================
//   JPEG Decoder State
// ==========================================================

class _JpegDecoderState {
  // Image dimensions
  int width = 0;
  int height = 0;
  int precision = 8;

  // Components
  List<JpegComponentInfo> components = [];
  int numComponents = 0;

  // Quantization tables
  List<JpegQuantTable?> quantTables = List.filled(jpegNumQuantTables, null);

  // Huffman tables
  List<JpegHuffTable?> dcHuffTables = List.filled(jpegNumHuffTables, null);
  List<JpegHuffTable?> acHuffTables = List.filled(jpegNumHuffTables, null);

  // Scan parameters
  List<int> scanComponentIndex = [];
  int ss = 0; // Spectral selection start
  int se = 63; // Spectral selection end
  int ah = 0; // Successive approximation high
  int al = 0; // Successive approximation low

  // MCU parameters
  int maxHSampFactor = 1;
  int maxVSampFactor = 1;
  int mcuWidth = 0;
  int mcuHeight = 0;
  int mcusPerRow = 0;
  int mcuRows = 0;

  // Restart interval
  int restartInterval = 0;

  // Color space
  JpegColorSpace colorSpace = JpegColorSpace.unknown;
  bool adobeTransform = false;
  int adobeTransformCode = 0;

  // Decoded component data
  List<Uint8List> componentData = [];

  // DC prediction values
  List<int> dcPred = [];

  // Error message
  String? errorMessage;
}

// ==========================================================
//   JPEG Baseline Decoder
// ==========================================================

/// Baseline JPEG decoder
class JpegDecoder {
  final _JpegDecoderState _state = _JpegDecoderState();

  /// Decodes JPEG data
  JpegResult<JpegImage> decode(Uint8List data) {
    final reader = JpegBitReader(data);

    // Read SOI marker
    final soi = reader.readUint16BE();
    if (soi != JpegMarker.soi) {
      return JpegResult.failure('Invalid JPEG: Missing SOI marker');
    }

    // Read markers until SOS
    while (true) {
      final marker = reader.readUint16BE();

      if (marker == JpegMarker.eoi) {
        return JpegResult.failure('Unexpected EOI marker');
      }

      if (marker == JpegMarker.sos) {
        // Read SOS segment
        if (!_readSos(reader)) {
          return JpegResult.failure(_state.errorMessage ?? 'Failed to read SOS');
        }
        break;
      }

      if (marker == JpegMarker.sof0 || marker == JpegMarker.sof1) {
        // Baseline or extended sequential DCT
        if (!_readSof(reader, marker)) {
          return JpegResult.failure(_state.errorMessage ?? 'Failed to read SOF');
        }
      } else if (marker == JpegMarker.sof2) {
        return JpegResult.failure('Progressive JPEG not supported');
      } else if (marker == JpegMarker.dht) {
        if (!_readDht(reader)) {
          return JpegResult.failure(_state.errorMessage ?? 'Failed to read DHT');
        }
      } else if (marker == JpegMarker.dqt) {
        if (!_readDqt(reader)) {
          return JpegResult.failure(_state.errorMessage ?? 'Failed to read DQT');
        }
      } else if (marker == JpegMarker.dri) {
        if (!_readDri(reader)) {
          return JpegResult.failure(_state.errorMessage ?? 'Failed to read DRI');
        }
      } else if (JpegMarker.isApp(marker)) {
        if (!_readApp(reader, marker)) {
          return JpegResult.failure(_state.errorMessage ?? 'Failed to read APP');
        }
      } else if (marker == JpegMarker.com) {
        // Skip comment
        final len = reader.readUint16BE();
        reader.skip(len - 2);
      } else if ((marker & 0xFFF0) == 0xFFF0) {
        // Skip reserved markers
        final len = reader.readUint16BE();
        reader.skip(len - 2);
      } else if (marker != 0xFF00 && marker != 0xFFFF) {
        // Unknown marker with length
        if ((marker & 0xFF00) == 0xFF00) {
          final len = reader.readUint16BE();
          reader.skip(len - 2);
        }
      }
    }

    // Decode entropy-coded data
    if (!_decodeData(reader)) {
      return JpegResult.failure(_state.errorMessage ?? 'Failed to decode data');
    }

    // Create output image
    return JpegResult.success(JpegImage(
      width: _state.width,
      height: _state.height,
      numComponents: _state.numComponents,
      colorSpace: _state.colorSpace,
      components: _state.componentData,
    ));
  }

  /// Reads SOF (Start of Frame) marker
  bool _readSof(JpegBitReader reader, int marker) {
    final length = reader.readUint16BE();
    if (length < 8) {
      _state.errorMessage = 'Invalid SOF length';
      return false;
    }

    _state.precision = reader.readByte();
    _state.height = reader.readUint16BE();
    _state.width = reader.readUint16BE();
    _state.numComponents = reader.readByte();

    if (_state.numComponents < 1 || _state.numComponents > 4) {
      _state.errorMessage = 'Invalid number of components: ${_state.numComponents}';
      return false;
    }

    if (length != 8 + _state.numComponents * 3) {
      _state.errorMessage = 'Invalid SOF segment length';
      return false;
    }

    _state.components = [];
    _state.maxHSampFactor = 1;
    _state.maxVSampFactor = 1;

    for (int i = 0; i < _state.numComponents; i++) {
      final id = reader.readByte();
      final sampling = reader.readByte();
      final quantTable = reader.readByte();

      final comp = JpegComponentInfo(
        componentId: id,
        componentIndex: i,
        hSampFactor: (sampling >> 4) & 0x0F,
        vSampFactor: sampling & 0x0F,
        quantTableNo: quantTable,
      );

      if (comp.hSampFactor > _state.maxHSampFactor) {
        _state.maxHSampFactor = comp.hSampFactor;
      }
      if (comp.vSampFactor > _state.maxVSampFactor) {
        _state.maxVSampFactor = comp.vSampFactor;
      }

      _state.components.add(comp);
    }

    // Calculate MCU dimensions
    _state.mcuWidth = _state.maxHSampFactor * 8;
    _state.mcuHeight = _state.maxVSampFactor * 8;
    _state.mcusPerRow = (_state.width + _state.mcuWidth - 1) ~/ _state.mcuWidth;
    _state.mcuRows = (_state.height + _state.mcuHeight - 1) ~/ _state.mcuHeight;

    // Calculate component dimensions
    for (final comp in _state.components) {
      comp.widthInBlocks = _state.mcusPerRow * comp.hSampFactor;
      comp.heightInBlocks = _state.mcuRows * comp.vSampFactor;
      comp.downsampledWidth = comp.widthInBlocks * 8;
      comp.downsampledHeight = comp.heightInBlocks * 8;
    }

    // Guess color space
    _guessColorSpace();

    return true;
  }

  /// Reads DHT (Define Huffman Table) marker
  bool _readDht(JpegBitReader reader) {
    var length = reader.readUint16BE() - 2;

    while (length > 0) {
      final info = reader.readByte();
      length--;

      final tableClass = (info >> 4) & 0x0F;
      final tableIndex = info & 0x0F;

      if (tableIndex >= jpegNumHuffTables) {
        _state.errorMessage = 'Invalid Huffman table index: $tableIndex';
        return false;
      }

      final table = JpegHuffTable();

      // Read bit counts
      int count = 0;
      for (int i = 1; i <= 16; i++) {
        table.bits[i] = reader.readByte();
        count += table.bits[i];
        length--;
      }

      // Read symbols
      for (int i = 0; i < count; i++) {
        table.huffVal[i] = reader.readByte();
        length--;
      }

      // Build derived tables
      table.buildDerived();

      // Store table
      if (tableClass == 0) {
        _state.dcHuffTables[tableIndex] = table;
      } else {
        _state.acHuffTables[tableIndex] = table;
      }
    }

    return true;
  }

  /// Reads DQT (Define Quantization Table) marker
  bool _readDqt(JpegBitReader reader) {
    var length = reader.readUint16BE() - 2;

    while (length > 0) {
      final info = reader.readByte();
      length--;

      final precision = (info >> 4) & 0x0F;
      final tableIndex = info & 0x0F;

      if (tableIndex >= jpegNumQuantTables) {
        _state.errorMessage = 'Invalid quantization table index: $tableIndex';
        return false;
      }

      final table = JpegQuantTable(precision: precision);

      if (precision == 0) {
        // 8-bit values
        for (int i = 0; i < 64; i++) {
          table.values[jpegZigzag[i]] = reader.readByte();
          length--;
        }
      } else {
        // 16-bit values
        for (int i = 0; i < 64; i++) {
          table.values[jpegZigzag[i]] = reader.readUint16BE();
          length -= 2;
        }
      }

      _state.quantTables[tableIndex] = table;
    }

    return true;
  }

  /// Reads DRI (Define Restart Interval) marker
  bool _readDri(JpegBitReader reader) {
    final length = reader.readUint16BE();
    if (length != 4) {
      _state.errorMessage = 'Invalid DRI length';
      return false;
    }

    _state.restartInterval = reader.readUint16BE();
    return true;
  }

  /// Reads APP (Application) marker
  bool _readApp(JpegBitReader reader, int marker) {
    final length = reader.readUint16BE();
    final dataLength = length - 2;

    if (marker == JpegMarker.app0 && dataLength >= 5) {
      // JFIF marker
      final id = reader.readBytes(5);
      if (id != null &&
          id[0] == 0x4A && // J
          id[1] == 0x46 && // F
          id[2] == 0x49 && // I
          id[3] == 0x46 && // F
          id[4] == 0x00) {
        // JFIF header - skip rest
        reader.skip(dataLength - 5);
        return true;
      }
      reader.skip(dataLength - 5);
    } else if (marker == JpegMarker.app14 && dataLength >= 12) {
      // Adobe marker
      final id = reader.readBytes(5);
      if (id != null &&
          id[0] == 0x41 && // A
          id[1] == 0x64 && // d
          id[2] == 0x6F && // o
          id[3] == 0x62 && // b
          id[4] == 0x65) {
        // e
        // Adobe header
        reader.skip(2); // Version
        reader.skip(2); // Flags0
        reader.skip(2); // Flags1
        _state.adobeTransformCode = reader.readByte();
        _state.adobeTransform = true;
        reader.skip(dataLength - 12);
        return true;
      }
      reader.skip(dataLength - 5);
    } else {
      reader.skip(dataLength);
    }

    return true;
  }

  /// Reads SOS (Start of Scan) marker
  bool _readSos(JpegBitReader reader) {
    final length = reader.readUint16BE();
    final numComponents = reader.readByte();

    if (numComponents < 1 || numComponents > 4) {
      _state.errorMessage = 'Invalid number of scan components';
      return false;
    }

    if (length != 6 + numComponents * 2) {
      _state.errorMessage = 'Invalid SOS segment length';
      return false;
    }

    _state.scanComponentIndex = [];

    for (int i = 0; i < numComponents; i++) {
      final id = reader.readByte();
      final tableSpec = reader.readByte();

      // Find component by ID
      int compIndex = -1;
      for (int j = 0; j < _state.components.length; j++) {
        if (_state.components[j].componentId == id) {
          compIndex = j;
          break;
        }
      }

      if (compIndex < 0) {
        _state.errorMessage = 'Component ID not found: $id';
        return false;
      }

      _state.components[compIndex].dcTableNo = (tableSpec >> 4) & 0x0F;
      _state.components[compIndex].acTableNo = tableSpec & 0x0F;
      _state.scanComponentIndex.add(compIndex);
    }

    _state.ss = reader.readByte(); // Spectral selection start
    _state.se = reader.readByte(); // Spectral selection end
    final approx = reader.readByte();
    _state.ah = (approx >> 4) & 0x0F;
    _state.al = approx & 0x0F;

    return true;
  }

  /// Guesses color space based on component count and markers
  void _guessColorSpace() {
    if (_state.numComponents == 1) {
      _state.colorSpace = JpegColorSpace.grayscale;
    } else if (_state.numComponents == 3) {
      if (_state.adobeTransform) {
        if (_state.adobeTransformCode == 0) {
          _state.colorSpace = JpegColorSpace.rgb;
        } else {
          _state.colorSpace = JpegColorSpace.ycbcr;
        }
      } else {
        // Default to YCbCr for 3-component images
        _state.colorSpace = JpegColorSpace.ycbcr;
      }
    } else if (_state.numComponents == 4) {
      if (_state.adobeTransform) {
        if (_state.adobeTransformCode == 0) {
          _state.colorSpace = JpegColorSpace.cmyk;
        } else {
          _state.colorSpace = JpegColorSpace.ycck;
        }
      } else {
        _state.colorSpace = JpegColorSpace.cmyk;
      }
    }
  }

  /// Decodes entropy-coded data
  bool _decodeData(JpegBitReader reader) {
    // Allocate component buffers
    _state.componentData = [];
    for (final comp in _state.components) {
      _state.componentData.add(Uint8List(comp.downsampledWidth * comp.downsampledHeight));
    }

    // Initialize DC predictions
    _state.dcPred = List.filled(_state.numComponents, 0);

    // Decode MCUs
    int mcuCount = 0;
    final rstInterval = _state.restartInterval;

    for (int mcuRow = 0; mcuRow < _state.mcuRows; mcuRow++) {
      for (int mcuCol = 0; mcuCol < _state.mcusPerRow; mcuCol++) {
        // Check for restart
        if (rstInterval > 0 && mcuCount > 0 && mcuCount % rstInterval == 0) {
          final expectedRst = JpegMarker.rst0 + ((mcuCount ~/ rstInterval - 1) % 8);
          reader.alignToByte();
          reader.checkRestartMarker(expectedRst);
          _state.dcPred.fillRange(0, _state.dcPred.length, 0);
        }

        // Decode all components in this MCU
        for (int compIdx = 0; compIdx < _state.scanComponentIndex.length; compIdx++) {
          final ci = _state.scanComponentIndex[compIdx];
          final comp = _state.components[ci];

          // Decode each block in the component's portion of the MCU
          for (int by = 0; by < comp.vSampFactor; by++) {
            for (int bx = 0; bx < comp.hSampFactor; bx++) {
              if (!_decodeBlock(reader, ci, mcuCol, mcuRow, bx, by)) {
                return false;
              }
            }
          }
        }

        mcuCount++;

        if (reader.reachedEoi) break;
      }
      if (reader.reachedEoi) break;
    }

    // Upsample components to full resolution
    _upsampleComponents();

    return true;
  }

  /// Decodes a single 8x8 block
  bool _decodeBlock(JpegBitReader reader, int compIndex, int mcuCol, int mcuRow, int bx, int by) {
    final comp = _state.components[compIndex];
    final quantTable = _state.quantTables[comp.quantTableNo];
    final dcTable = _state.dcHuffTables[comp.dcTableNo];
    final acTable = _state.acHuffTables[comp.acTableNo];

    if (quantTable == null || dcTable == null || acTable == null) {
      _state.errorMessage = 'Missing tables for component $compIndex';
      return false;
    }

    // Decode DCT coefficients
    final coef = Int16List(64);

    // DC coefficient
    final dcBits = reader.decodeHuffman(dcTable);
    if (dcBits > 0) {
      final dcDiff = reader.receive(dcBits);
      _state.dcPred[compIndex] += dcDiff;
    }
    coef[0] = _state.dcPred[compIndex];

    // AC coefficients
    int k = 1;
    while (k < 64) {
      final rs = reader.decodeHuffman(acTable);
      final r = (rs >> 4) & 0x0F; // Run length
      final s = rs & 0x0F; // Size

      if (s == 0) {
        if (r == 0) {
          // EOB - End of Block
          break;
        } else if (r == 15) {
          // ZRL - Zero Run Length (16 zeros)
          k += 16;
        } else {
          break;
        }
      } else {
        k += r;
        if (k >= 64) break;
        coef[k] = reader.receive(s);
        k++;
      }
    }

    // Calculate block position
    final blockX = mcuCol * comp.hSampFactor + bx;
    final blockY = mcuRow * comp.vSampFactor + by;
    final pixelX = blockX * 8;
    final pixelY = blockY * 8;

    // IDCT and store
    final output = _state.componentData[compIndex];
    final stride = comp.downsampledWidth;

    JpegIdct.idct8x8(
      coef,
      quantTable.values,
      output,
      pixelY * stride + pixelX,
      stride,
    );

    return true;
  }

  /// Upsamples components to full resolution
  void _upsampleComponents() {
    // Skip if all components have the same sampling
    bool needsUpsampling = false;
    for (final comp in _state.components) {
      if (comp.hSampFactor != _state.maxHSampFactor ||
          comp.vSampFactor != _state.maxVSampFactor) {
        needsUpsampling = true;
        break;
      }
    }

    if (!needsUpsampling) {
      // Just trim to actual dimensions
      for (int i = 0; i < _state.numComponents; i++) {
        final comp = _state.components[i];
        if (comp.downsampledWidth != _state.width || comp.downsampledHeight != _state.height) {
          final trimmed = Uint8List(_state.width * _state.height);
          final src = _state.componentData[i];
          for (int y = 0; y < _state.height; y++) {
            for (int x = 0; x < _state.width; x++) {
              trimmed[y * _state.width + x] = src[y * comp.downsampledWidth + x];
            }
          }
          _state.componentData[i] = trimmed;
        }
      }
      return;
    }

    // Upsample each component
    for (int i = 0; i < _state.numComponents; i++) {
      final comp = _state.components[i];
      final src = _state.componentData[i];

      // Calculate upsample factors
      final hFactor = _state.maxHSampFactor ~/ comp.hSampFactor;
      final vFactor = _state.maxVSampFactor ~/ comp.vSampFactor;

      if (hFactor == 1 && vFactor == 1) {
        // No upsampling needed, just trim
        if (comp.downsampledWidth != _state.width || comp.downsampledHeight != _state.height) {
          final trimmed = Uint8List(_state.width * _state.height);
          for (int y = 0; y < _state.height; y++) {
            for (int x = 0; x < _state.width; x++) {
              trimmed[y * _state.width + x] = src[y * comp.downsampledWidth + x];
            }
          }
          _state.componentData[i] = trimmed;
        }
        continue;
      }

      // Perform upsampling
      Uint8List upsampled;

      if (hFactor == 2 && vFactor == 2) {
        // 2x2 upsampling
        final fullWidth = comp.downsampledWidth * 2;
        final fullHeight = comp.downsampledHeight * 2;
        upsampled = Uint8List(fullWidth * fullHeight);
        JpegUpsample.upsample2x2(
          src,
          comp.downsampledWidth,
          comp.downsampledHeight,
          upsampled,
          fullWidth,
          fullHeight,
        );

        // Trim to actual dimensions
        final trimmed = Uint8List(_state.width * _state.height);
        for (int y = 0; y < _state.height; y++) {
          for (int x = 0; x < _state.width; x++) {
            trimmed[y * _state.width + x] = upsampled[y * fullWidth + x];
          }
        }
        _state.componentData[i] = trimmed;
      } else if (hFactor == 2 && vFactor == 1) {
        // 2x1 upsampling (horizontal only)
        final fullWidth = comp.downsampledWidth * 2;
        upsampled = Uint8List(fullWidth * comp.downsampledHeight);
        JpegUpsample.horizontal2x(
          src,
          comp.downsampledWidth,
          upsampled,
          fullWidth,
          comp.downsampledHeight,
        );

        // Trim
        final trimmed = Uint8List(_state.width * _state.height);
        for (int y = 0; y < _state.height; y++) {
          for (int x = 0; x < _state.width; x++) {
            trimmed[y * _state.width + x] = upsampled[y * fullWidth + x];
          }
        }
        _state.componentData[i] = trimmed;
      } else if (hFactor == 1 && vFactor == 2) {
        // 1x2 upsampling (vertical only)
        final fullHeight = comp.downsampledHeight * 2;
        upsampled = Uint8List(comp.downsampledWidth * fullHeight);
        JpegUpsample.vertical2x(
          src,
          comp.downsampledWidth,
          comp.downsampledHeight,
          upsampled,
          fullHeight,
        );

        // Trim
        final trimmed = Uint8List(_state.width * _state.height);
        for (int y = 0; y < _state.height; y++) {
          for (int x = 0; x < _state.width; x++) {
            trimmed[y * _state.width + x] = upsampled[y * comp.downsampledWidth + x];
          }
        }
        _state.componentData[i] = trimmed;
      } else {
        // Generic case - simple replication
        final trimmed = Uint8List(_state.width * _state.height);
        for (int y = 0; y < _state.height; y++) {
          final srcY = y ~/ vFactor;
          for (int x = 0; x < _state.width; x++) {
            final srcX = x ~/ hFactor;
            trimmed[y * _state.width + x] = src[srcY * comp.downsampledWidth + srcX];
          }
        }
        _state.componentData[i] = trimmed;
      }
    }
  }
}

// ==========================================================
//   Utility Functions
// ==========================================================

/// Checks if data appears to be a JPEG
bool isJpeg(Uint8List data) {
  if (data.length < 2) return false;
  return data[0] == 0xFF && data[1] == 0xD8;
}

/// Decodes JPEG data to an image
JpegResult<JpegImage> decodeJpeg(Uint8List data) {
  return JpegDecoder().decode(data);
}
