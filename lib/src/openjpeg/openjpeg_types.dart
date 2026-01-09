// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// OpenJPEG types and constants.
/// 
/// Port of openjpeg.h from OpenJPEG library.
/// JPEG 2000 codec library for encoding and decoding images.
library;

// ==========================================================
//   Constants
// ==========================================================

/// Maximum allowed size for filenames
const int opjPathLen = 4096;

/// Number of maximum resolution level authorized
const int opjJ2kMaxResolutionLevels = 33;

/// Number of maximum sub-band linked to number of resolution level
const int opjJ2kMaxBands = 3 * opjJ2kMaxResolutionLevels - 2;

/// Default number of segments
const int opjJ2kDefaultNbSegs = 10;

/// Stream chunk size (1 MB)
const int opjJ2kStreamChunkSize = 0x100000;

/// Default header size
const int opjJ2kDefaultHeaderSize = 1000;

/// Default number of MCC records
const int opjJ2kMccDefaultNbRecords = 10;

/// Default number of MCT records
const int opjJ2kMctDefaultNbRecords = 10;

/// Maximum number of POCs
const int opjJ2kMaxPocs = 32;

// ==========================================================
//   JPEG 2000 Markers
// ==========================================================

/// J2K marker values
class J2kMarker {
  J2kMarker._();

  /// Start of codestream
  static const int soc = 0xff4f;
  
  /// Start of tile-part
  static const int sot = 0xff90;
  
  /// Start of data
  static const int sod = 0xff93;
  
  /// End of codestream
  static const int eoc = 0xffd9;
  
  /// Capabilities marker
  static const int cap = 0xff50;
  
  /// Image and tile size
  static const int siz = 0xff51;
  
  /// Coding style default
  static const int cod = 0xff52;
  
  /// Coding style component
  static const int coc = 0xff53;
  
  /// Corresponding profile
  static const int cpf = 0xff59;
  
  /// Region-of-interest
  static const int rgn = 0xff5e;
  
  /// Quantization default
  static const int qcd = 0xff5c;
  
  /// Quantization component
  static const int qcc = 0xff5d;
  
  /// Progression order change
  static const int poc = 0xff5f;
  
  /// Tile-part lengths
  static const int tlm = 0xff55;
  
  /// Packet length, main header
  static const int plm = 0xff57;
  
  /// Packet length, tile-part header
  static const int plt = 0xff58;
  
  /// Packed packet headers, main header
  static const int ppm = 0xff60;
  
  /// Packed packet headers, tile-part header
  static const int ppt = 0xff61;
  
  /// Start of packet
  static const int sop = 0xff91;
  
  /// End of packet header
  static const int eph = 0xff92;
  
  /// Component registration
  static const int crg = 0xff63;
  
  /// Comment
  static const int com = 0xff64;
  
  /// Component bit depth
  static const int cbd = 0xff78;
  
  /// Multiple component collection
  static const int mcc = 0xff75;
  
  /// Multiple component transform
  static const int mct = 0xff74;
  
  /// Multiple component transform order
  static const int mco = 0xff77;
  
  /// Unknown marker
  static const int unk = 0;
}

// ==========================================================
//   JP2 Box Types
// ==========================================================

/// JP2 box types
class Jp2Box {
  Jp2Box._();

  /// JPEG 2000 Signature box
  static const int jp = 0x6a502020;
  
  /// File Type box
  static const int ftyp = 0x66747970;
  
  /// JP2 Header box (superbox)
  static const int jp2h = 0x6a703268;
  
  /// Image Header box
  static const int ihdr = 0x69686472;
  
  /// Colour Specification box
  static const int colr = 0x636f6c72;
  
  /// Channel Definition box
  static const int cdef = 0x63646566;
  
  /// Palette box
  static const int pclr = 0x70636c72;
  
  /// Component Mapping box
  static const int cmap = 0x636d6170;
  
  /// Resolution box (superbox)
  static const int res = 0x72657320;
  
  /// Capture Resolution box
  static const int resc = 0x72657363;
  
  /// Default Display Resolution box
  static const int resd = 0x72657364;
  
  /// Contiguous Codestream box
  static const int jp2c = 0x6a703263;
  
  /// Bits per component box
  static const int bpcc = 0x62706363;
  
  /// UUID box
  static const int uuid = 0x75756964;
  
  /// UUID Info box
  static const int uinf = 0x75696e66;
  
  /// UUID List box
  static const int ulst = 0x756c7374;
  
  /// URL box
  static const int url = 0x75726c20;
  
  /// XML box
  static const int xml = 0x786d6c20;
}

// ==========================================================
//   Enums
// ==========================================================

/// JPEG 2000 profiles
enum OpjProfile {
  /// No profile, conform to 15444-1
  none(0x0000),
  
  /// Profile 0
  profile0(0x0001),
  
  /// Profile 1
  profile1(0x0002),
  
  /// At least 1 extension defined in Part-2
  part2(0x8000),
  
  /// 2K cinema profile
  cinema2k(0x0003),
  
  /// 4K cinema profile
  cinema4k(0x0004),
  
  /// Scalable 2K cinema profile
  cinemaS2k(0x0005),
  
  /// Scalable 4K cinema profile
  cinemaS4k(0x0006),
  
  /// Long term storage cinema profile
  cinemaLts(0x0007),
  
  /// Single Tile Broadcast profile
  bcSingle(0x0100),
  
  /// Multi Tile Broadcast profile
  bcMulti(0x0200),
  
  /// Multi Tile Reversible Broadcast profile
  bcMultiR(0x0300),
  
  /// 2K Single Tile Lossy IMF profile
  imf2k(0x0400),
  
  /// 4K Single Tile Lossy IMF profile
  imf4k(0x0500),
  
  /// 8K Single Tile Lossy IMF profile
  imf8k(0x0600),
  
  /// 2K Reversible IMF profile
  imf2kR(0x0700),
  
  /// 4K Reversible IMF profile
  imf4kR(0x0800),
  
  /// 8K Reversible IMF profile
  imf8kR(0x0900);

  const OpjProfile(this.value);
  final int value;
}

/// Progression order
enum OpjProgressionOrder {
  /// Unknown progression order
  unknown(-1),
  
  /// Layer-resolution-component-precinct order
  lrcp(0),
  
  /// Resolution-layer-component-precinct order
  rlcp(1),
  
  /// Resolution-precinct-component-layer order
  rpcl(2),
  
  /// Precinct-component-resolution-layer order
  pcrl(3),
  
  /// Component-precinct-resolution-layer order
  cprl(4);

  const OpjProgressionOrder(this.value);
  final int value;

  static OpjProgressionOrder fromValue(int value) {
    return OpjProgressionOrder.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OpjProgressionOrder.unknown,
    );
  }
}

/// Supported image color spaces
enum OpjColorSpace {
  /// Not supported by the library
  unknown(-1),
  
  /// Not specified in the codestream
  unspecified(0),
  
  /// sRGB
  srgb(1),
  
  /// Grayscale
  gray(2),
  
  /// YUV
  sycc(3),
  
  /// e-YCC
  eycc(4),
  
  /// CMYK
  cmyk(5);

  const OpjColorSpace(this.value);
  final int value;

  static OpjColorSpace fromValue(int value) {
    return OpjColorSpace.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OpjColorSpace.unknown,
    );
  }
}

/// Supported codec formats
enum OpjCodecFormat {
  /// Unknown codec
  unknown(-1),
  
  /// JPEG-2000 codestream (read/write)
  j2k(0),
  
  /// JPT-stream (JPEG 2000, JPIP) (read only)
  jpt(1),
  
  /// JP2 file format (read/write)
  jp2(2),
  
  /// JPP-stream (JPEG 2000, JPIP)
  jpp(3),
  
  /// JPX file format (JPEG 2000 Part-2)
  jpx(4);

  const OpjCodecFormat(this.value);
  final int value;

  static OpjCodecFormat fromValue(int value) {
    return OpjCodecFormat.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OpjCodecFormat.unknown,
    );
  }
}

/// J2K decoder state
enum J2kState {
  /// No state
  none(0x0000),
  
  /// SOC marker expected
  mhsoc(0x0001),
  
  /// SIZ marker expected
  mhsiz(0x0002),
  
  /// Main header processing
  mh(0x0004),
  
  /// Tile part header SOT expected
  tphsot(0x0008),
  
  /// Tile part header processing
  tph(0x0010),
  
  /// EOC marker read
  mt(0x0020),
  
  /// No EOC expected (truncated)
  neoc(0x0040),
  
  /// Tile data expected
  data(0x0080),
  
  /// EOC reached
  eoc(0x0100),
  
  /// Error state
  error(0x8000);

  const J2kState(this.value);
  final int value;
}

/// MCT element type
enum MctElementType {
  /// Signed 16-bit integers
  int16(0),
  
  /// Signed 32-bit integers
  int32(1),
  
  /// 32-bit floats
  float32(2),
  
  /// 64-bit doubles
  float64(3);

  const MctElementType(this.value);
  final int value;
}

/// MCT array type
enum MctArrayType {
  /// Dependency transform
  dependency(0),
  
  /// Decorrelation transform
  decorrelation(1),
  
  /// Offset transform
  offset(2);

  const MctArrayType(this.value);
  final int value;
}

/// Quantization style
enum QuantizationStyle {
  /// No quantization
  none(0),
  
  /// Scalar implicit quantization
  scalarImplicit(1),
  
  /// Scalar explicit quantization
  scalarExplicit(2);

  const QuantizationStyle(this.value);
  final int value;
}

/// Code-block style flags
class CodeBlockStyle {
  CodeBlockStyle._();

  /// Selective arithmetic coding bypass
  static const int lazy = 0x01;
  
  /// Reset context probabilities on coding pass boundaries
  static const int reset = 0x02;
  
  /// Termination on each coding pass
  static const int termAll = 0x04;
  
  /// Vertically stripe causal context
  static const int vsc = 0x08;
  
  /// Predictable termination
  static const int pterm = 0x10;
  
  /// Segmentation symbols are used
  static const int segsym = 0x20;
  
  /// High throughput codeblocks
  static const int ht = 0x40;
  
  /// Mixed mode HT codeblocks
  static const int htMixed = 0x80;
}

/// Coding style flags
class CodingStyle {
  CodingStyle._();

  /// Precinct size defined
  static const int prt = 0x01;
  
  /// SOP markers present
  static const int sop = 0x02;
  
  /// EPH markers present
  static const int eph = 0x04;
}

// ==========================================================
//   Quantization
// ==========================================================

/// Quantization stepsize
class OpjStepsize {
  /// Exponent
  int exponent;
  
  /// Mantissa
  int mantissa;

  OpjStepsize({
    this.exponent = 0,
    this.mantissa = 0,
  });

  OpjStepsize.copy(OpjStepsize other)
      : exponent = other.exponent,
        mantissa = other.mantissa;
}

// ==========================================================
//   Tile-component coding parameters
// ==========================================================

/// Tile-component coding parameters
class OpjTccp {
  /// Coding style
  int csty;
  
  /// Number of resolutions
  int numResolutions;
  
  /// Code-block width
  int codeBlockWidth;
  
  /// Code-block height
  int codeBlockHeight;
  
  /// Code-block coding style
  int codeBlockStyle;
  
  /// DWT identifier (0 = 5-3 reversible, 1 = 9-7 irreversible)
  int qmfbid;
  
  /// Quantization style
  int quantStyle;
  
  /// Step sizes for quantization
  List<OpjStepsize> stepsizes;
  
  /// Number of guard bits
  int numGuardBits;
  
  /// ROI shift
  int roiShift;
  
  /// Precinct width (for each resolution level)
  List<int> precinctWidth;
  
  /// Precinct height (for each resolution level)
  List<int> precinctHeight;

  OpjTccp()
      : csty = 0,
        numResolutions = 6,
        codeBlockWidth = 64,
        codeBlockHeight = 64,
        codeBlockStyle = 0,
        qmfbid = 0,
        quantStyle = 0,
        stepsizes = List.generate(opjJ2kMaxBands, (_) => OpjStepsize()),
        numGuardBits = 2,
        roiShift = 0,
        precinctWidth = List.filled(opjJ2kMaxResolutionLevels, 1 << 15),
        precinctHeight = List.filled(opjJ2kMaxResolutionLevels, 1 << 15);
}

// ==========================================================
//   Progression Order Change
// ==========================================================

/// Progression order change
class OpjPoc {
  /// Resolution number start
  int resno0;
  
  /// Component number start
  int compno0;
  
  /// Layer number end
  int layno1;
  
  /// Resolution number end
  int resno1;
  
  /// Component number end
  int compno1;
  
  /// Layer number start
  int layno0;
  
  /// Precinct number start
  int precno0;
  
  /// Precinct number end
  int precno1;
  
  /// Progression order at start
  OpjProgressionOrder prg;
  
  /// Progression order at end
  OpjProgressionOrder prg1;
  
  /// Tile number
  int tile;
  
  /// Tile x0
  int tx0;
  
  /// Tile x1
  int tx1;
  
  /// Tile y0
  int ty0;
  
  /// Tile y1
  int ty1;

  OpjPoc()
      : resno0 = 0,
        compno0 = 0,
        layno1 = 0,
        resno1 = 0,
        compno1 = 0,
        layno0 = 0,
        precno0 = 0,
        precno1 = 0,
        prg = OpjProgressionOrder.lrcp,
        prg1 = OpjProgressionOrder.lrcp,
        tile = 1,
        tx0 = 0,
        tx1 = 0,
        ty0 = 0,
        ty1 = 0;
}

// ==========================================================
//   Result types
// ==========================================================

/// Result of an OpenJPEG operation
class OpjResult<T> {
  final T? value;
  final String? error;
  final bool success;

  const OpjResult.success(this.value)
      : error = null,
        success = true;

  const OpjResult.failure(this.error)
      : value = null,
        success = false;

  bool get isSuccess => success;
  bool get isFailure => !success;
}

/// Event/message severity
enum OpjMessageLevel {
  /// Error message
  error,
  
  /// Warning message
  warning,
  
  /// Info message
  info,
}

/// Message callback
typedef OpjMessageCallback = void Function(
  OpjMessageLevel level,
  String message,
);
