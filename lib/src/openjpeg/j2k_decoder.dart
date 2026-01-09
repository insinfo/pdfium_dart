// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG 2000 codestream (J2K) decoder.
/// 
/// Port of j2k.c from OpenJPEG library.
/// Implements decoding of JPEG 2000 Part-1 codestreams.
library;

import 'dart:typed_data';

import 'dwt.dart';
import 'mqc.dart';
import 'openjpeg_codec.dart';
import 'openjpeg_image.dart';
import 'openjpeg_stream.dart';
import 'openjpeg_types.dart';
import 't1.dart';
import 't2.dart';
import 'tcd.dart';

// ==========================================================
//   J2K Decoder State
// ==========================================================

/// J2K decoder internal state
class _J2kDecoderState {
  /// Current decoder state
  J2kState state = J2kState.none;
  
  /// Image info from SIZ marker
  int imageX0 = 0;
  int imageY0 = 0;
  int imageX1 = 0;
  int imageY1 = 0;
  
  /// Number of components
  int numComponents = 0;
  
  /// Component information
  final List<_ComponentInfo> components = [];
  
  /// Tile info from SIZ
  int tileX0 = 0;
  int tileY0 = 0;
  int tileWidth = 0;
  int tileHeight = 0;
  int numTilesX = 0;
  int numTilesY = 0;
  
  /// Coding parameters
  OpjCodingParams codingParams = OpjCodingParams();
  
  /// Current tile number being decoded
  int currentTile = 0;
  
  /// Default tile coding params
  OpjTileCodingParams? defaultTcp;
  
  /// Color space
  OpjColorSpace colorSpace = OpjColorSpace.unspecified;
  
  /// Error message
  String? errorMessage;
}

/// Component information from SIZ marker
class _ComponentInfo {
  int dx = 1; // XRsiz
  int dy = 1; // YRsiz
  int precision = 8;
  bool signed = false;
}

// ==========================================================
//   J2K Decoder
// ==========================================================

/// JPEG 2000 codestream decoder
class J2kDecoder {
  final _J2kDecoderState _state = _J2kDecoderState();
  final OpjDecompressionParams params;
  OpjMessageCallback? onMessage;
  
  J2kDecoder({OpjDecompressionParams? params})
      : params = params ?? OpjDecompressionParams();

  /// Decodes a JPEG 2000 codestream
  OpjResult<OpjImage> decode(Uint8List data) {
    final stream = J2kStreamReader(OpjMemoryStream(data));
    
    // Read main header
    final headerResult = _readMainHeader(stream);
    if (!headerResult) {
      return OpjResult.failure(_state.errorMessage ?? 'Failed to read main header');
    }

    // Create output image
    final image = _createImage();
    if (image == null) {
      return OpjResult.failure('Failed to create output image');
    }

    // Decode tiles
    final decodeResult = _decodeTiles(stream, image);
    if (!decodeResult) {
      return OpjResult.failure(_state.errorMessage ?? 'Failed to decode tiles');
    }

    return OpjResult.success(image);
  }

  /// Reads and validates the main header
  bool _readMainHeader(J2kStreamReader stream) {
    // Read SOC marker
    final soc = stream.readMarker();
    if (soc != J2kMarker.soc) {
      _state.errorMessage = 'Missing SOC marker';
      return false;
    }
    _state.state = J2kState.mhsoc;

    // Read SIZ marker (required after SOC)
    final marker = stream.readMarker();
    if (marker != J2kMarker.siz) {
      _state.errorMessage = 'Missing SIZ marker';
      return false;
    }
    if (!_readSizMarker(stream)) {
      return false;
    }
    _state.state = J2kState.mhsiz;

    // Read remaining main header markers
    _state.state = J2kState.mh;
    while (!stream.isEof) {
      final nextMarker = stream.readMarker();
      
      if (nextMarker == J2kMarker.sot) {
        // Start of tile - end of main header
        stream.skip(-2); // Put marker back
        break;
      }

      switch (nextMarker) {
        case J2kMarker.cod:
          if (!_readCodMarker(stream)) return false;
          break;
        case J2kMarker.coc:
          if (!_readCocMarker(stream)) return false;
          break;
        case J2kMarker.qcd:
          if (!_readQcdMarker(stream)) return false;
          break;
        case J2kMarker.qcc:
          if (!_readQccMarker(stream)) return false;
          break;
        case J2kMarker.poc:
          if (!_readPocMarker(stream)) return false;
          break;
        case J2kMarker.ppm:
          if (!_readPpmMarker(stream)) return false;
          break;
        case J2kMarker.tlm:
          if (!_readTlmMarker(stream)) return false;
          break;
        case J2kMarker.plm:
          if (!_readPlmMarker(stream)) return false;
          break;
        case J2kMarker.crg:
          if (!_readCrgMarker(stream)) return false;
          break;
        case J2kMarker.com:
          if (!_readComMarker(stream)) return false;
          break;
        default:
          // Skip unknown marker
          final len = stream.readUint16();
          stream.skip(len - 2);
          _onMessage(OpjMessageLevel.warning, 
              'Unknown marker: 0x${nextMarker.toRadixString(16)}');
      }
    }

    return true;
  }

  /// Reads SIZ marker (image and tile size)
  bool _readSizMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    if (len < 38) {
      _state.errorMessage = 'Invalid SIZ marker length';
      return false;
    }

    // Rsiz (capabilities)
    final rsiz = stream.readUint16();
    
    // Image size
    _state.imageX1 = stream.readUint32();
    _state.imageY1 = stream.readUint32();
    _state.imageX0 = stream.readUint32();
    _state.imageY0 = stream.readUint32();
    
    // Tile size
    _state.tileWidth = stream.readUint32();
    _state.tileHeight = stream.readUint32();
    _state.tileX0 = stream.readUint32();
    _state.tileY0 = stream.readUint32();
    
    // Number of components
    _state.numComponents = stream.readUint16();
    
    if (_state.numComponents == 0 || _state.numComponents > 16384) {
      _state.errorMessage = 'Invalid number of components: ${_state.numComponents}';
      return false;
    }

    // Component info
    _state.components.clear();
    for (var i = 0; i < _state.numComponents; i++) {
      final ssiz = stream.readByte();
      final xrsiz = stream.readByte();
      final yrsiz = stream.readByte();
      
      final comp = _ComponentInfo()
        ..signed = (ssiz & 0x80) != 0
        ..precision = (ssiz & 0x7F) + 1
        ..dx = xrsiz
        ..dy = yrsiz;
      
      _state.components.add(comp);
    }

    // Calculate number of tiles
    _state.numTilesX = _ceilDiv(
      _state.imageX1 - _state.tileX0, 
      _state.tileWidth
    );
    _state.numTilesY = _ceilDiv(
      _state.imageY1 - _state.tileY0, 
      _state.tileHeight
    );

    // Initialize coding parameters
    _state.codingParams = OpjCodingParams()
      ..tx0 = _state.tileX0
      ..ty0 = _state.tileY0
      ..tdx = _state.tileWidth
      ..tdy = _state.tileHeight
      ..numTilesX = _state.numTilesX
      ..numTilesY = _state.numTilesY;

    // Initialize tile coding params
    final totalTiles = _state.numTilesX * _state.numTilesY;
    _state.codingParams.tcps = List.generate(
      totalTiles, 
      (_) => OpjTileCodingParams(),
    );

    // Create default TCP
    _state.defaultTcp = OpjTileCodingParams();
    _state.defaultTcp!.tccps = List.generate(
      _state.numComponents,
      (_) => OpjTccp(),
    );

    return true;
  }

  /// Reads COD marker (coding style default)
  bool _readCodMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    final startPos = stream.position;
    
    final tcp = _state.defaultTcp!;
    
    // Scod (coding style)
    tcp.csty = stream.readByte();
    
    // SGcod (progression order, number of layers, MCT)
    tcp.progressionOrder = OpjProgressionOrder.fromValue(stream.readByte());
    tcp.numLayers = stream.readUint16();
    tcp.mct = stream.readByte();
    
    // SPcod (decomposition levels, code-block size, etc.)
    final numResolutions = stream.readByte() + 1;
    final cbWidth = stream.readByte();
    final cbHeight = stream.readByte();
    final cbStyle = stream.readByte();
    final qmfbid = stream.readByte(); // Wavelet transform: 0 = 9-7, 1 = 5-3
    
    // Apply to all components
    for (var i = 0; i < _state.numComponents; i++) {
      final tccp = tcp.tccps[i];
      tccp.csty = tcp.csty;
      tccp.numResolutions = numResolutions;
      tccp.codeBlockWidth = 1 << (cbWidth + 2);
      tccp.codeBlockHeight = 1 << (cbHeight + 2);
      tccp.codeBlockStyle = cbStyle;
      tccp.qmfbid = qmfbid;
      
      // Read precinct sizes if present
      if ((tcp.csty & CodingStyle.prt) != 0) {
        for (var r = 0; r < numResolutions; r++) {
          final val = stream.readByte();
          tccp.precinctWidth[r] = 1 << (val & 0x0F);
          tccp.precinctHeight[r] = 1 << ((val >> 4) & 0x0F);
        }
      }
    }

    // Skip any remaining bytes
    final bytesRead = stream.position - startPos;
    if (bytesRead < len - 2) {
      stream.skip(len - 2 - bytesRead);
    }

    return true;
  }

  /// Reads COC marker (coding style component)
  bool _readCocMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    
    // Component number
    final compno = _state.numComponents < 257 
        ? stream.readByte() 
        : stream.readUint16();
    
    if (compno >= _state.numComponents) {
      _state.errorMessage = 'Invalid component number in COC';
      return false;
    }

    final tccp = _state.defaultTcp!.tccps[compno];
    
    // Scoc
    tccp.csty = stream.readByte();
    
    // SPcoc
    tccp.numResolutions = stream.readByte() + 1;
    tccp.codeBlockWidth = 1 << (stream.readByte() + 2);
    tccp.codeBlockHeight = 1 << (stream.readByte() + 2);
    tccp.codeBlockStyle = stream.readByte();
    tccp.qmfbid = stream.readByte();
    
    // Precinct sizes
    if ((tccp.csty & CodingStyle.prt) != 0) {
      for (var r = 0; r < tccp.numResolutions; r++) {
        final val = stream.readByte();
        tccp.precinctWidth[r] = 1 << (val & 0x0F);
        tccp.precinctHeight[r] = 1 << ((val >> 4) & 0x0F);
      }
    }

    return true;
  }

  /// Reads QCD marker (quantization default)
  bool _readQcdMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    final startPos = stream.position;
    
    // Sqcd (quantization style)
    final sqcd = stream.readByte();
    final quantStyle = sqcd & 0x1F;
    final numGuardBits = sqcd >> 5;
    
    // Calculate number of subbands
    final numBands = len - 3;
    
    // Apply to all components
    for (var i = 0; i < _state.numComponents; i++) {
      final tccp = _state.defaultTcp!.tccps[i];
      tccp.quantStyle = quantStyle;
      tccp.numGuardBits = numGuardBits;
      
      // Reset position for each component
      stream.seek(startPos + 1);
      
      if (quantStyle == QuantizationStyle.none.value) {
        // No quantization - read exponent only
        for (var b = 0; b < numBands; b++) {
          final val = stream.readByte();
          tccp.stepsizes[b].exponent = val >> 3;
          tccp.stepsizes[b].mantissa = 0;
        }
      } else if (quantStyle == QuantizationStyle.scalarImplicit.value) {
        // Scalar quantization, implicit
        final val = stream.readUint16();
        final exp = val >> 11;
        final mant = val & 0x7FF;
        for (var b = 0; b < opjJ2kMaxBands; b++) {
          tccp.stepsizes[b].exponent = exp;
          tccp.stepsizes[b].mantissa = mant;
        }
      } else {
        // Scalar quantization, explicit
        for (var b = 0; b < numBands ~/ 2; b++) {
          final val = stream.readUint16();
          tccp.stepsizes[b].exponent = val >> 11;
          tccp.stepsizes[b].mantissa = val & 0x7FF;
        }
      }
    }

    // Skip to end of marker
    stream.seek(startPos + len - 2);
    return true;
  }

  /// Reads QCC marker (quantization component)
  bool _readQccMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    final startPos = stream.position;
    
    // Component number
    final compno = _state.numComponents < 257 
        ? stream.readByte() 
        : stream.readUint16();
    
    if (compno >= _state.numComponents) {
      _state.errorMessage = 'Invalid component number in QCC';
      return false;
    }

    final tccp = _state.defaultTcp!.tccps[compno];
    
    // Sqcc
    final sqcc = stream.readByte();
    tccp.quantStyle = sqcc & 0x1F;
    tccp.numGuardBits = sqcc >> 5;
    
    // Read step sizes
    final headerLen = _state.numComponents < 257 ? 2 : 3;
    final numBands = len - 2 - headerLen;
    
    if (tccp.quantStyle == QuantizationStyle.none.value) {
      for (var b = 0; b < numBands; b++) {
        final val = stream.readByte();
        tccp.stepsizes[b].exponent = val >> 3;
        tccp.stepsizes[b].mantissa = 0;
      }
    } else {
      for (var b = 0; b < numBands ~/ 2; b++) {
        final val = stream.readUint16();
        tccp.stepsizes[b].exponent = val >> 11;
        tccp.stepsizes[b].mantissa = val & 0x7FF;
      }
    }

    stream.seek(startPos + len - 2);
    return true;
  }

  /// Reads POC marker (progression order change)
  bool _readPocMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    stream.skip(len - 2); // Skip for now
    return true;
  }

  /// Reads PPM marker (packed packet headers, main header)
  bool _readPpmMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    stream.skip(len - 2); // Skip for now
    return true;
  }

  /// Reads TLM marker (tile-part lengths)
  bool _readTlmMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    stream.skip(len - 2); // Skip - informational only
    return true;
  }

  /// Reads PLM marker (packet length, main header)
  bool _readPlmMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    stream.skip(len - 2);
    return true;
  }

  /// Reads CRG marker (component registration)
  bool _readCrgMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    stream.skip(len - 2);
    return true;
  }

  /// Reads COM marker (comment)
  bool _readComMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    stream.skip(len - 2);
    return true;
  }

  /// Creates output image from parsed header info
  OpjImage? _createImage() {
    final image = OpjImage(
      x0: _state.imageX0,
      y0: _state.imageY0,
      x1: _state.imageX1,
      y1: _state.imageY1,
      colorSpace: _state.colorSpace,
    );

    for (var i = 0; i < _state.numComponents; i++) {
      final compInfo = _state.components[i];
      
      final compWidth = _ceilDiv(
        _state.imageX1 - _state.imageX0,
        compInfo.dx,
      );
      final compHeight = _ceilDiv(
        _state.imageY1 - _state.imageY0,
        compInfo.dy,
      );

      final comp = OpjImageComponent(
        dx: compInfo.dx,
        dy: compInfo.dy,
        width: compWidth,
        height: compHeight,
        x0: _ceilDiv(_state.imageX0, compInfo.dx),
        y0: _ceilDiv(_state.imageY0, compInfo.dy),
        precision: compInfo.precision,
        signed: compInfo.signed,
      );
      comp.allocateData();
      
      image.components.add(comp);
    }

    return image;
  }

  /// Decodes all tiles
  bool _decodeTiles(J2kStreamReader stream, OpjImage image) {
    _state.state = J2kState.tphsot;
    
    while (!stream.isEof) {
      final marker = stream.readMarker();
      
      if (marker == J2kMarker.eoc) {
        _state.state = J2kState.eoc;
        break;
      }
      
      if (marker == J2kMarker.sot) {
        if (!_decodeTile(stream, image)) {
          return false;
        }
      } else if (marker == -1) {
        // EOF
        break;
      } else {
        _onMessage(OpjMessageLevel.warning, 
            'Unexpected marker: 0x${marker.toRadixString(16)}');
        // Try to recover
        final len = stream.readUint16();
        stream.skip(len - 2);
      }
    }

    return true;
  }

  /// Decodes a single tile
  bool _decodeTile(J2kStreamReader stream, OpjImage image) {
    // Read SOT marker content
    final sotLen = stream.readUint16();
    
    final tileIndex = stream.readUint16();
    final tilePartLen = stream.readUint32();
    final tilePartIndex = stream.readByte();
    final numTileParts = stream.readByte();
    
    _state.currentTile = tileIndex;
    
    if (tileIndex >= _state.numTilesX * _state.numTilesY) {
      _state.errorMessage = 'Invalid tile index: $tileIndex';
      return false;
    }

    // Get tile coding parameters
    final tcp = _state.codingParams.tcps[tileIndex];
    
    // Copy default parameters if this is first tile part
    if (tilePartIndex == 0) {
      _copyTileCodingParams(tcp, _state.defaultTcp!);
    }

    // Read tile part header
    _state.state = J2kState.tph;
    while (!stream.isEof) {
      final marker = stream.readMarker();
      
      if (marker == J2kMarker.sod) {
        // Start of data
        break;
      }

      switch (marker) {
        case J2kMarker.cod:
          if (!_readTileCodMarker(stream, tcp)) return false;
          break;
        case J2kMarker.coc:
          if (!_readTileCocMarker(stream, tcp)) return false;
          break;
        case J2kMarker.qcd:
          if (!_readTileQcdMarker(stream, tcp)) return false;
          break;
        case J2kMarker.qcc:
          if (!_readTileQccMarker(stream, tcp)) return false;
          break;
        case J2kMarker.ppt:
          if (!_readPptMarker(stream, tcp)) return false;
          break;
        case J2kMarker.plt:
          if (!_readPltMarker(stream)) return false;
          break;
        case J2kMarker.com:
          if (!_readComMarker(stream)) return false;
          break;
        default:
          final len = stream.readUint16();
          stream.skip(len - 2);
      }
    }

    // Decode tile data
    _state.state = J2kState.data;
    if (!_decodeTileData(stream, image, tileIndex, tcp)) {
      return false;
    }

    return true;
  }

  /// Copies tile coding parameters
  void _copyTileCodingParams(OpjTileCodingParams dst, OpjTileCodingParams src) {
    dst.csty = src.csty;
    dst.progressionOrder = src.progressionOrder;
    dst.numLayers = src.numLayers;
    dst.mct = src.mct;
    
    dst.tccps = List.generate(_state.numComponents, (i) {
      final srcTccp = src.tccps[i];
      final dstTccp = OpjTccp()
        ..csty = srcTccp.csty
        ..numResolutions = srcTccp.numResolutions
        ..codeBlockWidth = srcTccp.codeBlockWidth
        ..codeBlockHeight = srcTccp.codeBlockHeight
        ..codeBlockStyle = srcTccp.codeBlockStyle
        ..qmfbid = srcTccp.qmfbid
        ..quantStyle = srcTccp.quantStyle
        ..numGuardBits = srcTccp.numGuardBits;
      
      for (var b = 0; b < opjJ2kMaxBands; b++) {
        dstTccp.stepsizes[b].exponent = srcTccp.stepsizes[b].exponent;
        dstTccp.stepsizes[b].mantissa = srcTccp.stepsizes[b].mantissa;
      }
      for (var r = 0; r < opjJ2kMaxResolutionLevels; r++) {
        dstTccp.precinctWidth[r] = srcTccp.precinctWidth[r];
        dstTccp.precinctHeight[r] = srcTccp.precinctHeight[r];
      }
      
      return dstTccp;
    });
  }

  /// Reads tile-specific COD marker
  bool _readTileCodMarker(J2kStreamReader stream, OpjTileCodingParams tcp) {
    final len = stream.readUint16();
    
    tcp.csty = stream.readByte();
    tcp.progressionOrder = OpjProgressionOrder.fromValue(stream.readByte());
    tcp.numLayers = stream.readUint16();
    tcp.mct = stream.readByte();
    
    final numResolutions = stream.readByte() + 1;
    final cbWidth = stream.readByte();
    final cbHeight = stream.readByte();
    final cbStyle = stream.readByte();
    final qmfbid = stream.readByte();
    
    for (var i = 0; i < _state.numComponents; i++) {
      final tccp = tcp.tccps[i];
      tccp.numResolutions = numResolutions;
      tccp.codeBlockWidth = 1 << (cbWidth + 2);
      tccp.codeBlockHeight = 1 << (cbHeight + 2);
      tccp.codeBlockStyle = cbStyle;
      tccp.qmfbid = qmfbid;
      
      if ((tcp.csty & CodingStyle.prt) != 0) {
        for (var r = 0; r < numResolutions; r++) {
          final val = stream.readByte();
          tccp.precinctWidth[r] = 1 << (val & 0x0F);
          tccp.precinctHeight[r] = 1 << ((val >> 4) & 0x0F);
        }
      }
    }

    return true;
  }

  /// Reads tile-specific COC marker
  bool _readTileCocMarker(J2kStreamReader stream, OpjTileCodingParams tcp) {
    final len = stream.readUint16();
    
    final compno = _state.numComponents < 257 
        ? stream.readByte() 
        : stream.readUint16();
    
    if (compno >= _state.numComponents) return false;
    
    final tccp = tcp.tccps[compno];
    tccp.csty = stream.readByte();
    tccp.numResolutions = stream.readByte() + 1;
    tccp.codeBlockWidth = 1 << (stream.readByte() + 2);
    tccp.codeBlockHeight = 1 << (stream.readByte() + 2);
    tccp.codeBlockStyle = stream.readByte();
    tccp.qmfbid = stream.readByte();
    
    return true;
  }

  /// Reads tile-specific QCD marker
  bool _readTileQcdMarker(J2kStreamReader stream, OpjTileCodingParams tcp) {
    final len = stream.readUint16();
    final startPos = stream.position;
    
    final sqcd = stream.readByte();
    final quantStyle = sqcd & 0x1F;
    final numGuardBits = sqcd >> 5;
    final numBands = len - 3;
    
    for (var i = 0; i < _state.numComponents; i++) {
      final tccp = tcp.tccps[i];
      tccp.quantStyle = quantStyle;
      tccp.numGuardBits = numGuardBits;
      
      stream.seek(startPos + 1);
      
      if (quantStyle == QuantizationStyle.none.value) {
        for (var b = 0; b < numBands; b++) {
          final val = stream.readByte();
          tccp.stepsizes[b].exponent = val >> 3;
          tccp.stepsizes[b].mantissa = 0;
        }
      } else {
        for (var b = 0; b < numBands ~/ 2; b++) {
          final val = stream.readUint16();
          tccp.stepsizes[b].exponent = val >> 11;
          tccp.stepsizes[b].mantissa = val & 0x7FF;
        }
      }
    }

    stream.seek(startPos + len - 2);
    return true;
  }

  /// Reads tile-specific QCC marker
  bool _readTileQccMarker(J2kStreamReader stream, OpjTileCodingParams tcp) {
    final len = stream.readUint16();
    stream.skip(len - 2);
    return true;
  }

  /// Reads PPT marker
  bool _readPptMarker(J2kStreamReader stream, OpjTileCodingParams tcp) {
    final len = stream.readUint16();
    stream.skip(len - 2);
    return true;
  }

  /// Reads PLT marker
  bool _readPltMarker(J2kStreamReader stream) {
    final len = stream.readUint16();
    stream.skip(len - 2);
    return true;
  }

  /// Decodes tile data
  bool _decodeTileData(
    J2kStreamReader stream,
    OpjImage image,
    int tileIndex,
    OpjTileCodingParams tcp,
  ) {
    // Create tile component decoder
    // Convert component info
    final tcdComponents = _state.components.map((c) => TcdComponentInfo(
      dx: c.dx,
      dy: c.dy,
      precision: c.precision,
      signed: c.signed,
    )).toList();
    
    final tcd = TileComponentDecoder(
      tileIndex: tileIndex,
      tileX: tileIndex % _state.numTilesX,
      tileY: tileIndex ~/ _state.numTilesX,
      tx0: _state.tileX0,
      ty0: _state.tileY0,
      tileWidth: _state.tileWidth,
      tileHeight: _state.tileHeight,
      imageX0: _state.imageX0,
      imageY0: _state.imageY0,
      imageX1: _state.imageX1,
      imageY1: _state.imageY1,
      numComponents: _state.numComponents,
      components: tcdComponents,
      tcp: tcp,
    );

    // Initialize tile
    if (!tcd.initialize()) {
      _state.errorMessage = 'Failed to initialize tile decoder';
      return false;
    }

    // Find the end of tile data (next marker or EOF)
    final dataStart = stream.position;
    var dataEnd = stream.length;
    
    // Scan for next marker
    final savedPos = stream.position;
    while (!stream.isEof) {
      final b = stream.readByte();
      if (b == 0xFF) {
        final next = stream.readByte();
        if (next >= 0x90 && next != 0xFF) {
          // Found marker
          dataEnd = stream.position - 2;
          break;
        }
      }
    }
    stream.seek(savedPos);

    // Read tile data
    final dataLen = dataEnd - dataStart;
    final tileData = stream.readBytes(dataLen);
    if (tileData == null) {
      _state.errorMessage = 'Failed to read tile data';
      return false;
    }

    // Decode tile
    if (!tcd.decode(tileData, image)) {
      _state.errorMessage = 'Failed to decode tile data';
      return false;
    }

    return true;
  }

  void _onMessage(OpjMessageLevel level, String message) {
    onMessage?.call(level, message);
  }

  static int _ceilDiv(int a, int b) {
    return (a + b - 1) ~/ b;
  }
}
