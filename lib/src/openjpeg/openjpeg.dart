// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// OpenJPEG JPEG 2000 Codec for Dart.
/// 
/// Pure Dart port of OpenJPEG library for JPEG 2000 encoding/decoding.
/// Supports both J2K codestream and JP2 file format.
/// 
/// ## Usage
/// 
/// ```dart
/// import 'package:pdfium_dart/src/openjpeg/openjpeg.dart';
/// 
/// // Decode JPEG 2000 data (auto-detects format)
/// final result = decodeJpeg2000(jpegData);
/// if (result.isSuccess) {
///   final image = result.value!;
///   print('Image: ${image.width}x${image.height}');
///   print('Components: ${image.numComponents}');
///   
///   // Convert to RGBA
///   final rgba = image.toRgba();
/// }
/// ```
/// 
/// ## Supported Features
/// 
/// - J2K codestream decoding (Part-1)
/// - JP2 file format decoding (Part-1)
/// - 5-3 reversible wavelet transform (lossless)
/// - 9-7 irreversible wavelet transform (lossy)
/// - Multiple color spaces: sRGB, Grayscale, sYCC, CMYK
/// - Palette-based images
/// - ICC profiles
/// - Multiple progression orders: LRCP, RLCP, RPCL, PCRL, CPRL
library openjpeg;

// Export public types
export 'openjpeg_types.dart'
    show
        OpjResult,
        OpjColorSpace,
        OpjCodecFormat,
        OpjProgressionOrder,
        OpjProfile,
        OpjStepsize,
        OpjTccp,
        OpjPoc,
        J2kMarker,
        Jp2Box;

// Export image structures
export 'openjpeg_image.dart' show OpjImage, OpjImageComponent;

// Export codec parameters
export 'openjpeg_codec.dart'
    show
        OpjCompressionParams,
        OpjDecompressionParams,
        OpjCodingParams,
        OpjCodestreamInfo,
        OpjPacketInfo,
        OpjTileInfo,
        OpjTilePartInfo,
        OpjTileCodingParams;

// Export stream types
export 'openjpeg_stream.dart'
    show OpjStream, OpjMemoryStream, OpjBitIO, J2kStreamReader;

// Export decoders
export 'j2k_decoder.dart' show J2kDecoder;
export 'jp2_decoder.dart' show Jp2Decoder, Jp2BoxInfo, detectJpeg2000Format;

// Export internal modules for advanced usage
export 'dwt.dart' show Dwt, Mct;
export 'mqc.dart' show MqDecoder, MqEncoder;
export 't1.dart' show T1Decoder, T1CodeBlock;
export 't2.dart' show T2Decoder, T2Packet, T2PacketCodeBlock, PacketIterator;
export 'tcd.dart'
    show
        TileComponentDecoder,
        TcdComponentInfo,
        TcdTile,
        TcdTileComponent,
        TcdResolution,
        TcdBand,
        TcdPrecinct,
        TcdCodeBlock;

import 'dart:typed_data';

import 'j2k_decoder.dart';
import 'jp2_decoder.dart';
import 'openjpeg_codec.dart';
import 'openjpeg_image.dart';
import 'openjpeg_types.dart';

// ==========================================================
//   High-Level API
// ==========================================================

/// Callback for decoder messages
typedef OpjMessageCallback = void Function(String message);

/// Decodes JPEG 2000 data (auto-detects J2K or JP2 format)
/// 
/// Returns an [OpjResult] containing either the decoded [OpjImage]
/// or an error message.
/// 
/// Example:
/// ```dart
/// final result = decodeJpeg2000(jpegData);
/// if (result.isSuccess) {
///   final image = result.value!;
///   // Use image...
/// } else {
///   print('Error: ${result.error}');
/// }
/// ```
OpjResult<OpjImage> decodeJpeg2000(
  Uint8List data, {
  OpjDecompressionParams? params,
  OpjMessageCallback? onMessage,
}) {
  final format = detectJpeg2000Format(data);
  
  switch (format) {
    case OpjCodecFormat.jp2:
      final decoder = Jp2Decoder(params: params);
      decoder.onMessage = onMessage;
      return decoder.decode(data);
      
    case OpjCodecFormat.j2k:
      final decoder = J2kDecoder(params: params);
      decoder.onMessage = onMessage;
      return decoder.decode(data);
      
    default:
      return OpjResult.failure('Unknown JPEG 2000 format');
  }
}

/// Decodes J2K codestream data
/// 
/// Use this when you know the data is a raw J2K codestream (no JP2 wrapper).
OpjResult<OpjImage> decodeJ2k(
  Uint8List data, {
  OpjDecompressionParams? params,
  OpjMessageCallback? onMessage,
}) {
  final decoder = J2kDecoder(params: params);
  decoder.onMessage = onMessage;
  return decoder.decode(data);
}

/// Decodes JP2 file format data
/// 
/// Use this when you know the data is a JP2 file (with JP2 box structure).
OpjResult<OpjImage> decodeJp2(
  Uint8List data, {
  OpjDecompressionParams? params,
  OpjMessageCallback? onMessage,
}) {
  final decoder = Jp2Decoder(params: params);
  decoder.onMessage = onMessage;
  return decoder.decode(data);
}

/// Checks if data appears to be valid JPEG 2000
bool isJpeg2000(Uint8List data) {
  return detectJpeg2000Format(data) != OpjCodecFormat.unknown;
}

/// Checks if data appears to be JP2 file format
bool isJp2(Uint8List data) {
  return detectJpeg2000Format(data) == OpjCodecFormat.jp2;
}

/// Checks if data appears to be J2K codestream
bool isJ2k(Uint8List data) {
  return detectJpeg2000Format(data) == OpjCodecFormat.j2k;
}

// ==========================================================
//   Decoder Configuration
// ==========================================================

/// Creates default decompression parameters
OpjDecompressionParams createDefaultDecompressionParams() {
  return OpjDecompressionParams();
}

/// Creates decompression parameters for thumbnail extraction
/// 
/// Decodes to a reduced resolution level for faster thumbnail generation.
OpjDecompressionParams createThumbnailParams({int reduceLevel = 2}) {
  return OpjDecompressionParams(
    cpReduce: reduceLevel,
  );
}

/// Creates decompression parameters for extracting a specific region
OpjDecompressionParams createRegionParams({
  required int x0,
  required int y0,
  required int x1,
  required int y1,
}) {
  return OpjDecompressionParams(
    daX0: x0,
    daY0: y0,
    daX1: x1,
    daY1: y1,
  );
}

// ==========================================================
//   Version Info
// ==========================================================

/// OpenJPEG Dart port version
const String openjpegDartVersion = '1.0.0';

/// Original OpenJPEG version this port is based on
const String openjpegBaseVersion = '2.5.0';

/// Returns version information string
String getVersionInfo() {
  return 'OpenJPEG Dart $openjpegDartVersion (based on OpenJPEG $openjpegBaseVersion)';
}
