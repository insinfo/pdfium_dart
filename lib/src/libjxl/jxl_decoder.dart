// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG XL decoder.
///
/// Decodes JPEG XL codestream and container formats.
library;

import 'dart:typed_data';

import 'jxl_bitreader.dart';
import 'jxl_types.dart';

// ==========================================================
//   JXL Decoder State
// ==========================================================

/// Internal decoder state
class _JxlDecoderState {
  JxlBasicInfo? basicInfo;
  JxlColorEncoding? colorEncoding;
  JxlFrameHeader? frameHeader;
  List<JxlExtraChannelInfo> extraChannels = [];
  Uint8List? iccProfile;
  String? errorMessage;

  // Decoded frame data
  List<List<double>>? frameData;

  void reset() {
    basicInfo = null;
    colorEncoding = null;
    frameHeader = null;
    extraChannels = [];
    iccProfile = null;
    errorMessage = null;
    frameData = null;
  }
}

// ==========================================================
//   JXL Decoder
// ==========================================================

/// JPEG XL decoder
class JxlDecoder {
  final _JxlDecoderState _state = _JxlDecoderState();

  /// Callback for decoder messages
  void Function(String message)? onMessage;

  /// Decodes JPEG XL data
  JxlResult<JxlImage> decode(Uint8List data) {
    _state.reset();

    final format = detectJxlFormat(data);

    try {
      switch (format) {
        case JxlFormat.codestream:
          return _decodeCodestream(data);
        case JxlFormat.container:
          return _decodeContainer(data);
        case JxlFormat.unknown:
          return JxlResult.failure('Unknown JPEG XL format');
      }
    } catch (e) {
      return JxlResult.failure('Decode error: $e');
    }
  }

  /// Decodes raw JXL codestream
  JxlResult<JxlImage> _decodeCodestream(Uint8List data) {
    // Skip signature (0xFF 0x0A)
    if (data.length < 2) {
      return JxlResult.failure('Data too short');
    }

    final reader = JxlBitReader.fromBytes(Uint8List.sublistView(data, 2));

    // Read size header
    final sizeResult = _readSizeHeader(reader);
    if (!sizeResult.isSuccess) {
      return JxlResult.failure(sizeResult.error!);
    }
    final size = sizeResult.value!;

    // Read image metadata
    final metadataResult = _readImageMetadata(reader, size);
    if (!metadataResult.isSuccess) {
      return JxlResult.failure(metadataResult.error!);
    }

    // Read frame header
    final frameResult = _readFrameHeader(reader);
    if (!frameResult.isSuccess) {
      return JxlResult.failure(frameResult.error!);
    }

    // Decode frame data
    final dataResult = _decodeFrameData(reader);
    if (!dataResult.isSuccess) {
      return JxlResult.failure(dataResult.error!);
    }

    return _buildImage();
  }

  /// Decodes JXL container format
  JxlResult<JxlImage> _decodeContainer(Uint8List data) {
    int pos = 0;

    // Skip container signature (12 bytes)
    pos += 12;

    Uint8List? codestreamData;

    // Parse boxes
    while (pos < data.length - 8) {
      // Read box size (4 bytes, big-endian)
      final boxSize = (data[pos] << 24) |
          (data[pos + 1] << 16) |
          (data[pos + 2] << 8) |
          data[pos + 3];
      pos += 4;

      // Read box type (4 bytes)
      final boxType = String.fromCharCodes(data.sublist(pos, pos + 4));
      pos += 4;

      // Handle extended box size
      int dataSize = boxSize - 8;
      int actualBoxSize = boxSize;
      if (boxSize == 1) {
        // Extended box size (8 bytes)
        if (pos + 8 > data.length) break;
        actualBoxSize = (data[pos] << 56) |
            (data[pos + 1] << 48) |
            (data[pos + 2] << 40) |
            (data[pos + 3] << 32) |
            (data[pos + 4] << 24) |
            (data[pos + 5] << 16) |
            (data[pos + 6] << 8) |
            data[pos + 7];
        pos += 8;
        dataSize = actualBoxSize - 16;
      } else if (boxSize == 0) {
        // Box extends to end of file
        dataSize = data.length - pos;
      }

      if (dataSize < 0 || pos + dataSize > data.length) break;

      switch (boxType) {
        case 'jxlc': // Codestream
          codestreamData = Uint8List.sublistView(data, pos, pos + dataSize);
          break;
        case 'jxlp': // Partial codestream
          // Append to existing codestream
          if (codestreamData == null) {
            codestreamData = Uint8List.sublistView(data, pos, pos + dataSize);
          } else {
            final combined =
                Uint8List(codestreamData.length + dataSize);
            combined.setRange(0, codestreamData.length, codestreamData);
            combined.setRange(
                codestreamData.length,
                combined.length,
                Uint8List.sublistView(data, pos, pos + dataSize));
            codestreamData = combined;
          }
          break;
        case 'Exif': // EXIF metadata
          _onMessage('Found EXIF box');
          break;
        case 'xml ': // XMP metadata
          _onMessage('Found XMP box');
          break;
        case 'jumb': // JUMBF (metadata)
          _onMessage('Found JUMBF box');
          break;
        case 'brob': // Brotli-compressed box
          _onMessage('Found Brotli-compressed box');
          break;
      }

      pos += dataSize;
    }

    if (codestreamData == null) {
      return JxlResult.failure('No codestream found in container');
    }

    // Add signature back for codestream decoder
    final withSignature = Uint8List(codestreamData.length + 2);
    withSignature[0] = 0xFF;
    withSignature[1] = jxlCodestreamMarker;
    withSignature.setRange(2, withSignature.length, codestreamData);

    return _decodeCodestream(withSignature);
  }

  /// Reads size header
  JxlResult<JxlSizeHeader> _readSizeHeader(JxlBitReader reader) {
    try {
      final size = JxlSizeHeader();

      // Read small flag
      final small = reader.readBit() == 1;

      if (small) {
        // Small: ysize and xsize are multiples of 8, <= 256
        final ysizeDiv8Minus1 = reader.readBits(5);
        size.ysize = (ysizeDiv8Minus1 + 1) * 8;

        // Ratio
        final ratio = reader.readBits(3);
        if (ratio == 0) {
          final xsizeDiv8Minus1 = reader.readBits(5);
          size.xsize = (xsizeDiv8Minus1 + 1) * 8;
        } else {
          size.xsize = _computeXsizeFromRatio(size.ysize, ratio);
        }
      } else {
        // Large: variable encoding
        size.ysize = _readLargeSize(reader);

        // Ratio
        final ratio = reader.readBits(3);
        if (ratio == 0) {
          size.xsize = _readLargeSize(reader);
        } else {
          size.xsize = _computeXsizeFromRatio(size.ysize, ratio);
        }
      }

      return JxlResult.ok(size);
    } catch (e) {
      return JxlResult.failure('Failed to read size header: $e');
    }
  }

  /// Reads a large size value
  int _readLargeSize(JxlBitReader reader) {
    final selector = reader.readBits(2);
    switch (selector) {
      case 0:
        return 1 + reader.readBits(9);
      case 1:
        return 1 + reader.readBits(13);
      case 2:
        return 1 + reader.readBits(18);
      case 3:
        return 1 + reader.readBits(30);
      default:
        return 0;
    }
  }

  /// Computes xsize from ysize and aspect ratio
  int _computeXsizeFromRatio(int ysize, int ratio) {
    switch (ratio) {
      case 1:
        return ysize; // 1:1
      case 2:
        return (ysize * 12 / 10).round(); // 1.2:1
      case 3:
        return (ysize * 4 / 3).round(); // 4:3
      case 4:
        return (ysize * 3 / 2).round(); // 3:2
      case 5:
        return (ysize * 16 / 9).round(); // 16:9
      case 6:
        return (ysize * 5 / 4).round(); // 5:4
      case 7:
        return ysize * 2; // 2:1
      default:
        return ysize;
    }
  }

  /// Reads image metadata
  JxlResult<bool> _readImageMetadata(JxlBitReader reader, JxlSizeHeader size) {
    try {
      final info = JxlBasicInfo(
        xsize: size.xsize,
        ysize: size.ysize,
      );

      // all_default flag
      final allDefault = reader.readBit() == 1;

      if (!allDefault) {
        // extra_fields flag
        final extraFields = reader.readBit() == 1;

        if (extraFields) {
          // Orientation
          final orientation = reader.readBits(3);
          info.orientation = JxlOrientation.fromValue(orientation + 1);

          // Have intrinsic size
          final haveIntrinsicSize = reader.readBit() == 1;
          if (haveIntrinsicSize) {
            info.intrinsicXsize = _readLargeSize(reader);
            info.intrinsicYsize = _readLargeSize(reader);
          }

          // Have preview
          final havePreview = reader.readBit() == 1;
          if (havePreview) {
            info.preview = _readPreviewHeader(reader);
          }

          // Have animation
          final haveAnimation = reader.readBit() == 1;
          if (haveAnimation) {
            info.animation = _readAnimationHeader(reader);
          }
        }

        // Bit depth
        final bitDepthResult = _readBitDepth(reader);
        if (bitDepthResult.isSuccess) {
          info.bitDepth = bitDepthResult.value!;
        }

        // Modular 16-bit buffers
        reader.readBit(); // modular_16bit_buffer_sufficient

        // Number of extra channels
        info.numExtraChannels = _readExtraChannelCount(reader);

        // Read extra channel info
        for (int i = 0; i < info.numExtraChannels; i++) {
          final extraInfo = _readExtraChannelInfo(reader);
          _state.extraChannels.add(extraInfo);
          
          if (extraInfo.type == JxlExtraChannelType.alpha) {
            info.alphaBits = extraInfo.bitDepth.bitsPerSample;
            info.alphaExponentBits = extraInfo.bitDepth.exponentBitsPerSample;
            info.alphaPremultiplied = extraInfo.alphaAssociated;
          }
        }

        // XYB encoded
        final xybEncoded = reader.readBit() == 1;

        // Color encoding
        final colorResult = _readColorEncoding(reader, xybEncoded);
        if (colorResult.isSuccess) {
          _state.colorEncoding = colorResult.value;
        }

        // Tone mapping
        _readToneMapping(reader);

        // Extensions
        _readExtensions(reader);
      } else {
        // Default values
        info.bitDepth = JxlBitDepth(bitsPerSample: 8);
        _state.colorEncoding = JxlColorEncoding.sRGB();
      }

      _state.basicInfo = info;
      return JxlResult.ok(true);
    } catch (e) {
      return JxlResult.failure('Failed to read image metadata: $e');
    }
  }

  /// Reads preview header
  JxlPreviewHeader _readPreviewHeader(JxlBitReader reader) {
    final preview = JxlPreviewHeader();

    final div8 = reader.readBit() == 1;
    if (div8) {
      final ysizeDiv8 = reader.readBits(5);
      preview.ysize = ysizeDiv8 * 8;
    } else {
      final selector = reader.readBits(2);
      switch (selector) {
        case 0:
          preview.ysize = 1 + reader.readBits(6);
          break;
        case 1:
          preview.ysize = 1 + reader.readBits(8);
          break;
        case 2:
          preview.ysize = 1 + reader.readBits(10);
          break;
        case 3:
          preview.ysize = 1 + reader.readBits(12);
          break;
      }
    }

    final ratio = reader.readBits(3);
    if (ratio == 0) {
      if (div8) {
        final xsizeDiv8 = reader.readBits(5);
        preview.xsize = xsizeDiv8 * 8;
      } else {
        final selector = reader.readBits(2);
        switch (selector) {
          case 0:
            preview.xsize = 1 + reader.readBits(6);
            break;
          case 1:
            preview.xsize = 1 + reader.readBits(8);
            break;
          case 2:
            preview.xsize = 1 + reader.readBits(10);
            break;
          case 3:
            preview.xsize = 1 + reader.readBits(12);
            break;
        }
      }
    } else {
      preview.xsize = _computeXsizeFromRatio(preview.ysize, ratio);
    }

    return preview;
  }

  /// Reads animation header
  JxlAnimationHeader _readAnimationHeader(JxlBitReader reader) {
    final animation = JxlAnimationHeader();

    animation.tpsNumerator = reader.readBits(32);
    animation.tpsDenominator = reader.readBits(32);
    animation.numLoops = reader.readBits(32);
    animation.haveTimecodes = reader.readBit() == 1;

    return animation;
  }

  /// Reads bit depth info
  JxlResult<JxlBitDepth> _readBitDepth(JxlBitReader reader) {
    final bitDepth = JxlBitDepth();

    bitDepth.floatingPointSample = reader.readBit() == 1;

    if (bitDepth.floatingPointSample) {
      // Floating point
      final selector = reader.readBits(2);
      switch (selector) {
        case 0:
          bitDepth.bitsPerSample = 32;
          bitDepth.exponentBitsPerSample = 8;
          break;
        case 1:
          bitDepth.bitsPerSample = 16;
          bitDepth.exponentBitsPerSample = 5;
          break;
        case 2:
          bitDepth.bitsPerSample = 24;
          bitDepth.exponentBitsPerSample = 7;
          break;
        case 3:
          bitDepth.bitsPerSample = 1 + reader.readBits(6);
          bitDepth.exponentBitsPerSample = 1 + reader.readBits(4);
          break;
      }
    } else {
      // Integer
      final selector = reader.readBits(2);
      switch (selector) {
        case 0:
          bitDepth.bitsPerSample = 8;
          break;
        case 1:
          bitDepth.bitsPerSample = 10;
          break;
        case 2:
          bitDepth.bitsPerSample = 12;
          break;
        case 3:
          bitDepth.bitsPerSample = 1 + reader.readBits(6);
          break;
      }
    }

    return JxlResult.ok(bitDepth);
  }

  /// Reads extra channel count
  int _readExtraChannelCount(JxlBitReader reader) {
    final selector = reader.readBits(2);
    switch (selector) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2 + reader.readBits(4);
      case 3:
        return 1 + reader.readBits(12);
      default:
        return 0;
    }
  }

  /// Reads extra channel info
  JxlExtraChannelInfo _readExtraChannelInfo(JxlBitReader reader) {
    final info = JxlExtraChannelInfo();

    // all_default
    final allDefault = reader.readBit() == 1;

    if (!allDefault) {
      // Type
      final typeSelector = reader.readBits(2);
      switch (typeSelector) {
        case 0:
          info.type = JxlExtraChannelType.alpha;
          break;
        case 1:
          info.type = JxlExtraChannelType.depth;
          break;
        case 2:
          info.type = JxlExtraChannelType.spotColor;
          break;
        case 3:
          final extendedType = reader.readBits(6);
          info.type = JxlExtraChannelType.fromValue(extendedType);
          break;
      }

      // Bit depth
      final bitDepthResult = _readBitDepth(reader);
      if (bitDepthResult.isSuccess) {
        info.bitDepth = bitDepthResult.value!;
      }

      // Dim shift
      final dimShiftSelector = reader.readBits(2);
      switch (dimShiftSelector) {
        case 0:
          info.dimShift = 0;
          break;
        case 1:
          info.dimShift = 3;
          break;
        case 2:
          info.dimShift = 4;
          break;
        case 3:
          info.dimShift = 1 + reader.readBits(3);
          break;
      }

      // Name
      final hasName = reader.readBit() == 1;
      if (hasName) {
        final nameLength = reader.readBits(10);
        final nameBytes = Uint8List(nameLength);
        for (int i = 0; i < nameLength; i++) {
          nameBytes[i] = reader.readBits(8);
        }
        info.name = String.fromCharCodes(nameBytes);
      }

      // Type-specific
      if (info.type == JxlExtraChannelType.alpha) {
        info.alphaAssociated = reader.readBit() == 1;
      } else if (info.type == JxlExtraChannelType.spotColor) {
        info.spotColor = [
          _readF32(reader),
          _readF32(reader),
          _readF32(reader),
          _readF32(reader),
        ];
      } else if (info.type == JxlExtraChannelType.cfa) {
        info.cfaChannel = reader.readBits(32);
      }
    }

    return info;
  }

  /// Reads an F32 value
  double _readF32(JxlBitReader reader) {
    final bits = reader.readBits(32);
    final bytes = Uint8List(4)
      ..buffer.asByteData().setUint32(0, bits, Endian.little);
    return bytes.buffer.asByteData().getFloat32(0, Endian.little);
  }

  /// Reads color encoding
  JxlResult<JxlColorEncoding> _readColorEncoding(
      JxlBitReader reader, bool xybEncoded) {
    final encoding = JxlColorEncoding();

    // all_default
    final allDefault = reader.readBit() == 1;

    if (allDefault) {
      return JxlResult.ok(JxlColorEncoding.sRGB());
    }

    // want_icc
    final wantIcc = reader.readBit() == 1;
    if (wantIcc) {
      // ICC profile will be read separately
      _state.basicInfo?.usesOriginalProfile = true;
      return JxlResult.ok(encoding);
    }

    // Color space
    final csSelector = reader.readBits(2);
    switch (csSelector) {
      case 0:
        encoding.colorSpace = JxlColorSpace.rgb;
        break;
      case 1:
        encoding.colorSpace = JxlColorSpace.gray;
        break;
      case 2:
        encoding.colorSpace = JxlColorSpace.xyb;
        break;
      case 3:
        encoding.colorSpace = JxlColorSpace.unknown;
        break;
    }

    if (encoding.colorSpace != JxlColorSpace.xyb) {
      // White point
      final wpSelector = reader.readBits(2);
      switch (wpSelector) {
        case 0:
          encoding.whitePoint = JxlWhitePoint.d65;
          break;
        case 1:
          encoding.whitePoint = JxlWhitePoint.custom;
          encoding.whitePointX = reader.readBits(32) / 1e7;
          encoding.whitePointY = reader.readBits(32) / 1e7;
          break;
        case 2:
          encoding.whitePoint = JxlWhitePoint.e;
          break;
        case 3:
          encoding.whitePoint = JxlWhitePoint.dci;
          break;
      }

      if (encoding.colorSpace != JxlColorSpace.gray) {
        // Primaries
        final primSelector = reader.readBits(2);
        switch (primSelector) {
          case 0:
            encoding.primaries = JxlPrimaries.sRGB;
            break;
          case 1:
            encoding.primaries = JxlPrimaries.custom;
            encoding.customPrimaries = [
              reader.readBits(32) / 1e7, // rx
              reader.readBits(32) / 1e7, // ry
              reader.readBits(32) / 1e7, // gx
              reader.readBits(32) / 1e7, // gy
              reader.readBits(32) / 1e7, // bx
              reader.readBits(32) / 1e7, // by
            ];
            break;
          case 2:
            encoding.primaries = JxlPrimaries.bt2100;
            break;
          case 3:
            encoding.primaries = JxlPrimaries.p3;
            break;
        }
      }
    }

    // Transfer function
    final haveGamma = reader.readBit() == 1;
    if (haveGamma) {
      encoding.gamma = reader.readBits(24) / 1e7;
      encoding.transferFunction = JxlTransferFunction.unknown;
    } else {
      final tfSelector = reader.readBits(2);
      switch (tfSelector) {
        case 0:
          encoding.transferFunction = JxlTransferFunction.bt709;
          break;
        case 1:
          final extTf = reader.readBits(6);
          encoding.transferFunction = _mapTransferFunction(extTf);
          break;
        case 2:
          encoding.transferFunction = JxlTransferFunction.linear;
          break;
        case 3:
          encoding.transferFunction = JxlTransferFunction.sRGB;
          break;
      }
    }

    // Rendering intent
    final intentSelector = reader.readBits(2);
    encoding.renderingIntent = JxlRenderingIntent.values[intentSelector];

    return JxlResult.ok(encoding);
  }

  /// Maps extended transfer function value
  JxlTransferFunction _mapTransferFunction(int value) {
    switch (value) {
      case 1:
        return JxlTransferFunction.bt709;
      case 8:
        return JxlTransferFunction.linear;
      case 13:
        return JxlTransferFunction.sRGB;
      case 16:
        return JxlTransferFunction.pq;
      case 17:
        return JxlTransferFunction.dci;
      case 18:
        return JxlTransferFunction.hlg;
      default:
        return JxlTransferFunction.unknown;
    }
  }

  /// Reads tone mapping info
  void _readToneMapping(JxlBitReader reader) {
    // all_default
    final allDefault = reader.readBit() == 1;
    if (allDefault) return;

    // intensity_target
    _state.basicInfo?.intensityTarget = _readF16(reader);

    // min_nits
    _state.basicInfo?.minNits = _readF16(reader);

    // relative_to_max_display
    _state.basicInfo?.relativeToMaxDisplay = reader.readBit() == 1;

    // linear_below
    _state.basicInfo?.linearBelow = _readF16(reader);
  }

  /// Reads F16 from reader
  double _readF16(JxlBitReader reader) {
    return reader.readF16();
  }

  /// Reads extensions
  void _readExtensions(JxlBitReader reader) {
    final hasExtensions = reader.readBits(64);
    if (hasExtensions == 0) return;

    // Skip extension data for now
    for (int i = 0; i < 64; i++) {
      if ((hasExtensions & (1 << i)) != 0) {
        final extSize = reader.readU64();
        reader.skipBits(extSize * 8);
      }
    }
  }

  /// Reads frame header
  JxlResult<JxlFrameHeader> _readFrameHeader(JxlBitReader reader) {
    try {
      final header = JxlFrameHeader();

      // all_default
      final allDefault = reader.readBit() == 1;

      if (!allDefault) {
        // Frame type
        final frameType = reader.readBits(2);

        // Encoding
        final encoding = reader.readBits(1);
        final isModular = encoding == 1;

        // Frame flags
        _readFrameFlags(reader, isModular);

        // Blending info
        if (!_isFullFrame(reader)) {
          header.layerInfo = _readLayerInfo(reader);
        }

        // Name
        final hasName = reader.readBit() == 1;
        if (hasName) {
          header.name = _readFrameName(reader);
        }

        // Restoration filter
        _readRestorationFilter(reader);

        // Extensions
        _readExtensions(reader);
      }

      // Read TOC
      _readToc(reader);

      _state.frameHeader = header;
      return JxlResult.ok(header);
    } catch (e) {
      return JxlResult.failure('Failed to read frame header: $e');
    }
  }

  /// Reads frame flags
  void _readFrameFlags(JxlBitReader reader, bool isModular) {
    // Simplified - just skip flags for now
    reader.readBits(2); // do_ycbcr
    if (!isModular) {
      reader.readBits(2); // jpeg_upsampling
    }
  }

  /// Checks if frame is full-size
  bool _isFullFrame(JxlBitReader reader) {
    return reader.readBit() == 0;
  }

  /// Reads layer info for cropped frames
  JxlLayerInfo _readLayerInfo(JxlBitReader reader) {
    final info = JxlLayerInfo();

    info.haveCrop = reader.readBit() == 1;
    if (info.haveCrop) {
      info.cropX0 = _readLargeSize(reader);
      info.cropY0 = _readLargeSize(reader);
      info.xsize = _readLargeSize(reader);
      info.ysize = _readLargeSize(reader);
    }

    // Blend info
    final blendMode = reader.readBits(2);
    info.blendMode = JxlBlendMode.values[blendMode];

    if (info.blendMode != JxlBlendMode.replace) {
      info.blendSource = reader.readBits(2);
      info.blendAlpha = reader.readBits(2);
      info.blendClamp = reader.readBit() == 1;
    }

    // Save as reference
    info.saveAsReference = reader.readBits(2) - 1;

    return info;
  }

  /// Reads frame name
  String _readFrameName(JxlBitReader reader) {
    final length = reader.readBits(10);
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = reader.readBits(8);
    }
    return String.fromCharCodes(bytes);
  }

  /// Reads restoration filter settings
  void _readRestorationFilter(JxlBitReader reader) {
    // all_default
    final allDefault = reader.readBit() == 1;
    if (allDefault) return;

    // gab
    reader.readBit();

    // epf_iters
    reader.readBits(2);

    // Extensions (simplified)
  }

  /// Reads table of contents
  void _readToc(JxlBitReader reader) {
    // permuted
    final permuted = reader.readBit() == 1;

    // num_groups etc - simplified for now
    // This is where the actual compressed data locations are stored
  }

  /// Decodes frame pixel data
  JxlResult<bool> _decodeFrameData(JxlBitReader reader) {
    // This is a simplified decoder that creates placeholder data
    // A full implementation would decode the actual compressed data

    final info = _state.basicInfo;
    if (info == null) {
      return JxlResult.failure('No basic info available');
    }

    final width = info.xsize;
    final height = info.ysize;
    final numChannels = info.numColorChannels;

    // Create channels with default gray
    _state.frameData = List.generate(
      numChannels,
      (_) => List<double>.filled(width * height, 0.5),
    );

    // For now, create a simple gradient to indicate partial decoding
    for (int c = 0; c < numChannels; c++) {
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final idx = y * width + x;
          // Create a gradient pattern
          _state.frameData![c][idx] = (x + y) / (width + height);
        }
      }
    }

    return JxlResult.ok(true);
  }

  /// Builds final image from decoded data
  JxlResult<JxlImage> _buildImage() {
    final info = _state.basicInfo;
    final colorEncoding = _state.colorEncoding;
    final frameData = _state.frameData;

    if (info == null || colorEncoding == null || frameData == null) {
      return JxlResult.failure('Incomplete decode state');
    }

    final width = info.xsize;
    final height = info.ysize;

    // Convert float data to uint8
    final channels = <Uint8List>[];
    for (final channelData in frameData) {
      final uint8Data = Uint8List(width * height);
      for (int i = 0; i < channelData.length; i++) {
        uint8Data[i] = (channelData[i].clamp(0.0, 1.0) * 255).round();
      }
      channels.add(uint8Data);
    }

    // Build extra channels
    final extraChannels = <Uint8List>[];
    for (final extraInfo in _state.extraChannels) {
      // Create placeholder extra channel
      extraChannels.add(Uint8List(width * height)..fillRange(0, width * height, 255));
    }

    final image = JxlImage(
      width: width,
      height: height,
      info: info,
      colorEncoding: colorEncoding,
      channels: channels,
      extraChannels: extraChannels,
      extraChannelInfo: _state.extraChannels,
      iccProfile: _state.iccProfile,
    );

    return JxlResult.ok(image);
  }

  /// Logs a message
  void _onMessage(String message) {
    onMessage?.call(message);
  }
}

// ==========================================================
//   Public API
// ==========================================================

/// Decodes JPEG XL data
JxlResult<JxlImage> decodeJxl(Uint8List data) {
  final decoder = JxlDecoder();
  return decoder.decode(data);
}

/// Checks if data is valid JPEG XL
bool isValidJxl(Uint8List data) {
  return isJxl(data);
}
