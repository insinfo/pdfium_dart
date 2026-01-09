// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG XL types, constants, and enums.
///
/// Port of JPEG XL (libjxl) codestream header types.
library;

import 'dart:typed_data';

// ==========================================================
//   Constants
// ==========================================================

/// JPEG XL codestream marker (0x0A after 0xFF)
const int jxlCodestreamMarker = 0x0A;

/// JPEG XL signature bytes: 0xFF 0x0A
const List<int> jxlSignature = [0xFF, 0x0A];

/// JPEG XL container signature (ISOBMFF box)
const List<int> jxlContainerSignature = [
  0x00, 0x00, 0x00, 0x0C, // Box size: 12
  0x4A, 0x58, 0x4C, 0x20, // Box type: 'JXL '
  0x0D, 0x0A, 0x87, 0x0A, // Additional signature
];

/// Maximum number of passes in an image
const int jxlMaxNumPasses = 11;

/// Maximum number of reference frames
const int jxlMaxNumReferenceFrames = 4;

/// Maximum bits per call for bit reader
const int jxlMaxBitsPerCall = 56;

/// Maximum image dimension (2^30)
const int jxlMaxImageDimension = 1 << 30;

/// Maximum number of extra channels
const int jxlMaxExtraChannels = 4096;

// ==========================================================
//   Enums
// ==========================================================

/// Image orientation metadata (matches EXIF definitions 1-8)
enum JxlOrientation {
  identity(1),
  flipHorizontal(2),
  rotate180(3),
  flipVertical(4),
  transpose(5),
  rotate90CW(6),
  antiTranspose(7),
  rotate90CCW(8);

  const JxlOrientation(this.value);
  final int value;

  static JxlOrientation fromValue(int value) {
    return JxlOrientation.values.firstWhere(
      (e) => e.value == value,
      orElse: () => JxlOrientation.identity,
    );
  }
}

/// Extra channel types
enum JxlExtraChannelType {
  alpha(0),
  depth(1),
  spotColor(2),
  selectionMask(3),
  black(4), // for CMYK
  cfa(5), // Bayer channel
  thermal(6),
  reserved0(7),
  reserved1(8),
  reserved2(9),
  reserved3(10),
  reserved4(11),
  reserved5(12),
  reserved6(13),
  reserved7(14),
  unknown(15),
  optional(16);

  const JxlExtraChannelType(this.value);
  final int value;

  static JxlExtraChannelType fromValue(int value) {
    return JxlExtraChannelType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => JxlExtraChannelType.unknown,
    );
  }
}

/// Frame encoding type
enum JxlFrameEncoding {
  varDCT(0), // Variable-size DCT
  modular(1); // Modular encoding

  const JxlFrameEncoding(this.value);
  final int value;
}

/// Color transform type
enum JxlColorTransform {
  xyb(0), // XYB color space (default for lossy)
  none(1), // No transform, use attached color profile
  ycbcr(2); // YCbCr transform

  const JxlColorTransform(this.value);
  final int value;
}

/// Blend mode for frames
enum JxlBlendMode {
  replace(0),
  add(1),
  blend(2),
  mulAdd(3),
  mul(4);

  const JxlBlendMode(this.value);
  final int value;
}

/// Data type for pixel values
enum JxlDataType {
  float32(0),
  uint8(1),
  uint16(2),
  float16(3);

  const JxlDataType(this.value);
  final int value;
}

/// Color space type
enum JxlColorSpace {
  rgb(0),
  gray(1),
  xyb(2),
  unknown(3);

  const JxlColorSpace(this.value);
  final int value;
}

/// White point presets
enum JxlWhitePoint {
  d65(1),
  custom(2),
  e(10),
  dci(11);

  const JxlWhitePoint(this.value);
  final int value;
}

/// Primaries presets
enum JxlPrimaries {
  sRGB(1),
  custom(2),
  bt2100(9),
  p3(11);

  const JxlPrimaries(this.value);
  final int value;
}

/// Transfer function
enum JxlTransferFunction {
  bt709(1), // sRGB / BT.709
  unknown(2),
  linear(8),
  sRGB(13),
  pq(16), // Perceptual Quantizer (HDR)
  dci(17),
  hlg(18); // Hybrid Log-Gamma (HDR)

  const JxlTransferFunction(this.value);
  final int value;
}

/// Rendering intent
enum JxlRenderingIntent {
  perceptual(0),
  relative(1),
  saturation(2),
  absolute(3);

  const JxlRenderingIntent(this.value);
  final int value;
}

// ==========================================================
//   Result Types
// ==========================================================

/// Result wrapper for JXL operations
class JxlResult<T> {
  final T? value;
  final String? error;
  final bool success;

  JxlResult.ok(this.value)
      : error = null,
        success = true;

  JxlResult.failure(this.error)
      : value = null,
        success = false;

  bool get isSuccess => success;
  bool get isFailure => !success;
}

// ==========================================================
//   Header Structures
// ==========================================================

/// Size header - compact representation of image dimensions
class JxlSizeHeader {
  /// Image width in pixels
  int xsize;

  /// Image height in pixels
  int ysize;

  JxlSizeHeader({
    this.xsize = 0,
    this.ysize = 0,
  });
}

/// Preview header
class JxlPreviewHeader {
  /// Preview width in pixels
  int xsize;

  /// Preview height in pixels
  int ysize;

  JxlPreviewHeader({
    this.xsize = 0,
    this.ysize = 0,
  });
}

/// Animation header
class JxlAnimationHeader {
  /// Ticks per second numerator
  int tpsNumerator;

  /// Ticks per second denominator
  int tpsDenominator;

  /// Number of loops (0 = infinite)
  int numLoops;

  /// Whether frames have timecodes
  bool haveTimecodes;

  JxlAnimationHeader({
    this.tpsNumerator = 1,
    this.tpsDenominator = 1,
    this.numLoops = 0,
    this.haveTimecodes = false,
  });
}

/// Bit depth information
class JxlBitDepth {
  /// Whether samples are floating point
  bool floatingPointSample;

  /// Bits per sample (1-32)
  int bitsPerSample;

  /// Exponent bits for floating point (only if floatingPointSample)
  int exponentBitsPerSample;

  JxlBitDepth({
    this.floatingPointSample = false,
    this.bitsPerSample = 8,
    this.exponentBitsPerSample = 0,
  });
}

/// Extra channel information
class JxlExtraChannelInfo {
  /// Channel type
  JxlExtraChannelType type;

  /// Bit depth
  JxlBitDepth bitDepth;

  /// Downsampling shift (2^dimShift)
  int dimShift;

  /// Channel name (UTF-8)
  String name;

  /// Whether alpha is premultiplied
  bool alphaAssociated;

  /// Spot color values [R, G, B, A]
  List<double>? spotColor;

  /// CFA channel index
  int cfaChannel;

  JxlExtraChannelInfo({
    this.type = JxlExtraChannelType.alpha,
    JxlBitDepth? bitDepth,
    this.dimShift = 0,
    this.name = '',
    this.alphaAssociated = false,
    this.spotColor,
    this.cfaChannel = 0,
  }) : bitDepth = bitDepth ?? JxlBitDepth();
}

/// Color encoding information
class JxlColorEncoding {
  /// Color space
  JxlColorSpace colorSpace;

  /// White point
  JxlWhitePoint whitePoint;

  /// Custom white point (if whitePoint == custom)
  double whitePointX;
  double whitePointY;

  /// Primaries
  JxlPrimaries primaries;

  /// Custom primaries (if primaries == custom)
  /// [rx, ry, gx, gy, bx, by]
  List<double>? customPrimaries;

  /// Transfer function
  JxlTransferFunction transferFunction;

  /// Gamma (if transferFunction == unknown)
  double gamma;

  /// Rendering intent
  JxlRenderingIntent renderingIntent;

  JxlColorEncoding({
    this.colorSpace = JxlColorSpace.rgb,
    this.whitePoint = JxlWhitePoint.d65,
    this.whitePointX = 0.3127,
    this.whitePointY = 0.3290,
    this.primaries = JxlPrimaries.sRGB,
    this.customPrimaries,
    this.transferFunction = JxlTransferFunction.sRGB,
    this.gamma = 1.0,
    this.renderingIntent = JxlRenderingIntent.relative,
  });

  /// Creates sRGB color encoding
  factory JxlColorEncoding.sRGB() => JxlColorEncoding(
        colorSpace: JxlColorSpace.rgb,
        whitePoint: JxlWhitePoint.d65,
        primaries: JxlPrimaries.sRGB,
        transferFunction: JxlTransferFunction.sRGB,
        renderingIntent: JxlRenderingIntent.relative,
      );

  /// Creates linear sRGB color encoding
  factory JxlColorEncoding.linearSRGB() => JxlColorEncoding(
        colorSpace: JxlColorSpace.rgb,
        whitePoint: JxlWhitePoint.d65,
        primaries: JxlPrimaries.sRGB,
        transferFunction: JxlTransferFunction.linear,
        renderingIntent: JxlRenderingIntent.relative,
      );

  /// Creates grayscale encoding
  factory JxlColorEncoding.gray() => JxlColorEncoding(
        colorSpace: JxlColorSpace.gray,
        whitePoint: JxlWhitePoint.d65,
        transferFunction: JxlTransferFunction.sRGB,
        renderingIntent: JxlRenderingIntent.relative,
      );
}

/// Basic image information
class JxlBasicInfo {
  /// Image width in pixels
  int xsize;

  /// Image height in pixels
  int ysize;

  /// Bit depth for main channels
  JxlBitDepth bitDepth;

  /// Number of color channels (1 for gray, 3 for RGB)
  int numColorChannels;

  /// Number of extra channels
  int numExtraChannels;

  /// Alpha bit depth (0 if no alpha)
  int alphaBits;

  /// Alpha exponent bits (for floating point alpha)
  int alphaExponentBits;

  /// Whether alpha is premultiplied
  bool alphaPremultiplied;

  /// Preview header (null if no preview)
  JxlPreviewHeader? preview;

  /// Animation header (null if not animated)
  JxlAnimationHeader? animation;

  /// Image orientation
  JxlOrientation orientation;

  /// Intensity target for HDR (nits)
  double intensityTarget;

  /// Minimum nits for HDR tone mapping
  double minNits;

  /// Whether intensity target is relative to max display luminance
  bool relativeToMaxDisplay;

  /// Linear below value for tone mapping
  double linearBelow;

  /// Uses original ICC profile
  bool usesOriginalProfile;

  /// Intrinsic size (if different from encoded size)
  int? intrinsicXsize;
  int? intrinsicYsize;

  JxlBasicInfo({
    this.xsize = 0,
    this.ysize = 0,
    JxlBitDepth? bitDepth,
    this.numColorChannels = 3,
    this.numExtraChannels = 0,
    this.alphaBits = 0,
    this.alphaExponentBits = 0,
    this.alphaPremultiplied = false,
    this.preview,
    this.animation,
    this.orientation = JxlOrientation.identity,
    this.intensityTarget = 255.0,
    this.minNits = 0.0,
    this.relativeToMaxDisplay = false,
    this.linearBelow = 0.0,
    this.usesOriginalProfile = false,
    this.intrinsicXsize,
    this.intrinsicYsize,
  }) : bitDepth = bitDepth ?? JxlBitDepth();

  /// Whether the image is animated
  bool get isAnimated => animation != null;

  /// Whether the image has alpha
  bool get hasAlpha => alphaBits > 0 || numExtraChannels > 0;

  /// Whether the image is grayscale
  bool get isGray => numColorChannels == 1;
}

/// Frame header information
class JxlFrameHeader {
  /// Frame name
  String name;

  /// Duration in ticks (for animation)
  int duration;

  /// Timecode (if animation has timecodes)
  int timecode;

  /// Whether this is the last frame
  bool isLast;

  /// Layer info for blending
  JxlLayerInfo layerInfo;

  JxlFrameHeader({
    this.name = '',
    this.duration = 0,
    this.timecode = 0,
    this.isLast = true,
    JxlLayerInfo? layerInfo,
  }) : layerInfo = layerInfo ?? JxlLayerInfo();
}

/// Layer information for frame blending
class JxlLayerInfo {
  /// Whether to save as reference
  bool haveCrop;

  /// Crop position X
  int cropX0;

  /// Crop position Y
  int cropY0;

  /// Crop width (0 = full width)
  int xsize;

  /// Crop height (0 = full height)
  int ysize;

  /// Blend mode
  JxlBlendMode blendMode;

  /// Source for blending
  int blendSource;

  /// Alpha channel for blending
  int blendAlpha;

  /// Whether alpha is clipped
  bool blendClamp;

  /// Reference frame to save to (-1 = none)
  int saveAsReference;

  JxlLayerInfo({
    this.haveCrop = false,
    this.cropX0 = 0,
    this.cropY0 = 0,
    this.xsize = 0,
    this.ysize = 0,
    this.blendMode = JxlBlendMode.replace,
    this.blendSource = 0,
    this.blendAlpha = 0,
    this.blendClamp = false,
    this.saveAsReference = -1,
  });
}

// ==========================================================
//   Image Structure
// ==========================================================

/// Decoded JPEG XL image
class JxlImage {
  /// Image width
  final int width;

  /// Image height
  final int height;

  /// Basic info
  final JxlBasicInfo info;

  /// Color encoding
  final JxlColorEncoding colorEncoding;

  /// Pixel data for each channel
  /// For RGB: [R, G, B] each width*height
  /// For Gray: [Y] width*height
  final List<Uint8List> channels;

  /// Extra channels (alpha, depth, etc.)
  final List<Uint8List> extraChannels;

  /// Extra channel info
  final List<JxlExtraChannelInfo> extraChannelInfo;

  /// ICC profile (if usesOriginalProfile)
  final Uint8List? iccProfile;

  JxlImage({
    required this.width,
    required this.height,
    required this.info,
    required this.colorEncoding,
    required this.channels,
    this.extraChannels = const [],
    this.extraChannelInfo = const [],
    this.iccProfile,
  });

  /// Number of color channels
  int get numColorChannels => info.numColorChannels;

  /// Whether the image is grayscale
  bool get isGray => info.isGray;

  /// Whether the image has alpha
  bool get hasAlpha => extraChannels.isNotEmpty;

  /// Gets the alpha channel (if present)
  Uint8List? get alphaChannel {
    for (int i = 0; i < extraChannelInfo.length; i++) {
      if (extraChannelInfo[i].type == JxlExtraChannelType.alpha) {
        return extraChannels[i];
      }
    }
    return null;
  }

  /// Converts to RGB byte array (interleaved)
  Uint8List toRgb() {
    final result = Uint8List(width * height * 3);

    if (isGray) {
      // Convert grayscale to RGB
      final y = channels[0];
      for (int i = 0; i < width * height; i++) {
        result[i * 3 + 0] = y[i];
        result[i * 3 + 1] = y[i];
        result[i * 3 + 2] = y[i];
      }
    } else {
      // RGB
      final r = channels[0];
      final g = channels[1];
      final b = channels[2];
      for (int i = 0; i < width * height; i++) {
        result[i * 3 + 0] = r[i];
        result[i * 3 + 1] = g[i];
        result[i * 3 + 2] = b[i];
      }
    }

    return result;
  }

  /// Converts to RGBA byte array (interleaved)
  Uint8List toRgba() {
    final result = Uint8List(width * height * 4);
    final alpha = alphaChannel;

    if (isGray) {
      // Convert grayscale to RGBA
      final y = channels[0];
      for (int i = 0; i < width * height; i++) {
        result[i * 4 + 0] = y[i];
        result[i * 4 + 1] = y[i];
        result[i * 4 + 2] = y[i];
        result[i * 4 + 3] = alpha?[i] ?? 255;
      }
    } else {
      // RGBA
      final r = channels[0];
      final g = channels[1];
      final b = channels[2];
      for (int i = 0; i < width * height; i++) {
        result[i * 4 + 0] = r[i];
        result[i * 4 + 1] = g[i];
        result[i * 4 + 2] = b[i];
        result[i * 4 + 3] = alpha?[i] ?? 255;
      }
    }

    return result;
  }
}

// ==========================================================
//   Format Detection
// ==========================================================

/// Checks if data starts with JXL codestream signature
bool isJxlCodestream(Uint8List data) {
  if (data.length < 2) return false;
  return data[0] == 0xFF && data[1] == jxlCodestreamMarker;
}

/// Checks if data starts with JXL container signature
bool isJxlContainer(Uint8List data) {
  if (data.length < 12) return false;
  for (int i = 0; i < 12; i++) {
    if (data[i] != jxlContainerSignature[i]) return false;
  }
  return true;
}

/// Checks if data is JPEG XL (codestream or container)
bool isJxl(Uint8List data) {
  return isJxlCodestream(data) || isJxlContainer(data);
}

/// JXL format type
enum JxlFormat {
  /// Raw codestream (starts with 0xFF 0x0A)
  codestream,

  /// Container format (ISOBMFF boxes)
  container,

  /// Unknown/invalid format
  unknown,
}

/// Detects JXL format type
JxlFormat detectJxlFormat(Uint8List data) {
  if (isJxlCodestream(data)) return JxlFormat.codestream;
  if (isJxlContainer(data)) return JxlFormat.container;
  return JxlFormat.unknown;
}
