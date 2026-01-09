// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tile Coder/Decoder (TCD) - Tile processing.
/// 
/// Port of tcd.c from OpenJPEG library.
/// Handles tile-level encoding/decoding coordination.
library;

import 'dart:typed_data';

import 'dwt.dart';
import 'openjpeg_codec.dart';
import 'openjpeg_image.dart';
import 'openjpeg_types.dart';
import 't1.dart';
import 't2.dart';

/// Component information for tile decoding
class TcdComponentInfo {
  int dx;
  int dy;
  int precision;
  bool signed;

  TcdComponentInfo({
    this.dx = 1,
    this.dy = 1,
    this.precision = 8,
    this.signed = false,
  });
}

// ==========================================================
//   TCD Structures
// ==========================================================

/// Tile component resolution level
class TcdResolution {
  /// X0 coordinate
  int x0;
  
  /// Y0 coordinate
  int y0;
  
  /// X1 coordinate
  int x1;
  
  /// Y1 coordinate
  int y1;
  
  /// Number of precincts in X
  int numPrecinctsX;
  
  /// Number of precincts in Y
  int numPrecinctsY;
  
  /// Bands in this resolution
  List<TcdBand> bands;

  TcdResolution({
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.numPrecinctsX = 1,
    this.numPrecinctsY = 1,
    List<TcdBand>? bands,
  }) : bands = bands ?? [];

  int get width => x1 - x0;
  int get height => y1 - y0;
}

/// Tile component band (subband)
class TcdBand {
  /// X0 coordinate
  int x0;
  
  /// Y0 coordinate
  int y0;
  
  /// X1 coordinate
  int x1;
  
  /// Y1 coordinate
  int y1;
  
  /// Band number (0-3)
  int bandNo;
  
  /// Step size
  double stepSize;
  
  /// Number of significant bit-planes
  int numbps;
  
  /// Precincts in this band
  List<TcdPrecinct> precincts;

  TcdBand({
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.bandNo = 0,
    this.stepSize = 1.0,
    this.numbps = 0,
    List<TcdPrecinct>? precincts,
  }) : precincts = precincts ?? [];

  int get width => x1 - x0;
  int get height => y1 - y0;
}

/// Precinct within a band
class TcdPrecinct {
  /// X0 coordinate
  int x0;
  
  /// Y0 coordinate
  int y0;
  
  /// X1 coordinate
  int x1;
  
  /// Y1 coordinate
  int y1;
  
  /// Code-blocks in this precinct
  List<T1CodeBlock> codeBlocks;

  TcdPrecinct({
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    List<T1CodeBlock>? codeBlocks,
  }) : codeBlocks = codeBlocks ?? [];

  int get width => x1 - x0;
  int get height => y1 - y0;
}

/// Tile component
class TcdTileComponent {
  /// X0 coordinate
  int x0;
  
  /// Y0 coordinate
  int y0;
  
  /// X1 coordinate
  int x1;
  
  /// Y1 coordinate
  int y1;
  
  /// Component data
  Int32List? data;
  
  /// Resolutions
  List<TcdResolution> resolutions;
  
  /// Number of resolutions
  int numResolutions;

  TcdTileComponent({
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.data,
    List<TcdResolution>? resolutions,
    this.numResolutions = 0,
  }) : resolutions = resolutions ?? [];

  int get width => x1 - x0;
  int get height => y1 - y0;
}

// ==========================================================
//   Tile Component Decoder
// ==========================================================

/// Decodes a single tile
class TileComponentDecoder {
  final int tileIndex;
  final int tileX;
  final int tileY;
  final int tx0;
  final int ty0;
  final int tileWidth;
  final int tileHeight;
  final int imageX0;
  final int imageY0;
  final int imageX1;
  final int imageY1;
  final int numComponents;
  final List<TcdComponentInfo> components;
  final OpjTileCodingParams tcp;
  
  /// Tile components
  final List<TcdTileComponent> _tileComps = [];
  
  /// Tile bounds
  int _tileX0 = 0;
  int _tileY0 = 0;
  int _tileX1 = 0;
  int _tileY1 = 0;

  TileComponentDecoder({
    required this.tileIndex,
    required this.tileX,
    required this.tileY,
    required this.tx0,
    required this.ty0,
    required this.tileWidth,
    required this.tileHeight,
    required this.imageX0,
    required this.imageY0,
    required this.imageX1,
    required this.imageY1,
    required this.numComponents,
    required this.components,
    required this.tcp,
  });

  /// Initializes tile structures
  bool initialize() {
    // Calculate tile bounds
    _tileX0 = _max(tx0 + tileX * tileWidth, imageX0);
    _tileY0 = _max(ty0 + tileY * tileHeight, imageY0);
    _tileX1 = _min(tx0 + (tileX + 1) * tileWidth, imageX1);
    _tileY1 = _min(ty0 + (tileY + 1) * tileHeight, imageY1);

    // Initialize each component
    for (var compno = 0; compno < numComponents; compno++) {
      final compInfo = components[compno];
      final tccp = tcp.tccps[compno];
      
      // Component bounds in component coordinates
      final compX0 = _ceilDiv(_tileX0, compInfo.dx);
      final compY0 = _ceilDiv(_tileY0, compInfo.dy);
      final compX1 = _ceilDiv(_tileX1, compInfo.dx);
      final compY1 = _ceilDiv(_tileY1, compInfo.dy);
      
      final tileComp = TcdTileComponent(
        x0: compX0,
        y0: compY0,
        x1: compX1,
        y1: compY1,
        numResolutions: tccp.numResolutions,
      );

      // Allocate data
      final size = tileComp.width * tileComp.height;
      if (size > 0) {
        tileComp.data = Int32List(size);
      }

      // Initialize resolutions
      for (var resno = 0; resno < tccp.numResolutions; resno++) {
        final levelDiff = tccp.numResolutions - 1 - resno;
        
        // Resolution bounds
        final resX0 = _ceilDivPow2(compX0, levelDiff);
        final resY0 = _ceilDivPow2(compY0, levelDiff);
        final resX1 = _ceilDivPow2(compX1, levelDiff);
        final resY1 = _ceilDivPow2(compY1, levelDiff);
        
        // Precinct sizes
        final precWidth = tccp.precinctWidth[resno];
        final precHeight = tccp.precinctHeight[resno];
        
        final numPrecX = _ceilDiv(resX1, precWidth) - (resX0 ~/ precWidth);
        final numPrecY = _ceilDiv(resY1, precHeight) - (resY0 ~/ precHeight);
        
        final resolution = TcdResolution(
          x0: resX0,
          y0: resY0,
          x1: resX1,
          y1: resY1,
          numPrecinctsX: _max(numPrecX, 1),
          numPrecinctsY: _max(numPrecY, 1),
        );

        // Initialize bands
        final numBands = resno == 0 ? 1 : 3;
        for (var bandno = 0; bandno < numBands; bandno++) {
          final band = _createBand(
            resno, 
            bandno, 
            resX0, resY0, resX1, resY1,
            tccp,
            compInfo.precision,
          );
          
          // Initialize code-blocks
          _initializeCodeBlocks(band, tccp);
          
          resolution.bands.add(band);
        }
        
        tileComp.resolutions.add(resolution);
      }
      
      _tileComps.add(tileComp);
    }

    return true;
  }

  TcdBand _createBand(
    int resno,
    int bandno,
    int resX0, int resY0, int resX1, int resY1,
    OpjTccp tccp,
    int precision,
  ) {
    int x0, y0, x1, y1;
    int bandIdx;
    
    if (resno == 0) {
      // LL band
      x0 = resX0;
      y0 = resY0;
      x1 = resX1;
      y1 = resY1;
      bandIdx = 0;
    } else {
      // HL, LH, HH bands
      final levelDiff = tccp.numResolutions - resno;
      final halfX0 = _ceilDivPow2(resX0, 1);
      final halfY0 = _ceilDivPow2(resY0, 1);
      final halfX1 = _ceilDivPow2(resX1, 1);
      final halfY1 = _ceilDivPow2(resY1, 1);
      
      switch (bandno) {
        case 0: // HL
          x0 = halfX0;
          y0 = resY0 - halfY0;
          x1 = halfX1;
          y1 = resY1 - halfY0;
          bandIdx = 1;
          break;
        case 1: // LH
          x0 = resX0 - halfX0;
          y0 = halfY0;
          x1 = resX1 - halfX0;
          y1 = halfY1;
          bandIdx = 2;
          break;
        default: // HH
          x0 = halfX0;
          y0 = halfY0;
          x1 = halfX1;
          y1 = halfY1;
          bandIdx = 3;
      }
    }

    // Calculate step size
    final globalBandIdx = resno == 0 ? 0 : (resno - 1) * 3 + bandIdx;
    final stepsize = tccp.stepsizes[globalBandIdx];
    
    double step;
    if (tccp.quantStyle == QuantizationStyle.none.value) {
      step = 1.0;
    } else {
      step = (1.0 + stepsize.mantissa / 2048.0) * 
             (1 << (precision + tccp.numGuardBits - stepsize.exponent));
    }

    return TcdBand(
      x0: _max(x0, 0),
      y0: _max(y0, 0),
      x1: _max(x1, 0),
      y1: _max(y1, 0),
      bandNo: bandIdx,
      stepSize: step,
      numbps: stepsize.exponent + tccp.numGuardBits - 1,
    );
  }

  void _initializeCodeBlocks(TcdBand band, OpjTccp tccp) {
    if (band.width <= 0 || band.height <= 0) return;

    final cbWidth = tccp.codeBlockWidth;
    final cbHeight = tccp.codeBlockHeight;
    
    final numCbX = _ceilDiv(band.width, cbWidth);
    final numCbY = _ceilDiv(band.height, cbHeight);
    
    // Create single precinct with all code-blocks
    final precinct = TcdPrecinct(
      x0: band.x0,
      y0: band.y0,
      x1: band.x1,
      y1: band.y1,
    );
    
    for (var cby = 0; cby < numCbY; cby++) {
      for (var cbx = 0; cbx < numCbX; cbx++) {
        final cblkX0 = band.x0 + cbx * cbWidth;
        final cblkY0 = band.y0 + cby * cbHeight;
        final cblkX1 = _min(cblkX0 + cbWidth, band.x1);
        final cblkY1 = _min(cblkY0 + cbHeight, band.y1);
        
        if (cblkX1 > cblkX0 && cblkY1 > cblkY0) {
          precinct.codeBlocks.add(T1CodeBlock(
            x0: cblkX0,
            y0: cblkY0,
            width: cblkX1 - cblkX0,
            height: cblkY1 - cblkY0,
          ));
        }
      }
    }
    
    band.precincts.add(precinct);
  }

  /// Decodes tile data
  bool decode(Uint8List data, OpjImage image) {
    // Simplified decoding:
    // 1. For now, just initialize with zeros
    // 2. Full implementation would:
    //    - Parse packets with T2
    //    - Decode code-blocks with T1
    //    - Apply inverse DWT
    //    - Apply inverse MCT
    
    for (var compno = 0; compno < numComponents; compno++) {
      final tileComp = _tileComps[compno];
      final tccp = tcp.tccps[compno];
      
      // Initialize tile data to zero
      if (tileComp.data != null) {
        tileComp.data!.fillRange(0, tileComp.data!.length, 0);
      }
      
      // Apply inverse DWT (if there's data)
      if (data.isNotEmpty && tileComp.data != null) {
        _applyInverseDwt(tileComp, tccp);
      }
    }

    // Apply inverse MCT if applicable
    if (tcp.mct != 0 && numComponents >= 3) {
      _applyInverseMct();
    }

    // Copy tile data to image
    _copyToImage(image);

    return true;
  }

  void _applyInverseDwt(TcdTileComponent tileComp, OpjTccp tccp) {
    if (tileComp.data == null) return;
    
    final width = tileComp.width;
    final height = tileComp.height;
    
    if (tccp.qmfbid == 1) {
      // 5-3 reversible DWT
      Dwt.decode53(tileComp.data!, width, height, tccp.numResolutions);
    } else {
      // 9-7 irreversible DWT - convert to float, process, convert back
      final floatData = Float64List(tileComp.data!.length);
      for (var i = 0; i < tileComp.data!.length; i++) {
        floatData[i] = tileComp.data![i].toDouble();
      }
      
      Dwt.decode97(floatData, width, height, tccp.numResolutions);
      
      for (var i = 0; i < tileComp.data!.length; i++) {
        tileComp.data![i] = floatData[i].round();
      }
    }
  }

  void _applyInverseMct() {
    if (_tileComps.length < 3) return;
    
    final c0 = _tileComps[0].data;
    final c1 = _tileComps[1].data;
    final c2 = _tileComps[2].data;
    
    if (c0 == null || c1 == null || c2 == null) return;
    
    final len = _min(c0.length, _min(c1.length, c2.length));
    
    // Check if reversible
    final isReversible = tcp.tccps[0].qmfbid == 1;
    
    if (isReversible) {
      Mct.inverseReversible(c0, c1, c2, len);
    } else {
      // Convert to float for irreversible MCT
      final f0 = Float64List(len);
      final f1 = Float64List(len);
      final f2 = Float64List(len);
      
      for (var i = 0; i < len; i++) {
        f0[i] = c0[i].toDouble();
        f1[i] = c1[i].toDouble();
        f2[i] = c2[i].toDouble();
      }
      
      Mct.inverseIrreversible(f0, f1, f2, len);
      
      for (var i = 0; i < len; i++) {
        c0[i] = f0[i].round();
        c1[i] = f1[i].round();
        c2[i] = f2[i].round();
      }
    }
  }

  void _copyToImage(OpjImage image) {
    for (var compno = 0; compno < numComponents; compno++) {
      final tileComp = _tileComps[compno];
      final imgComp = image.components[compno];
      
      if (tileComp.data == null || imgComp.data == null) continue;
      
      // Calculate offsets
      final tileOffsetX = tileComp.x0 - _ceilDiv(imageX0, components[compno].dx);
      final tileOffsetY = tileComp.y0 - _ceilDiv(imageY0, components[compno].dy);
      
      // Copy with offset
      for (var y = 0; y < tileComp.height; y++) {
        final imgY = tileOffsetY + y;
        if (imgY < 0 || imgY >= imgComp.height) continue;
        
        for (var x = 0; x < tileComp.width; x++) {
          final imgX = tileOffsetX + x;
          if (imgX < 0 || imgX >= imgComp.width) continue;
          
          final srcIdx = y * tileComp.width + x;
          final dstIdx = imgY * imgComp.width + imgX;
          
          imgComp.data![dstIdx] = tileComp.data![srcIdx];
        }
      }
    }
  }

  static int _max(int a, int b) => a > b ? a : b;
  static int _min(int a, int b) => a < b ? a : b;
  static int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;
  static int _ceilDivPow2(int a, int b) => (a + (1 << b) - 1) >> b;
}
