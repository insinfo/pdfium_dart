// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JP2 file format decoder.
/// 
/// Port of jp2.c from OpenJPEG library.
/// Implements reading of JP2 file format (ISO/IEC 15444-1 Annex I).
library;

import 'dart:typed_data';

import 'j2k_decoder.dart';
import 'openjpeg_codec.dart';
import 'openjpeg_image.dart';
import 'openjpeg_stream.dart';
import 'openjpeg_types.dart';

// ==========================================================
//   JP2 Box Reader
// ==========================================================

/// JP2 box structure
class Jp2BoxInfo {
  /// Box type (4-byte code)
  final int type;
  
  /// Box length (0 = to end of file, 1 = extended)
  final int length;
  
  /// Box data start position
  final int dataStart;
  
  /// Box data length
  final int dataLength;

  Jp2BoxInfo({
    required this.type,
    required this.length,
    required this.dataStart,
    required this.dataLength,
  });

  /// Type as string (4 chars)
  String get typeString {
    return String.fromCharCodes([
      (type >> 24) & 0xFF,
      (type >> 16) & 0xFF,
      (type >> 8) & 0xFF,
      type & 0xFF,
    ]);
  }
}

// ==========================================================
//   JP2 Decoder State
// ==========================================================

/// JP2 decoder state
class _Jp2State {
  /// Brand
  String brand = '';
  
  /// Minor version
  int minorVersion = 0;
  
  /// Compatibility list
  List<String> compatibilityList = [];
  
  /// Image header info
  int height = 0;
  int width = 0;
  int numComponents = 0;
  int bitsPerComponent = 0;
  int compressionType = 0;
  int unknownColorspace = 0;
  int ipr = 0;
  
  /// Color specification
  int colorSpecMethod = 0;
  int colorSpecPrecedence = 0;
  int colorSpecApprox = 0;
  OpjColorSpace colorSpace = OpjColorSpace.unspecified;
  Uint8List? iccProfile;
  
  /// Component definitions
  List<_Jp2ChannelDef>? channelDefinitions;
  
  /// Palette
  _Jp2Palette? palette;
  
  /// Component mapping
  List<_Jp2ComponentMap>? componentMapping;
  
  /// Resolution
  double captureResX = 0;
  double captureResY = 0;
  double displayResX = 0;
  double displayResY = 0;
  
  /// Codestream position
  int codestreamStart = 0;
  int codestreamLength = 0;
  
  /// Error
  String? errorMessage;
}

/// Channel definition
class _Jp2ChannelDef {
  int channel;
  int type; // 0=color, 1=opacity, 2=premultiplied opacity
  int association;

  _Jp2ChannelDef({
    this.channel = 0,
    this.type = 0,
    this.association = 0,
  });
}

/// Palette
class _Jp2Palette {
  int numEntries;
  int numColumns;
  List<int> signedFlags;
  List<int> bitDepths;
  List<List<int>> entries;

  _Jp2Palette({
    this.numEntries = 0,
    this.numColumns = 0,
    List<int>? signedFlags,
    List<int>? bitDepths,
    List<List<int>>? entries,
  })  : signedFlags = signedFlags ?? [],
        bitDepths = bitDepths ?? [],
        entries = entries ?? [];
}

/// Component mapping
class _Jp2ComponentMap {
  int component;
  int mappingType; // 0=direct, 1=palette
  int paletteColumn;

  _Jp2ComponentMap({
    this.component = 0,
    this.mappingType = 0,
    this.paletteColumn = 0,
  });
}

// ==========================================================
//   JP2 Decoder
// ==========================================================

/// JP2 file format decoder
class Jp2Decoder {
  final _Jp2State _state = _Jp2State();
  final OpjDecompressionParams params;
  OpjMessageCallback? onMessage;
  
  Jp2Decoder({OpjDecompressionParams? params})
      : params = params ?? OpjDecompressionParams();

  /// Decodes a JP2 file
  OpjResult<OpjImage> decode(Uint8List data) {
    final stream = OpjMemoryStream(data);
    
    // Read JP2 signature
    if (!_readSignature(stream)) {
      return OpjResult.failure(_state.errorMessage ?? 'Invalid JP2 signature');
    }

    // Read file type box
    if (!_readFileTypeBox(stream)) {
      return OpjResult.failure(_state.errorMessage ?? 'Invalid file type box');
    }

    // Read JP2 header box
    if (!_readJp2HeaderBox(stream)) {
      return OpjResult.failure(_state.errorMessage ?? 'Failed to read JP2 header');
    }

    // Find and read codestream
    if (!_findCodestream(stream)) {
      return OpjResult.failure(_state.errorMessage ?? 'Codestream not found');
    }

    // Extract codestream data
    final codestreamData = Uint8List.sublistView(
      data,
      _state.codestreamStart,
      _state.codestreamStart + _state.codestreamLength,
    );

    // Decode codestream using J2K decoder
    final j2kDecoder = J2kDecoder(params: params);
    j2kDecoder.onMessage = onMessage;
    
    final result = j2kDecoder.decode(codestreamData);
    if (!result.isSuccess) {
      return result;
    }

    // Apply JP2 color space info to image
    final image = result.value!;
    image.colorSpace = _state.colorSpace;
    
    // Copy ICC profile if present
    if (_state.iccProfile != null) {
      image.iccProfile = Uint8List.fromList(_state.iccProfile!);
    }

    // Apply palette mapping if present
    if (_state.palette != null && _state.componentMapping != null) {
      _applyPaletteMapping(image);
    }

    return OpjResult.success(image);
  }

  /// Reads JP2 signature box
  bool _readSignature(OpjMemoryStream stream) {
    // JP2 signature: 0x0000000C 6A502020 0D0A870A
    final len = stream.readUint32BE();
    final type = stream.readUint32BE();
    
    if (len != 12 || type != Jp2Box.jp) {
      _state.errorMessage = 'Invalid JP2 signature box';
      return false;
    }

    final sig = stream.readUint32BE();
    if (sig != 0x0D0A870A) {
      _state.errorMessage = 'Invalid JP2 signature';
      return false;
    }

    return true;
  }

  /// Reads file type box
  bool _readFileTypeBox(OpjMemoryStream stream) {
    final box = _readBox(stream);
    if (box == null || box.type != Jp2Box.ftyp) {
      _state.errorMessage = 'Missing file type box';
      return false;
    }

    // Read brand (4 bytes)
    _state.brand = _read4CharCode(stream);
    
    // Read minor version
    _state.minorVersion = stream.readUint32BE();

    // Read compatibility list
    final numCompat = (box.dataLength - 8) ~/ 4;
    _state.compatibilityList.clear();
    for (var i = 0; i < numCompat; i++) {
      _state.compatibilityList.add(_read4CharCode(stream));
    }

    return true;
  }

  /// Reads JP2 header superbox
  bool _readJp2HeaderBox(OpjMemoryStream stream) {
    final box = _readBox(stream);
    if (box == null || box.type != Jp2Box.jp2h) {
      _state.errorMessage = 'Missing JP2 header box';
      return false;
    }

    final headerEnd = stream.position + box.dataLength - 8;

    // Read sub-boxes
    while (stream.position < headerEnd) {
      final subBox = _readBox(stream);
      if (subBox == null) break;

      final boxEnd = stream.position + subBox.dataLength - 8;

      switch (subBox.type) {
        case Jp2Box.ihdr:
          if (!_readImageHeaderBox(stream, subBox)) return false;
          break;
        case Jp2Box.colr:
          if (!_readColorSpecBox(stream, subBox)) return false;
          break;
        case Jp2Box.cdef:
          if (!_readChannelDefBox(stream, subBox)) return false;
          break;
        case Jp2Box.pclr:
          if (!_readPaletteBox(stream, subBox)) return false;
          break;
        case Jp2Box.cmap:
          if (!_readComponentMapBox(stream, subBox)) return false;
          break;
        case Jp2Box.res:
          if (!_readResolutionBox(stream, subBox)) return false;
          break;
        default:
          // Skip unknown box
          break;
      }

      stream.seek(boxEnd);
    }

    return true;
  }

  /// Reads image header box
  bool _readImageHeaderBox(OpjMemoryStream stream, Jp2BoxInfo box) {
    _state.height = stream.readUint32BE();
    _state.width = stream.readUint32BE();
    _state.numComponents = stream.readUint16BE();
    _state.bitsPerComponent = stream.readByte();
    _state.compressionType = stream.readByte();
    _state.unknownColorspace = stream.readByte();
    _state.ipr = stream.readByte();

    if (_state.compressionType != 7) {
      _state.errorMessage = 'Unsupported compression type: ${_state.compressionType}';
      return false;
    }

    return true;
  }

  /// Reads color specification box
  bool _readColorSpecBox(OpjMemoryStream stream, Jp2BoxInfo box) {
    _state.colorSpecMethod = stream.readByte();
    _state.colorSpecPrecedence = stream.readByte();
    _state.colorSpecApprox = stream.readByte();

    if (_state.colorSpecMethod == 1) {
      // Enumerated color space
      final enumCS = stream.readUint32BE();
      switch (enumCS) {
        case 16: // sRGB
          _state.colorSpace = OpjColorSpace.srgb;
          break;
        case 17: // Grayscale
          _state.colorSpace = OpjColorSpace.gray;
          break;
        case 18: // sYCC
          _state.colorSpace = OpjColorSpace.sycc;
          break;
        case 12: // CMYK
          _state.colorSpace = OpjColorSpace.cmyk;
          break;
        default:
          _state.colorSpace = OpjColorSpace.unspecified;
      }
    } else if (_state.colorSpecMethod == 2) {
      // Restricted ICC profile
      final profileLen = box.dataLength - 3;
      if (profileLen > 0) {
        _state.iccProfile = stream.readBytes(profileLen);
      }
    }

    return true;
  }

  /// Reads channel definition box
  bool _readChannelDefBox(OpjMemoryStream stream, Jp2BoxInfo box) {
    final numDefs = stream.readUint16BE();
    _state.channelDefinitions = [];

    for (var i = 0; i < numDefs; i++) {
      final channel = stream.readUint16BE();
      final type = stream.readUint16BE();
      final assoc = stream.readUint16BE();
      
      _state.channelDefinitions!.add(_Jp2ChannelDef(
        channel: channel,
        type: type,
        association: assoc,
      ));
    }

    return true;
  }

  /// Reads palette box
  bool _readPaletteBox(OpjMemoryStream stream, Jp2BoxInfo box) {
    final numEntries = stream.readUint16BE();
    final numColumns = stream.readByte();

    final palette = _Jp2Palette(
      numEntries: numEntries,
      numColumns: numColumns,
    );

    // Read bit depths for each column
    for (var i = 0; i < numColumns; i++) {
      final b = stream.readByte();
      palette.signedFlags.add((b >> 7) & 1);
      palette.bitDepths.add((b & 0x7F) + 1);
    }

    // Read palette entries
    for (var i = 0; i < numEntries; i++) {
      final entry = <int>[];
      for (var j = 0; j < numColumns; j++) {
        final bits = palette.bitDepths[j];
        int value;
        if (bits <= 8) {
          value = stream.readByte();
        } else {
          value = stream.readUint16BE();
        }
        entry.add(value);
      }
      palette.entries.add(entry);
    }

    _state.palette = palette;
    return true;
  }

  /// Reads component mapping box
  bool _readComponentMapBox(OpjMemoryStream stream, Jp2BoxInfo box) {
    final numMappings = (box.dataLength - 8) ~/ 4;
    _state.componentMapping = [];

    for (var i = 0; i < numMappings; i++) {
      final comp = stream.readUint16BE();
      final mtyp = stream.readByte();
      final pcol = stream.readByte();
      
      _state.componentMapping!.add(_Jp2ComponentMap(
        component: comp,
        mappingType: mtyp,
        paletteColumn: pcol,
      ));
    }

    return true;
  }

  /// Reads resolution box
  bool _readResolutionBox(OpjMemoryStream stream, Jp2BoxInfo box) {
    final boxEnd = stream.position + box.dataLength - 8;

    while (stream.position < boxEnd) {
      final subBox = _readBox(stream);
      if (subBox == null) break;

      if (subBox.type == Jp2Box.resc) {
        // Capture resolution
        final vrN = stream.readUint16BE();
        final vrD = stream.readUint16BE();
        final hrN = stream.readUint16BE();
        final hrD = stream.readUint16BE();
        final vrE = stream.readByte();
        final hrE = stream.readByte();
        
        _state.captureResY = (vrN / vrD) * _pow10(vrE);
        _state.captureResX = (hrN / hrD) * _pow10(hrE);
      } else if (subBox.type == Jp2Box.resd) {
        // Display resolution
        final vrN = stream.readUint16BE();
        final vrD = stream.readUint16BE();
        final hrN = stream.readUint16BE();
        final hrD = stream.readUint16BE();
        final vrE = stream.readByte();
        final hrE = stream.readByte();
        
        _state.displayResY = (vrN / vrD) * _pow10(vrE);
        _state.displayResX = (hrN / hrD) * _pow10(hrE);
      }
    }

    return true;
  }

  /// Finds codestream box
  bool _findCodestream(OpjMemoryStream stream) {
    while (!stream.isEof) {
      final box = _readBox(stream);
      if (box == null) break;

      if (box.type == Jp2Box.jp2c) {
        _state.codestreamStart = stream.position;
        _state.codestreamLength = box.dataLength - 8;
        return true;
      }

      // Skip box content
      stream.skip(box.dataLength - 8);
    }

    _state.errorMessage = 'Codestream box not found';
    return false;
  }

  /// Applies palette mapping to image
  void _applyPaletteMapping(OpjImage image) {
    final palette = _state.palette!;
    final mapping = _state.componentMapping!;
    
    // This is a simplified implementation
    // Full implementation would create new components based on mapping
    
    for (final map in mapping) {
      if (map.mappingType == 1 && map.component < image.numComponents) {
        // Palette mapping
        final comp = image.components[map.component];
        final col = map.paletteColumn;
        
        if (comp.data != null && col < palette.numColumns) {
          for (var i = 0; i < comp.data!.length; i++) {
            final idx = comp.data![i];
            if (idx >= 0 && idx < palette.numEntries) {
              comp.data![i] = palette.entries[idx][col];
            }
          }
        }
      }
    }
  }

  /// Reads a box header
  Jp2BoxInfo? _readBox(OpjMemoryStream stream) {
    if (stream.remaining < 8) return null;

    final startPos = stream.position;
    var length = stream.readUint32BE();
    final type = stream.readUint32BE();

    int dataLength;
    if (length == 1) {
      // Extended length
      if (stream.remaining < 8) return null;
      length = stream.readUint64BE();
      dataLength = length - 16;
    } else if (length == 0) {
      // Box extends to end of file
      dataLength = stream.remaining;
      length = dataLength + 8;
    } else {
      dataLength = length - 8;
    }

    return Jp2BoxInfo(
      type: type,
      length: length,
      dataStart: stream.position,
      dataLength: length,
    );
  }

  String _read4CharCode(OpjMemoryStream stream) {
    final bytes = stream.readBytes(4);
    if (bytes == null) return '';
    return String.fromCharCodes(bytes);
  }

  static double _pow10(int exp) {
    if (exp >= 0) {
      var result = 1.0;
      for (var i = 0; i < exp; i++) {
        result *= 10;
      }
      return result;
    } else {
      var result = 1.0;
      for (var i = 0; i < -exp; i++) {
        result /= 10;
      }
      return result;
    }
  }
}

// ==========================================================
//   Utility: Detect Format
// ==========================================================

/// Detects whether data is J2K codestream or JP2 file
OpjCodecFormat detectJpeg2000Format(Uint8List data) {
  if (data.length < 12) return OpjCodecFormat.unknown;

  // Check for JP2 signature
  if (data[0] == 0x00 && data[1] == 0x00 && data[2] == 0x00 && data[3] == 0x0C &&
      data[4] == 0x6A && data[5] == 0x50 && data[6] == 0x20 && data[7] == 0x20) {
    return OpjCodecFormat.jp2;
  }

  // Check for J2K codestream (SOC marker)
  if (data[0] == 0xFF && data[1] == 0x4F) {
    return OpjCodecFormat.j2k;
  }

  return OpjCodecFormat.unknown;
}
