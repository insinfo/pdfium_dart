// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// OpenJPEG codec and parameters.
/// 
/// Port of codec structures from openjpeg.h.
library;

import 'openjpeg_types.dart';

// ==========================================================
//   Compression Parameters
// ==========================================================

/// Compression parameters
class OpjCompressionParams {
  /// Tile size enabled
  bool tileSizeOn;
  
  /// XTOsiz - tile origin X
  int tileOriginX;
  
  /// YTOsiz - tile origin Y
  int tileOriginY;
  
  /// XTsiz - tile width
  int tileWidth;
  
  /// YTsiz - tile height
  int tileHeight;
  
  /// Allocation by rate/distortion
  bool distortionAllocation;
  
  /// Allocation by fixed layer
  bool fixedAllocation;
  
  /// Allocation by fixed quality (PSNR)
  bool fixedQuality;
  
  /// Comment for coding
  String? comment;
  
  /// Coding style
  int codingStyle;
  
  /// Progression order
  OpjProgressionOrder progressionOrder;
  
  /// Progression order changes
  List<OpjPoc> pocs;
  
  /// Number of layers
  int numLayers;
  
  /// Rates of layers
  List<double> layerRates;
  
  /// PSNR for layers
  List<double> layerDistortion;
  
  /// Number of resolutions
  int numResolutions;
  
  /// Initial code block width
  int codeBlockWidth;
  
  /// Initial code block height
  int codeBlockHeight;
  
  /// Code block style mode
  int codeBlockStyle;
  
  /// 1 = irreversible DWT 9-7, 0 = reversible 5-3
  int irreversible;
  
  /// ROI component number (-1 = none)
  int roiComponentNo;
  
  /// ROI shift value
  int roiShift;
  
  /// Number of precinct size specifications
  int numPrecincts;
  
  /// Initial precinct widths
  List<int> precinctWidth;
  
  /// Initial precinct heights
  List<int> precinctHeight;
  
  /// Image offset X
  int imageOffsetX;
  
  /// Image offset Y
  int imageOffsetY;
  
  /// Subsampling X
  int subsamplingX;
  
  /// Subsampling Y
  int subsamplingY;
  
  /// MCT (multiple component transform)
  int mct;
  
  /// Maximum size per component (0 = no limit)
  int maxComponentSize;
  
  /// Maximum codestream size (0 = no limit)
  int maxCodestreamSize;
  
  /// RSIZ value (profile)
  int rsiz;

  OpjCompressionParams()
      : tileSizeOn = false,
        tileOriginX = 0,
        tileOriginY = 0,
        tileWidth = 0,
        tileHeight = 0,
        distortionAllocation = false,
        fixedAllocation = false,
        fixedQuality = false,
        comment = null,
        codingStyle = 0,
        progressionOrder = OpjProgressionOrder.lrcp,
        pocs = [],
        numLayers = 1,
        layerRates = List.filled(100, 0.0),
        layerDistortion = List.filled(100, 0.0),
        numResolutions = 6,
        codeBlockWidth = 64,
        codeBlockHeight = 64,
        codeBlockStyle = 0,
        irreversible = 0,
        roiComponentNo = -1,
        roiShift = 0,
        numPrecincts = 0,
        precinctWidth = List.filled(opjJ2kMaxResolutionLevels, 1 << 15),
        precinctHeight = List.filled(opjJ2kMaxResolutionLevels, 1 << 15),
        imageOffsetX = 0,
        imageOffsetY = 0,
        subsamplingX = 1,
        subsamplingY = 1,
        mct = 0,
        maxComponentSize = 0,
        maxCodestreamSize = 0,
        rsiz = OpjProfile.none.value;

  /// Sets default compression parameters
  void setDefaults() {
    tileSizeOn = false;
    tileOriginX = 0;
    tileOriginY = 0;
    tileWidth = 0;
    tileHeight = 0;
    distortionAllocation = false;
    fixedAllocation = false;
    fixedQuality = false;
    codingStyle = 0;
    progressionOrder = OpjProgressionOrder.lrcp;
    numLayers = 1;
    layerRates[0] = 0;
    numResolutions = 6;
    codeBlockWidth = 64;
    codeBlockHeight = 64;
    codeBlockStyle = 0;
    irreversible = 0;
    roiComponentNo = -1;
    roiShift = 0;
    numPrecincts = 0;
    for (var i = 0; i < opjJ2kMaxResolutionLevels; i++) {
      precinctWidth[i] = 1 << 15;
      precinctHeight[i] = 1 << 15;
    }
    imageOffsetX = 0;
    imageOffsetY = 0;
    subsamplingX = 1;
    subsamplingY = 1;
    mct = 0;
    maxComponentSize = 0;
    maxCodestreamSize = 0;
    rsiz = OpjProfile.none.value;
  }
}

// ==========================================================
//   Decompression Parameters
// ==========================================================

/// Flags for decompression parameters
class DecompressionFlags {
  DecompressionFlags._();

  /// Ignore pclr/cmap/cdef boxes
  static const int ignorePclrCmapCdef = 0x0001;
  
  /// Dump flag
  static const int dump = 0x0002;
}

/// Decompression parameters
class OpjDecompressionParams {
  /// Number of highest resolution levels to discard
  int reduceLevel;
  
  /// Maximum number of quality layers to decode
  int maxLayers;
  
  /// Decoding area left boundary
  int decodingAreaX0;
  
  /// Decoding area right boundary
  int decodingAreaX1;
  
  /// Decoding area top boundary
  int decodingAreaY0;
  
  /// Decoding area bottom boundary
  int decodingAreaY1;
  
  /// Tile index to decode
  int tileIndex;
  
  /// Number of tiles to decode
  int numTilesToDecode;
  
  /// Flags
  int flags;

  OpjDecompressionParams()
      : reduceLevel = 0,
        maxLayers = 0,
        decodingAreaX0 = 0,
        decodingAreaX1 = 0,
        decodingAreaY0 = 0,
        decodingAreaY1 = 0,
        tileIndex = 0,
        numTilesToDecode = 0,
        flags = 0;

  /// Sets default decompression parameters
  void setDefaults() {
    reduceLevel = 0;
    maxLayers = 0;
    decodingAreaX0 = 0;
    decodingAreaX1 = 0;
    decodingAreaY0 = 0;
    decodingAreaY1 = 0;
    tileIndex = 0;
    numTilesToDecode = 0;
    flags = 0;
  }

  /// Whether to decode only a specific area
  bool get hasDecodingArea =>
      decodingAreaX0 != 0 ||
      decodingAreaX1 != 0 ||
      decodingAreaY0 != 0 ||
      decodingAreaY1 != 0;

  /// Whether to decode only specific tiles
  bool get hasSpecificTile => numTilesToDecode > 0;
}

// ==========================================================
//   Codestream Info
// ==========================================================

/// Packet information
class OpjPacketInfo {
  /// Packet start position (including SOP marker)
  int startPos;
  
  /// End of packet header position (including EPH marker)
  int endPhPos;
  
  /// Packet end position
  int endPos;
  
  /// Packet distortion
  double distortion;

  OpjPacketInfo({
    this.startPos = 0,
    this.endPhPos = 0,
    this.endPos = 0,
    this.distortion = 0.0,
  });
}

/// Marker information
class OpjMarkerInfo {
  /// Marker type
  int type;
  
  /// Position in codestream
  int position;
  
  /// Length (marker value included)
  int length;

  OpjMarkerInfo({
    this.type = 0,
    this.position = 0,
    this.length = 0,
  });
}

/// Tile part information
class OpjTilePartInfo {
  /// Start position of tile part
  int startPos;
  
  /// End position of tile part header
  int endHeaderPos;
  
  /// End position of tile part
  int endPos;

  OpjTilePartInfo({
    this.startPos = 0,
    this.endHeaderPos = 0,
    this.endPos = 0,
  });
}

/// Tile information
class OpjTileInfo {
  /// Tile index
  int tileIndex;
  
  /// Tile X coordinate
  int tileX;
  
  /// Tile Y coordinate
  int tileY;
  
  /// Number of tile parts
  int numTileParts;
  
  /// Current tile part number
  int currentTilePart;
  
  /// Tile parts information
  List<OpjTilePartInfo> tileParts;
  
  /// Markers in tile
  List<OpjMarkerInfo> markers;

  OpjTileInfo({
    this.tileIndex = 0,
    this.tileX = 0,
    this.tileY = 0,
    this.numTileParts = 0,
    this.currentTilePart = 0,
    List<OpjTilePartInfo>? tileParts,
    List<OpjMarkerInfo>? markers,
  })  : tileParts = tileParts ?? [],
        markers = markers ?? [];
}

/// Codestream index/information
class OpjCodestreamInfo {
  /// Main header start position
  int mainHeaderStart;
  
  /// Main header end position
  int mainHeaderEnd;
  
  /// Codestream size
  int codestreamSize;
  
  /// Image width
  int imageWidth;
  
  /// Image height
  int imageHeight;
  
  /// Number of components
  int numComponents;
  
  /// Number of tiles in X
  int numTilesX;
  
  /// Number of tiles in Y
  int numTilesY;
  
  /// Tile origin X
  int tileOriginX;
  
  /// Tile origin Y
  int tileOriginY;
  
  /// Tile width
  int tileWidth;
  
  /// Tile height
  int tileHeight;
  
  /// Number of layers
  int numLayers;
  
  /// Progression order
  OpjProgressionOrder progressionOrder;
  
  /// Tiles information
  List<OpjTileInfo> tiles;
  
  /// Main header markers
  List<OpjMarkerInfo> markers;

  OpjCodestreamInfo()
      : mainHeaderStart = 0,
        mainHeaderEnd = 0,
        codestreamSize = 0,
        imageWidth = 0,
        imageHeight = 0,
        numComponents = 0,
        numTilesX = 0,
        numTilesY = 0,
        tileOriginX = 0,
        tileOriginY = 0,
        tileWidth = 0,
        tileHeight = 0,
        numLayers = 0,
        progressionOrder = OpjProgressionOrder.lrcp,
        tiles = [],
        markers = [];

  /// Total number of tiles
  int get totalTiles => numTilesX * numTilesY;
}

// ==========================================================
//   Coding Parameters
// ==========================================================

/// Tile coding parameters
class OpjTileCodingParams {
  /// First component number
  int firstComponentNo;
  
  /// Last component number
  int lastComponentNo;
  
  /// Coding style
  int csty;
  
  /// Progression order
  OpjProgressionOrder progressionOrder;
  
  /// Number of layers
  int numLayers;
  
  /// MCT identifier
  int mct;
  
  /// Rates for layers
  List<double> rates;
  
  /// Number of POCs
  int numPocs;
  
  /// POC changes
  List<OpjPoc> pocs;
  
  /// PPT data present flag
  bool pptPresent;
  
  /// PPT data
  List<int>? pptData;
  
  /// Tile component coding parameters
  List<OpjTccp> tccps;

  OpjTileCodingParams()
      : firstComponentNo = 0,
        lastComponentNo = 0,
        csty = 0,
        progressionOrder = OpjProgressionOrder.lrcp,
        numLayers = 1,
        mct = 0,
        rates = List.filled(100, 0.0),
        numPocs = 0,
        pocs = List.generate(opjJ2kMaxPocs, (_) => OpjPoc()),
        pptPresent = false,
        pptData = null,
        tccps = [];
}

/// Coding parameters
class OpjCodingParams {
  /// Image offset X
  int tx0;
  
  /// Image offset Y
  int ty0;
  
  /// Tile width
  int tdx;
  
  /// Tile height
  int tdy;
  
  /// Comment
  String? comment;
  
  /// Number of tiles
  int numTilesX;
  int numTilesY;
  
  /// PPM data present
  bool ppmPresent;
  
  /// PPM data
  List<int>? ppmData;
  
  /// Tile coding parameters
  List<OpjTileCodingParams> tcps;

  OpjCodingParams()
      : tx0 = 0,
        ty0 = 0,
        tdx = 0,
        tdy = 0,
        comment = null,
        numTilesX = 0,
        numTilesY = 0,
        ppmPresent = false,
        ppmData = null,
        tcps = [];

  /// Gets total number of tiles
  int get totalTiles => numTilesX * numTilesY;
}
