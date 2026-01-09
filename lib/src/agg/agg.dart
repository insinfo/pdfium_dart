// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG - Anti-Grain Geometry library for high-quality 2D graphics.
/// 
/// This is a Dart port of the AGG C++ library, providing:
/// - Anti-aliased polygon rasterization
/// - Path storage and manipulation
/// - Bezier curves (quadratic and cubic)
/// - Affine transformations
/// - Color types and blending
/// - Rendering buffers and pixel formats
/// 
/// ## Usage
/// 
/// ```dart
/// import 'package:pdfium_dart/src/agg/agg.dart';
/// 
/// // Create a rendering buffer
/// final buffer = Uint8List(width * height * 4);
/// final rbuf = RenderingBuffer(buffer, width, height, width * 4);
/// final pixfmt = PixfmtRgba32(rbuf);
/// final renBase = RendererBase(pixfmt);
/// 
/// // Clear to white
/// renBase.clear(Rgba8(255, 255, 255, 255));
/// 
/// // Create a path
/// final path = PathStorage();
/// path.moveTo(10, 10);
/// path.lineTo(100, 10);
/// path.lineTo(100, 100);
/// path.closePolygon();
/// 
/// // Rasterize and render
/// final ras = RasterizerScanlineAA();
/// final sl = ScanlineU8();
/// ras.addPath(path);
/// renderScanlinesAASolid(ras, sl, renBase, Rgba8(255, 0, 0, 255));
/// ```
library;

export 'agg_basics.dart' hide RowInfo;
export 'agg_math.dart';
export 'agg_trans_affine.dart';
export 'agg_color.dart';
export 'agg_path_storage.dart';
export 'agg_rendering_buffer.dart';
export 'agg_scanline.dart';
export 'agg_rasterizer.dart';
export 'agg_renderer.dart';
export 'agg_curves.dart';
