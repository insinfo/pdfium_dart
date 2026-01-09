// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// OpenJPEG image structures.
/// 
/// Port of image structures from openjpeg.h.
library;

import 'dart:typed_data';

import 'openjpeg_types.dart';

// ==========================================================
//   Image Component
// ==========================================================

/// Defines a single image component
class OpjImageComponent {
  /// Horizontal separation of sample with respect to reference grid
  int dx;
  
  /// Vertical separation of sample with respect to reference grid
  int dy;
  
  /// Data width
  int width;
  
  /// Data height
  int height;
  
  /// X component offset compared to the whole image
  int x0;
  
  /// Y component offset compared to the whole image
  int y0;
  
  /// Precision: number of bits per component per pixel
  int precision;
  
  /// Signed (true) / unsigned (false)
  bool signed;
  
  /// Number of decoded resolution
  int resolutionDecoded;
  
  /// Number of division by 2 of output image compared to original
  int factor;
  
  /// Image component data
  Int32List? data;
  
  /// Alpha channel flag
  int alpha;

  OpjImageComponent({
    this.dx = 1,
    this.dy = 1,
    this.width = 0,
    this.height = 0,
    this.x0 = 0,
    this.y0 = 0,
    this.precision = 8,
    this.signed = false,
    this.resolutionDecoded = 0,
    this.factor = 0,
    this.data,
    this.alpha = 0,
  });

  /// Creates a copy of this component
  OpjImageComponent copy() {
    return OpjImageComponent(
      dx: dx,
      dy: dy,
      width: width,
      height: height,
      x0: x0,
      y0: y0,
      precision: precision,
      signed: signed,
      resolutionDecoded: resolutionDecoded,
      factor: factor,
      data: data != null ? Int32List.fromList(data!) : null,
      alpha: alpha,
    );
  }

  /// Allocates data buffer for this component
  void allocateData() {
    final size = width * height;
    if (size > 0) {
      data = Int32List(size);
    }
  }

  /// Gets pixel value at (x, y)
  int getPixel(int x, int y) {
    if (data == null || x < 0 || x >= width || y < 0 || y >= height) {
      return 0;
    }
    return data![y * width + x];
  }

  /// Sets pixel value at (x, y)
  void setPixel(int x, int y, int value) {
    if (data == null || x < 0 || x >= width || y < 0 || y >= height) {
      return;
    }
    data![y * width + x] = value;
  }

  /// Gets maximum value for this component based on precision
  int get maxValue => (1 << precision) - 1;

  /// Gets minimum value for this component (signed vs unsigned)
  int get minValue => signed ? -(1 << (precision - 1)) : 0;
}

// ==========================================================
//   Image Component Parameters
// ==========================================================

/// Component parameters used for image creation
class OpjImageComponentParams {
  /// Horizontal separation
  int dx;
  
  /// Vertical separation
  int dy;
  
  /// Data width
  int width;
  
  /// Data height
  int height;
  
  /// X offset
  int x0;
  
  /// Y offset
  int y0;
  
  /// Precision (bits per component)
  int precision;
  
  /// Signed flag
  bool signed;

  OpjImageComponentParams({
    this.dx = 1,
    this.dy = 1,
    this.width = 0,
    this.height = 0,
    this.x0 = 0,
    this.y0 = 0,
    this.precision = 8,
    this.signed = false,
  });
}

// ==========================================================
//   Image
// ==========================================================

/// Defines image data and characteristics
class OpjImage {
  /// Horizontal offset from origin of reference grid to left side
  int x0;
  
  /// Vertical offset from origin of reference grid to top side
  int y0;
  
  /// Width of the reference grid
  int x1;
  
  /// Height of the reference grid
  int y1;
  
  /// Number of components in the image
  int get numComponents => components.length;
  
  /// Color space
  OpjColorSpace colorSpace;
  
  /// Image components
  List<OpjImageComponent> components;
  
  /// ICC profile data
  Uint8List? iccProfile;

  OpjImage({
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.colorSpace = OpjColorSpace.unspecified,
    List<OpjImageComponent>? components,
    this.iccProfile,
  }) : components = components ?? [];

  /// Creates an image with the specified component parameters
  factory OpjImage.create(
    List<OpjImageComponentParams> params,
    OpjColorSpace colorSpace,
  ) {
    final image = OpjImage(colorSpace: colorSpace);
    
    for (final param in params) {
      final comp = OpjImageComponent(
        dx: param.dx,
        dy: param.dy,
        width: param.width,
        height: param.height,
        x0: param.x0,
        y0: param.y0,
        precision: param.precision,
        signed: param.signed,
      );
      comp.allocateData();
      image.components.add(comp);
    }

    // Set image bounds from first component if not set
    if (image.components.isNotEmpty) {
      final firstComp = image.components.first;
      if (image.x1 == 0) image.x1 = firstComp.width;
      if (image.y1 == 0) image.y1 = firstComp.height;
    }

    return image;
  }

  /// Image width (from reference grid)
  int get width => x1 - x0;

  /// Image height (from reference grid)
  int get height => y1 - y0;

  /// Creates a copy of this image
  OpjImage copy() {
    return OpjImage(
      x0: x0,
      y0: y0,
      x1: x1,
      y1: y1,
      colorSpace: colorSpace,
      components: components.map((c) => c.copy()).toList(),
      iccProfile: iccProfile != null ? Uint8List.fromList(iccProfile!) : null,
    );
  }

  /// Destroys the image and frees resources
  void destroy() {
    for (final comp in components) {
      comp.data = null;
    }
    components.clear();
    iccProfile = null;
  }

  /// Converts image to RGBA bytes
  Uint8List? toRgba() {
    if (components.isEmpty) return null;

    final w = width;
    final h = height;
    final result = Uint8List(w * h * 4);

    switch (numComponents) {
      case 1:
        // Grayscale
        _convertGrayscaleToRgba(result, w, h);
        break;
      case 2:
        // Grayscale + Alpha
        _convertGrayscaleAlphaToRgba(result, w, h);
        break;
      case 3:
        // RGB
        _convertRgbToRgba(result, w, h);
        break;
      case >= 4:
        // RGBA or more
        _convertFullToRgba(result, w, h);
        break;
    }

    return result;
  }

  void _convertGrayscaleToRgba(Uint8List result, int w, int h) {
    final comp = components[0];
    final data = comp.data;
    if (data == null) return;

    final shift = comp.precision > 8 ? comp.precision - 8 : 0;
    final scale = comp.precision < 8 ? 255 ~/ ((1 << comp.precision) - 1) : 1;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final srcIdx = y * comp.width + x;
        final dstIdx = (y * w + x) * 4;
        
        if (srcIdx < data.length) {
          var value = data[srcIdx];
          if (comp.signed) {
            value += (1 << (comp.precision - 1));
          }
          if (shift > 0) {
            value >>= shift;
          } else {
            value *= scale;
          }
          value = value.clamp(0, 255);
          
          result[dstIdx] = value;
          result[dstIdx + 1] = value;
          result[dstIdx + 2] = value;
          result[dstIdx + 3] = 255;
        }
      }
    }
  }

  void _convertGrayscaleAlphaToRgba(Uint8List result, int w, int h) {
    final gray = components[0];
    final alpha = components[1];
    final grayData = gray.data;
    final alphaData = alpha.data;
    if (grayData == null || alphaData == null) return;

    final grayShift = gray.precision > 8 ? gray.precision - 8 : 0;
    final alphaShift = alpha.precision > 8 ? alpha.precision - 8 : 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final srcIdx = y * gray.width + x;
        final dstIdx = (y * w + x) * 4;
        
        if (srcIdx < grayData.length) {
          var gVal = grayData[srcIdx];
          if (gray.signed) gVal += (1 << (gray.precision - 1));
          if (grayShift > 0) gVal >>= grayShift;
          gVal = gVal.clamp(0, 255);
          
          var aVal = srcIdx < alphaData.length ? alphaData[srcIdx] : 255;
          if (alpha.signed) aVal += (1 << (alpha.precision - 1));
          if (alphaShift > 0) aVal >>= alphaShift;
          aVal = aVal.clamp(0, 255);
          
          result[dstIdx] = gVal;
          result[dstIdx + 1] = gVal;
          result[dstIdx + 2] = gVal;
          result[dstIdx + 3] = aVal;
        }
      }
    }
  }

  void _convertRgbToRgba(Uint8List result, int w, int h) {
    final r = components[0];
    final g = components[1];
    final b = components[2];
    final rData = r.data;
    final gData = g.data;
    final bData = b.data;
    if (rData == null || gData == null || bData == null) return;

    final rShift = r.precision > 8 ? r.precision - 8 : 0;
    final gShift = g.precision > 8 ? g.precision - 8 : 0;
    final bShift = b.precision > 8 ? b.precision - 8 : 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final srcIdx = y * r.width + x;
        final dstIdx = (y * w + x) * 4;
        
        if (srcIdx < rData.length) {
          var rVal = rData[srcIdx];
          var gVal = srcIdx < gData.length ? gData[srcIdx] : 0;
          var bVal = srcIdx < bData.length ? bData[srcIdx] : 0;
          
          if (r.signed) rVal += (1 << (r.precision - 1));
          if (g.signed) gVal += (1 << (g.precision - 1));
          if (b.signed) bVal += (1 << (b.precision - 1));
          
          if (rShift > 0) rVal >>= rShift;
          if (gShift > 0) gVal >>= gShift;
          if (bShift > 0) bVal >>= bShift;
          
          result[dstIdx] = rVal.clamp(0, 255);
          result[dstIdx + 1] = gVal.clamp(0, 255);
          result[dstIdx + 2] = bVal.clamp(0, 255);
          result[dstIdx + 3] = 255;
        }
      }
    }
  }

  void _convertFullToRgba(Uint8List result, int w, int h) {
    final r = components[0];
    final g = components[1];
    final b = components[2];
    final a = components.length > 3 ? components[3] : null;
    
    final rData = r.data;
    final gData = g.data;
    final bData = b.data;
    final aData = a?.data;
    if (rData == null || gData == null || bData == null) return;

    final rShift = r.precision > 8 ? r.precision - 8 : 0;
    final gShift = g.precision > 8 ? g.precision - 8 : 0;
    final bShift = b.precision > 8 ? b.precision - 8 : 0;
    final aShift = a != null && a.precision > 8 ? a.precision - 8 : 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final srcIdx = y * r.width + x;
        final dstIdx = (y * w + x) * 4;
        
        if (srcIdx < rData.length) {
          var rVal = rData[srcIdx];
          var gVal = srcIdx < gData.length ? gData[srcIdx] : 0;
          var bVal = srcIdx < bData.length ? bData[srcIdx] : 0;
          var aVal = aData != null && srcIdx < aData.length ? aData[srcIdx] : 255;
          
          if (r.signed) rVal += (1 << (r.precision - 1));
          if (g.signed) gVal += (1 << (g.precision - 1));
          if (b.signed) bVal += (1 << (b.precision - 1));
          if (a != null && a.signed) aVal += (1 << (a.precision - 1));
          
          if (rShift > 0) rVal >>= rShift;
          if (gShift > 0) gVal >>= gShift;
          if (bShift > 0) bVal >>= bShift;
          if (aShift > 0) aVal >>= aShift;
          
          result[dstIdx] = rVal.clamp(0, 255);
          result[dstIdx + 1] = gVal.clamp(0, 255);
          result[dstIdx + 2] = bVal.clamp(0, 255);
          result[dstIdx + 3] = aVal.clamp(0, 255);
        }
      }
    }
  }

  /// Converts sYCC color space to sRGB
  void syccToRgb() {
    if (numComponents < 3) return;
    if (colorSpace != OpjColorSpace.sycc) return;

    final y = components[0];
    final cb = components[1];
    final cr = components[2];
    
    if (y.data == null || cb.data == null || cr.data == null) return;

    final maxVal = (1 << y.precision) - 1;
    final offset = 1 << (y.precision - 1);

    for (var i = 0; i < y.data!.length; i++) {
      final yVal = y.data![i];
      final cbIdx = i < cb.data!.length ? i : 0;
      final crIdx = i < cr.data!.length ? i : 0;
      final cbVal = cb.data![cbIdx] - offset;
      final crVal = cr.data![crIdx] - offset;

      // YCbCr to RGB conversion
      var r = (yVal + 1.402 * crVal).round();
      var g = (yVal - 0.344136 * cbVal - 0.714136 * crVal).round();
      var b = (yVal + 1.772 * cbVal).round();

      y.data![i] = r.clamp(0, maxVal);
      cb.data![cbIdx] = g.clamp(0, maxVal);
      cr.data![crIdx] = b.clamp(0, maxVal);
    }

    colorSpace = OpjColorSpace.srgb;
  }

  /// Applies CMYK to RGB conversion
  void cmykToRgb() {
    if (numComponents < 4) return;
    if (colorSpace != OpjColorSpace.cmyk) return;

    final c = components[0];
    final m = components[1];
    final yy = components[2];
    final k = components[3];

    if (c.data == null || m.data == null || yy.data == null || k.data == null) {
      return;
    }

    final maxVal = (1 << c.precision) - 1;

    for (var i = 0; i < c.data!.length; i++) {
      final cVal = c.data![i].toDouble() / maxVal;
      final mIdx = i < m.data!.length ? i : 0;
      final yIdx = i < yy.data!.length ? i : 0;
      final kIdx = i < k.data!.length ? i : 0;
      
      final mVal = m.data![mIdx].toDouble() / maxVal;
      final yVal = yy.data![yIdx].toDouble() / maxVal;
      final kVal = k.data![kIdx].toDouble() / maxVal;

      // CMYK to RGB conversion
      final r = ((1 - cVal) * (1 - kVal) * maxVal).round();
      final g = ((1 - mVal) * (1 - kVal) * maxVal).round();
      final b = ((1 - yVal) * (1 - kVal) * maxVal).round();

      c.data![i] = r.clamp(0, maxVal);
      m.data![mIdx] = g.clamp(0, maxVal);
      yy.data![yIdx] = b.clamp(0, maxVal);
    }

    // Remove K component
    components = components.sublist(0, 3);
    colorSpace = OpjColorSpace.srgb;
  }
}

// ==========================================================
//   Tile Component Data
// ==========================================================

/// Tile component data for decoding
class OpjTileComponentData {
  /// Component index
  int componentIndex;
  
  /// X0 position
  int x0;
  
  /// Y0 position
  int y0;
  
  /// X1 position
  int x1;
  
  /// Y1 position
  int y1;
  
  /// Data buffer
  Int32List? data;

  OpjTileComponentData({
    required this.componentIndex,
    this.x0 = 0,
    this.y0 = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.data,
  });

  int get width => x1 - x0;
  int get height => y1 - y0;
}

/// Tile data structure
class OpjTileData {
  /// Tile index
  int tileIndex;
  
  /// Tile X position
  int tileX;
  
  /// Tile Y position
  int tileY;
  
  /// Tile components
  List<OpjTileComponentData> components;
  
  /// Whether tile data is present
  bool hasData;

  OpjTileData({
    required this.tileIndex,
    this.tileX = 0,
    this.tileY = 0,
    List<OpjTileComponentData>? components,
    this.hasData = false,
  }) : components = components ?? [];
}
