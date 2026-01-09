// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// JPEG types and constants
/// 
/// Port of libjpeg data structures and constants.
library;

// ==========================================================
//   JPEG Constants
// ==========================================================

/// DCT block size (8x8)
const int jpegDctSize = 8;

/// DCT block size squared (64 coefficients)
const int jpegDctSize2 = 64;

/// Maximum number of quantization tables
const int jpegNumQuantTables = 4;

/// Maximum number of Huffman tables
const int jpegNumHuffTables = 4;

/// Maximum components in a scan
const int jpegMaxCompsInScan = 4;

/// Maximum sampling factor
const int jpegMaxSampFactor = 4;

/// Maximum blocks per MCU
const int jpegMaxBlocksInMcu = 10;

// ==========================================================
//   JPEG Markers
// ==========================================================

/// JPEG marker codes
abstract class JpegMarker {
  // Start Of Frame markers (non-differential, Huffman coding)
  static const int sof0 = 0xFFC0; // Baseline DCT
  static const int sof1 = 0xFFC1; // Extended sequential DCT
  static const int sof2 = 0xFFC2; // Progressive DCT
  static const int sof3 = 0xFFC3; // Lossless (sequential)

  // Start Of Frame markers (differential, Huffman coding)
  static const int sof5 = 0xFFC5; // Differential sequential DCT
  static const int sof6 = 0xFFC6; // Differential progressive DCT
  static const int sof7 = 0xFFC7; // Differential lossless (sequential)

  // Start Of Frame markers (non-differential, arithmetic coding)
  static const int jpg = 0xFFC8; // Reserved for JPEG extensions
  static const int sof9 = 0xFFC9; // Extended sequential DCT
  static const int sof10 = 0xFFCA; // Progressive DCT
  static const int sof11 = 0xFFCB; // Lossless (sequential)

  // Start Of Frame markers (differential, arithmetic coding)
  static const int sof13 = 0xFFCD; // Differential sequential DCT
  static const int sof14 = 0xFFCE; // Differential progressive DCT
  static const int sof15 = 0xFFCF; // Differential lossless

  // Huffman table specification
  static const int dht = 0xFFC4; // Define Huffman Table

  // Arithmetic coding conditioning specification
  static const int dac = 0xFFCC; // Define Arithmetic Coding

  // Restart interval termination
  static const int rst0 = 0xFFD0; // Restart with modulo 8 count 0
  static const int rst1 = 0xFFD1;
  static const int rst2 = 0xFFD2;
  static const int rst3 = 0xFFD3;
  static const int rst4 = 0xFFD4;
  static const int rst5 = 0xFFD5;
  static const int rst6 = 0xFFD6;
  static const int rst7 = 0xFFD7;

  // Other markers
  static const int soi = 0xFFD8; // Start Of Image
  static const int eoi = 0xFFD9; // End Of Image
  static const int sos = 0xFFDA; // Start Of Scan
  static const int dqt = 0xFFDB; // Define Quantization Table
  static const int dnl = 0xFFDC; // Define Number of Lines
  static const int dri = 0xFFDD; // Define Restart Interval
  static const int dhp = 0xFFDE; // Define Hierarchical Progression
  static const int exp = 0xFFDF; // Expand Reference Component

  // Application segments
  static const int app0 = 0xFFE0; // JFIF marker
  static const int app1 = 0xFFE1; // EXIF marker
  static const int app2 = 0xFFE2;
  static const int app3 = 0xFFE3;
  static const int app4 = 0xFFE4;
  static const int app5 = 0xFFE5;
  static const int app6 = 0xFFE6;
  static const int app7 = 0xFFE7;
  static const int app8 = 0xFFE8;
  static const int app9 = 0xFFE9;
  static const int app10 = 0xFFEA;
  static const int app11 = 0xFFEB;
  static const int app12 = 0xFFEC;
  static const int app13 = 0xFFED; // Photoshop / IPTC
  static const int app14 = 0xFFEE; // Adobe marker
  static const int app15 = 0xFFEF;

  // JPEG extensions
  static const int jpg0 = 0xFFF0;
  static const int jpg13 = 0xFFFD;

  // Comments
  static const int com = 0xFFFE; // Comment

  // Reserved markers
  static const int tem = 0xFF01; // For temporary private use

  /// Checks if marker is SOF (Start Of Frame)
  static bool isSof(int marker) {
    return (marker >= sof0 && marker <= sof3) ||
        (marker >= sof5 && marker <= sof7) ||
        (marker >= sof9 && marker <= sof11) ||
        (marker >= sof13 && marker <= sof15);
  }

  /// Checks if marker is RST (Restart)
  static bool isRst(int marker) {
    return marker >= rst0 && marker <= rst7;
  }

  /// Checks if marker is APP (Application)
  static bool isApp(int marker) {
    return marker >= app0 && marker <= app15;
  }
}

// ==========================================================
//   JPEG Color Spaces
// ==========================================================

/// JPEG color space enumeration
enum JpegColorSpace {
  /// Unknown color space
  unknown,

  /// Grayscale
  grayscale,

  /// RGB
  rgb,

  /// YCbCr (most common for photos)
  ycbcr,

  /// CMYK
  cmyk,

  /// YCCK
  ycck,

  /// BG_RGB
  bgRgb,

  /// BG_YCC
  bgYcc,
}

// ==========================================================
//   DCT Scaling
// ==========================================================

/// DCT method enumeration
enum JpegDctMethod {
  /// Integer slow DCT
  integerSlow,

  /// Integer fast DCT
  integerFast,

  /// Floating point DCT
  floatingPoint,
}

// ==========================================================
//   Quantization Table
// ==========================================================

/// Quantization table
class JpegQuantTable {
  /// Quantization values in natural order (not zigzag)
  final List<int> values;

  /// Precision: 0 = 8-bit, 1 = 16-bit
  final int precision;

  JpegQuantTable({
    List<int>? values,
    this.precision = 0,
  }) : values = values ?? List.filled(jpegDctSize2, 0);

  /// Creates a copy of this table
  JpegQuantTable copy() {
    return JpegQuantTable(
      values: List.from(values),
      precision: precision,
    );
  }
}

// ==========================================================
//   Huffman Table
// ==========================================================

/// Huffman coding table
class JpegHuffTable {
  /// Bits[k] = # of symbols with codes of length k bits
  /// bits[0] is unused
  final List<int> bits;

  /// The symbols, in order of increasing code length
  final List<int> huffVal;

  /// Derived: maximum code length
  int maxLength = 0;

  /// Derived: huffman codes
  List<int>? huffCode;

  /// Derived: huffman sizes
  List<int>? huffSize;

  /// Derived: lookup table for fast decoding
  List<int>? lookupTable;

  /// Derived: lookup bits (log2 of table size)
  int lookupBits = 8;

  JpegHuffTable({
    List<int>? bits,
    List<int>? huffVal,
  })  : bits = bits ?? List.filled(17, 0),
        huffVal = huffVal ?? List.filled(256, 0);

  /// Creates a copy of this table
  JpegHuffTable copy() {
    return JpegHuffTable(
      bits: List.from(bits),
      huffVal: List.from(huffVal),
    );
  }

  /// Builds derived tables for decoding
  void buildDerived() {
    // Count total symbols
    int numSymbols = 0;
    for (int i = 1; i <= 16; i++) {
      numSymbols += bits[i];
    }

    // Build huffman codes
    huffCode = List.filled(numSymbols, 0);
    huffSize = List.filled(numSymbols, 0);

    int code = 0;
    int si = 0;
    int k = 0;

    for (int i = 1; i <= 16; i++) {
      for (int j = 0; j < bits[i]; j++) {
        huffCode![k] = code;
        huffSize![k] = i;
        code++;
        k++;
      }
      code <<= 1;
    }

    maxLength = 0;
    for (int i = 16; i >= 1; i--) {
      if (bits[i] != 0) {
        maxLength = i;
        break;
      }
    }

    // Build lookup table
    _buildLookupTable();
  }

  void _buildLookupTable() {
    final tableSize = 1 << lookupBits;
    lookupTable = List.filled(tableSize * 2, -1);

    int k = 0;
    for (int i = 1; i <= lookupBits && i <= 16; i++) {
      for (int j = 0; j < bits[i]; j++) {
        final code = huffCode![k];
        final sym = huffVal[k];
        final padding = lookupBits - i;
        final entries = 1 << padding;

        for (int m = 0; m < entries; m++) {
          final index = (code << padding) | m;
          lookupTable![index * 2] = sym;
          lookupTable![index * 2 + 1] = i;
        }
        k++;
      }
    }
  }
}

// ==========================================================
//   Component Info
// ==========================================================

/// Information about one color component
class JpegComponentInfo {
  /// Component identifier (0..255)
  int componentId;

  /// Index in SOF
  int componentIndex;

  /// Horizontal sampling factor (1..4)
  int hSampFactor;

  /// Vertical sampling factor (1..4)
  int vSampFactor;

  /// Quantization table selector (0..3)
  int quantTableNo;

  /// DC entropy table selector (0..3)
  int dcTableNo;

  /// AC entropy table selector (0..3)
  int acTableNo;

  /// Width in DCT blocks
  int widthInBlocks;

  /// Height in DCT blocks
  int heightInBlocks;

  /// DCT scaled width
  int dctScaledWidth;

  /// DCT scaled height
  int dctScaledHeight;

  /// Downsampled width
  int downsampledWidth;

  /// Downsampled height
  int downsampledHeight;

  /// MCU width
  int mcuWidth;

  /// MCU height
  int mcuHeight;

  /// MCU blocks
  int mcuBlocks;

  /// Last column width
  int lastColWidth;

  /// Last row height
  int lastRowHeight;

  JpegComponentInfo({
    this.componentId = 0,
    this.componentIndex = 0,
    this.hSampFactor = 1,
    this.vSampFactor = 1,
    this.quantTableNo = 0,
    this.dcTableNo = 0,
    this.acTableNo = 0,
    this.widthInBlocks = 0,
    this.heightInBlocks = 0,
    this.dctScaledWidth = jpegDctSize,
    this.dctScaledHeight = jpegDctSize,
    this.downsampledWidth = 0,
    this.downsampledHeight = 0,
    this.mcuWidth = 0,
    this.mcuHeight = 0,
    this.mcuBlocks = 0,
    this.lastColWidth = 0,
    this.lastRowHeight = 0,
  });
}

// ==========================================================
//   Scan Info
// ==========================================================

/// Information about one scan
class JpegScanInfo {
  /// Number of components in this scan
  int numComponents;

  /// Component indices for this scan
  List<int> componentIndex;

  /// Spectral selection start
  int ss;

  /// Spectral selection end
  int se;

  /// Successive approximation high
  int ah;

  /// Successive approximation low
  int al;

  JpegScanInfo({
    this.numComponents = 0,
    List<int>? componentIndex,
    this.ss = 0,
    this.se = 63,
    this.ah = 0,
    this.al = 0,
  }) : componentIndex = componentIndex ?? List.filled(jpegMaxCompsInScan, 0);
}

// ==========================================================
//   Zigzag Order
// ==========================================================

/// Zigzag order for 8x8 block
const List<int> jpegZigzag = [
  0, 1, 8, 16, 9, 2, 3, 10,
  17, 24, 32, 25, 18, 11, 4, 5,
  12, 19, 26, 33, 40, 48, 41, 34,
  27, 20, 13, 6, 7, 14, 21, 28,
  35, 42, 49, 56, 57, 50, 43, 36,
  29, 22, 15, 23, 30, 37, 44, 51,
  58, 59, 52, 45, 38, 31, 39, 46,
  53, 60, 61, 54, 47, 55, 62, 63,
];

/// Natural order (inverse of zigzag)
const List<int> jpegNaturalOrder = [
  0, 1, 5, 6, 14, 15, 27, 28,
  2, 4, 7, 13, 16, 26, 29, 42,
  3, 8, 12, 17, 25, 30, 41, 43,
  9, 11, 18, 24, 31, 40, 44, 53,
  10, 19, 23, 32, 39, 45, 52, 54,
  20, 22, 33, 38, 46, 51, 55, 60,
  21, 34, 37, 47, 50, 56, 59, 61,
  35, 36, 48, 49, 57, 58, 62, 63,
];

// ==========================================================
//   Default Quantization Tables
// ==========================================================

/// Standard luminance quantization table
const List<int> jpegStdLuminanceQuantTable = [
  16, 11, 10, 16, 24, 40, 51, 61,
  12, 12, 14, 19, 26, 58, 60, 55,
  14, 13, 16, 24, 40, 57, 69, 56,
  14, 17, 22, 29, 51, 87, 80, 62,
  18, 22, 37, 56, 68, 109, 103, 77,
  24, 35, 55, 64, 81, 104, 113, 92,
  49, 64, 78, 87, 103, 121, 120, 101,
  72, 92, 95, 98, 112, 100, 103, 99,
];

/// Standard chrominance quantization table
const List<int> jpegStdChrominanceQuantTable = [
  17, 18, 24, 47, 99, 99, 99, 99,
  18, 21, 26, 66, 99, 99, 99, 99,
  24, 26, 56, 99, 99, 99, 99, 99,
  47, 66, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99,
];

// ==========================================================
//   Default Huffman Tables
// ==========================================================

/// DC luminance bits
const List<int> jpegDcLumBits = [
  0, 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
];

/// DC luminance values
const List<int> jpegDcLumVal = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

/// DC chrominance bits
const List<int> jpegDcChromBits = [
  0, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0
];

/// DC chrominance values
const List<int> jpegDcChromVal = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

/// AC luminance bits
const List<int> jpegAcLumBits = [
  0, 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d
];

/// AC luminance values
const List<int> jpegAcLumVal = [
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12,
  0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
  0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08,
  0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
  0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16,
  0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
  0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
  0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
  0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
  0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
  0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79,
  0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
  0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
  0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
  0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
  0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
  0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4,
  0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
  0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea,
  0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
  0xf9, 0xfa,
];

/// AC chrominance bits
const List<int> jpegAcChromBits = [
  0, 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77
];

/// AC chrominance values
const List<int> jpegAcChromVal = [
  0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21,
  0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
  0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91,
  0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
  0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34,
  0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
  0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38,
  0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
  0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
  0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
  0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
  0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
  0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96,
  0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
  0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4,
  0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
  0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2,
  0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
  0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9,
  0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
  0xf9, 0xfa,
];
