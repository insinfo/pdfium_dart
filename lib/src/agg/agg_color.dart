// Anti-Grain Geometry - Version 2.4
// Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)
// Ported to Dart
//
// Permission to copy, use, modify, sell and distribute this software
// is granted provided this copyright notice appears in all copies.
// This software is provided "as is" without express or implied
// warranty, and with no claim as to its suitability for any purpose.

/// AGG Color types - RGBA colors with various precision levels.
library;

import 'dart:math' as math;
import 'agg_basics.dart';

// ============================================================================
// Component Order Constants
// ============================================================================

/// RGB component order
abstract class OrderRgb {
  static const int r = 0;
  static const int g = 1;
  static const int b = 2;
  static const int n = 3;
}

/// BGR component order
abstract class OrderBgr {
  static const int b = 0;
  static const int g = 1;
  static const int r = 2;
  static const int n = 3;
}

/// RGBA component order
abstract class OrderRgba {
  static const int r = 0;
  static const int g = 1;
  static const int b = 2;
  static const int a = 3;
  static const int n = 4;
}

/// ARGB component order
abstract class OrderArgb {
  static const int a = 0;
  static const int r = 1;
  static const int g = 2;
  static const int b = 3;
  static const int n = 4;
}

/// ABGR component order
abstract class OrderAbgr {
  static const int a = 0;
  static const int b = 1;
  static const int g = 2;
  static const int r = 3;
  static const int n = 4;
}

/// BGRA component order
abstract class OrderBgra {
  static const int b = 0;
  static const int g = 1;
  static const int r = 2;
  static const int a = 3;
  static const int n = 4;
}

// ============================================================================
// Rgba - Double precision RGBA color
// ============================================================================

/// Double precision RGBA color (0.0 - 1.0 range)
class Rgba {
  double r;
  double g;
  double b;
  double a;

  Rgba([this.r = 0.0, this.g = 0.0, this.b = 0.0, this.a = 1.0]);

  Rgba.fromRgba(Rgba c, double alpha)
    : r = c.r, g = c.g, b = c.b, a = alpha;

  Rgba.from(Rgba other)
    : r = other.r, g = other.g, b = other.b, a = other.a;

  /// Create from wavelength (nm) with optional gamma
  factory Rgba.fromWavelength(double wl, [double gamma = 1.0]) {
    final t = Rgba(0.0, 0.0, 0.0);

    if (wl >= 380.0 && wl <= 440.0) {
      t.r = -1.0 * (wl - 440.0) / (440.0 - 380.0);
      t.b = 1.0;
    } else if (wl >= 440.0 && wl <= 490.0) {
      t.g = (wl - 440.0) / (490.0 - 440.0);
      t.b = 1.0;
    } else if (wl >= 490.0 && wl <= 510.0) {
      t.g = 1.0;
      t.b = -1.0 * (wl - 510.0) / (510.0 - 490.0);
    } else if (wl >= 510.0 && wl <= 580.0) {
      t.r = (wl - 510.0) / (580.0 - 510.0);
      t.g = 1.0;
    } else if (wl >= 580.0 && wl <= 645.0) {
      t.r = 1.0;
      t.g = -1.0 * (wl - 645.0) / (645.0 - 580.0);
    } else if (wl >= 645.0 && wl <= 780.0) {
      t.r = 1.0;
    }

    double s = 1.0;
    if (wl > 700.0) {
      s = 0.3 + 0.7 * (780.0 - wl) / (780.0 - 700.0);
    } else if (wl < 420.0) {
      s = 0.3 + 0.7 * (wl - 380.0) / (420.0 - 380.0);
    }

    t.r = math.pow(t.r * s, gamma).toDouble();
    t.g = math.pow(t.g * s, gamma).toDouble();
    t.b = math.pow(t.b * s, gamma).toDouble();
    return t;
  }

  /// Clear color (all zeros)
  Rgba clear() {
    r = g = b = a = 0;
    return this;
  }

  /// Make transparent
  Rgba transparent() {
    a = 0;
    return this;
  }

  /// Set opacity
  Rgba setOpacity(double opacity) {
    if (opacity < 0) {
      a = 0;
    } else if (opacity > 1) {
      a = 1;
    } else {
      a = opacity;
    }
    return this;
  }

  double get opacity => a;

  /// Premultiply alpha
  Rgba premultiply() {
    r *= a;
    g *= a;
    b *= a;
    return this;
  }

  /// Premultiply with given alpha
  Rgba premultiplyAlpha(double alpha) {
    if (a <= 0 || alpha <= 0) {
      r = g = b = a = 0;
    } else {
      final factor = alpha / a;
      r *= factor;
      g *= factor;
      b *= factor;
      a = alpha;
    }
    return this;
  }

  /// Demultiply alpha
  Rgba demultiply() {
    if (a == 0) {
      r = g = b = 0;
    } else {
      final factor = 1.0 / a;
      r *= factor;
      g *= factor;
      b *= factor;
    }
    return this;
  }

  /// Gradient interpolation to another color
  Rgba gradient(Rgba c, double k) {
    return Rgba(
      r + (c.r - r) * k,
      g + (c.g - g) * k,
      b + (c.b - b) * k,
      a + (c.a - a) * k,
    );
  }

  /// Add colors
  Rgba operator +(Rgba c) {
    return Rgba(r + c.r, g + c.g, b + c.b, a + c.a);
  }

  /// Multiply by scalar
  Rgba operator *(double k) {
    return Rgba(r * k, g * k, b * k, a * k);
  }

  /// No color (transparent black)
  static Rgba noColor() => Rgba(0, 0, 0, 0);

  @override
  String toString() => 'Rgba($r, $g, $b, $a)';

  @override
  bool operator ==(Object other) =>
      other is Rgba && r == other.r && g == other.g && b == other.b && a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);
}

/// Create premultiplied Rgba
Rgba rgbaPre(double r, double g, double b, double a) {
  return Rgba(r, g, b, a).premultiply();
}

// ============================================================================
// Rgba8 - 8-bit per channel RGBA color
// ============================================================================

/// 8-bit per channel RGBA color (0-255 range)
class Rgba8 {
  static const int baseShift = 8;
  static const int baseScale = 1 << baseShift; // 256
  static const int baseMask = baseScale - 1; // 255
  static const int baseMsb = 1 << (baseShift - 1); // 128

  int r;
  int g;
  int b;
  int a;

  Rgba8([this.r = 0, this.g = 0, this.b = 0, this.a = baseMask]);

  Rgba8.from(Rgba8 other)
    : r = other.r, g = other.g, b = other.b, a = other.a;

  Rgba8.fromRgba8Alpha(Rgba8 c, int alpha)
    : r = c.r, g = c.g, b = c.b, a = alpha & baseMask;

  /// Create from Rgba (double precision)
  Rgba8.fromRgba(Rgba c)
    : r = uround(c.r * baseMask),
      g = uround(c.g * baseMask),
      b = uround(c.b * baseMask),
      a = uround(c.a * baseMask);

  /// Create from packed 32-bit ARGB
  Rgba8.fromPacked(int packed)
    : a = (packed >> 24) & baseMask,
      r = (packed >> 16) & baseMask,
      g = (packed >> 8) & baseMask,
      b = packed & baseMask;

  /// Convert to Rgba (double precision)
  Rgba toRgba() {
    return Rgba(r / 255.0, g / 255.0, b / 255.0, a / 255.0);
  }

  /// Convert to packed 32-bit ARGB
  int toPacked() {
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Convert to packed 32-bit ABGR
  int toPackedAbgr() {
    return (a << 24) | (b << 16) | (g << 8) | r;
  }

  /// Convert component to double
  static double toDouble(int v) => v / baseMask;

  /// Convert double to component
  static int fromDouble(double v) => uround(v * baseMask);

  /// Empty (transparent black)
  static int emptyValue() => 0;

  /// Full (opaque white component)
  static int fullValue() => baseMask;

  bool get isTransparent => a == 0;
  bool get isOpaque => a == baseMask;

  /// Invert component
  static int invertComponent(int x) => baseMask - x;

  /// Fixed-point multiply, exact over int8
  static int multiply(int a, int b) {
    int t = a * b + baseMsb;
    return ((t >> baseShift) + t) >> baseShift;
  }

  /// Fixed-point demultiply
  static int demultiplyComponent(int a, int b) {
    if (a * b == 0) return 0;
    if (a >= b) return baseMask;
    return (a * baseMask + (b >> 1)) ~/ b;
  }

  /// Downscale value
  static int downscale(int a) => a >> baseShift;

  /// Multiply color by cover
  static int multCover(int a, int cover) => multiply(a, cover);

  /// Scale cover by value
  static int scaleCover(int cover, int value) => multiply(value, cover);

  /// Interpolate p to q by a, assuming q is premultiplied by a
  static int prelerp(int p, int q, int a) {
    return p + q - multiply(p, a);
  }

  /// Interpolate p to q by a
  static int lerp(int p, int q, int a) {
    int t = (q - p) * a + baseMsb - (p > q ? 1 : 0);
    return p + (((t >> baseShift) + t) >> baseShift);
  }

  /// Clear to transparent black
  Rgba8 clear() {
    r = g = b = a = 0;
    return this;
  }

  /// Make transparent
  Rgba8 transparent() {
    a = 0;
    return this;
  }

  /// Set opacity
  Rgba8 setOpacity(double opacity) {
    if (opacity < 0) {
      a = 0;
    } else if (opacity > 1) {
      a = baseMask;
    } else {
      a = uround(opacity * baseMask);
    }
    return this;
  }

  double get opacity => a / baseMask;

  /// Premultiply alpha
  Rgba8 premultiply() {
    if (a != baseMask) {
      if (a == 0) {
        r = g = b = 0;
      } else {
        r = multiply(r, a);
        g = multiply(g, a);
        b = multiply(b, a);
      }
    }
    return this;
  }

  /// Premultiply with given alpha
  Rgba8 premultiplyAlpha(int alpha) {
    if (a != baseMask || alpha != baseMask) {
      if (a == 0 || alpha == 0) {
        r = g = b = a = 0;
      } else {
        final combinedAlpha = multiply(a, alpha);
        r = multiply(r, alpha);
        g = multiply(g, alpha);
        b = multiply(b, alpha);
        a = combinedAlpha;
      }
    }
    return this;
  }

  /// Demultiply alpha
  Rgba8 demultiply() {
    if (a != baseMask) {
      if (a == 0) {
        r = g = b = 0;
      } else {
        r = demultiplyComponent(r, a);
        g = demultiplyComponent(g, a);
        b = demultiplyComponent(b, a);
      }
    }
    return this;
  }

  /// Gradient interpolation to another color
  Rgba8 gradient(Rgba8 c, double k) {
    final ik = uround(k * baseScale);
    return Rgba8(
      lerp(r, c.r, ik),
      lerp(g, c.g, ik),
      lerp(b, c.b, ik),
      lerp(a, c.a, ik),
    );
  }

  /// Add with saturation
  Rgba8 addSaturated(Rgba8 c, int cover) {
    int cr, cg, cb, ca;
    if (cover == CoverScale.full) {
      cr = c.r;
      cg = c.g;
      cb = c.b;
      ca = c.a;
    } else {
      cr = multiply(c.r, cover);
      cg = multiply(c.g, cover);
      cb = multiply(c.b, cover);
      ca = multiply(c.a, cover);
    }
    return Rgba8(
      (r + cr > baseMask) ? baseMask : r + cr,
      (g + cg > baseMask) ? baseMask : g + cg,
      (b + cb > baseMask) ? baseMask : b + cb,
      (a + ca > baseMask) ? baseMask : a + ca,
    );
  }

  /// No color (transparent black)
  static Rgba8 noColor() => Rgba8(0, 0, 0, 0);

  @override
  String toString() => 'Rgba8($r, $g, $b, $a)';

  @override
  bool operator ==(Object other) =>
      other is Rgba8 && r == other.r && g == other.g && b == other.b && a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);
}

/// Create premultiplied Rgba8
Rgba8 rgba8Pre(int r, int g, int b, int a) {
  return Rgba8(r, g, b, a).premultiply();
}

// ============================================================================
// Rgba16 - 16-bit per channel RGBA color
// ============================================================================

/// 16-bit per channel RGBA color (0-65535 range)
class Rgba16 {
  static const int baseShift = 16;
  static const int baseScale = 1 << baseShift; // 65536
  static const int baseMask = baseScale - 1; // 65535
  static const int baseMsb = 1 << (baseShift - 1);

  int r;
  int g;
  int b;
  int a;

  Rgba16([this.r = 0, this.g = 0, this.b = 0, this.a = baseMask]);

  Rgba16.from(Rgba16 other)
    : r = other.r, g = other.g, b = other.b, a = other.a;

  /// Create from Rgba (double precision)
  Rgba16.fromRgba(Rgba c)
    : r = uround(c.r * baseMask),
      g = uround(c.g * baseMask),
      b = uround(c.b * baseMask),
      a = uround(c.a * baseMask);

  /// Create from Rgba8
  Rgba16.fromRgba8(Rgba8 c)
    : r = (c.r << 8) | c.r,
      g = (c.g << 8) | c.g,
      b = (c.b << 8) | c.b,
      a = (c.a << 8) | c.a;

  /// Convert to Rgba (double precision)
  Rgba toRgba() {
    return Rgba(r / baseMask, g / baseMask, b / baseMask, a / baseMask);
  }

  /// Convert to Rgba8
  Rgba8 toRgba8() {
    return Rgba8(r >> 8, g >> 8, b >> 8, a >> 8);
  }

  /// Fixed-point multiply
  static int multiply(int a, int b) {
    int t = a * b + baseMsb;
    return ((t >> baseShift) + t) >> baseShift;
  }

  /// Interpolate p to q by a
  static int lerp(int p, int q, int a) {
    int t = (q - p) * a + baseMsb - (p > q ? 1 : 0);
    return p + (((t >> baseShift) + t) >> baseShift);
  }

  /// Clear to transparent black
  Rgba16 clear() {
    r = g = b = a = 0;
    return this;
  }

  bool get isTransparent => a == 0;
  bool get isOpaque => a == baseMask;

  /// Premultiply alpha
  Rgba16 premultiply() {
    if (a != baseMask) {
      if (a == 0) {
        r = g = b = 0;
      } else {
        r = multiply(r, a);
        g = multiply(g, a);
        b = multiply(b, a);
      }
    }
    return this;
  }

  /// Demultiply alpha
  Rgba16 demultiply() {
    if (a != baseMask) {
      if (a == 0) {
        r = g = b = 0;
      } else {
        final inv = baseMask ~/ a;
        r = (r * inv).clamp(0, baseMask);
        g = (g * inv).clamp(0, baseMask);
        b = (b * inv).clamp(0, baseMask);
      }
    }
    return this;
  }

  /// Gradient interpolation to another color
  Rgba16 gradient(Rgba16 c, double k) {
    final ik = uround(k * baseScale);
    return Rgba16(
      lerp(r, c.r, ik),
      lerp(g, c.g, ik),
      lerp(b, c.b, ik),
      lerp(a, c.a, ik),
    );
  }

  /// No color (transparent black)
  static Rgba16 noColor() => Rgba16(0, 0, 0, 0);

  @override
  String toString() => 'Rgba16($r, $g, $b, $a)';

  @override
  bool operator ==(Object other) =>
      other is Rgba16 && r == other.r && g == other.g && b == other.b && a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);
}

// ============================================================================
// Gray8 - 8-bit grayscale color
// ============================================================================

/// 8-bit grayscale color with alpha
class Gray8 {
  static const int baseMask = 255;

  int v; // value (grayscale)
  int a; // alpha

  Gray8([this.v = 0, this.a = baseMask]);

  Gray8.from(Gray8 other) : v = other.v, a = other.a;

  /// Create from Rgba8 (using luminance)
  Gray8.fromRgba8(Rgba8 c)
    : v = ((c.r * 77 + c.g * 150 + c.b * 29) >> 8),
      a = c.a;

  /// Create from Rgba (double precision)
  Gray8.fromRgba(Rgba c)
    : v = uround((c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * baseMask),
      a = uround(c.a * baseMask);

  /// Convert to Rgba8
  Rgba8 toRgba8() => Rgba8(v, v, v, a);

  /// Convert to Rgba
  Rgba toRgba() => Rgba(v / 255.0, v / 255.0, v / 255.0, a / 255.0);

  bool get isTransparent => a == 0;
  bool get isOpaque => a == baseMask;

  /// Fixed-point multiply
  static int multiply(int a, int b) {
    int t = a * b + 128;
    return ((t >> 8) + t) >> 8;
  }

  /// Interpolate
  static int lerp(int p, int q, int a) {
    int t = (q - p) * a + 128 - (p > q ? 1 : 0);
    return p + (((t >> 8) + t) >> 8);
  }

  /// Clear
  Gray8 clear() {
    v = a = 0;
    return this;
  }

  /// Premultiply alpha
  Gray8 premultiply() {
    if (a != baseMask) {
      if (a == 0) {
        v = 0;
      } else {
        v = multiply(v, a);
      }
    }
    return this;
  }

  @override
  String toString() => 'Gray8($v, $a)';

  @override
  bool operator ==(Object other) =>
      other is Gray8 && v == other.v && a == other.a;

  @override
  int get hashCode => Object.hash(v, a);
}

// ============================================================================
// Predefined Colors
// ============================================================================

/// Predefined color constants
abstract class AggColors {
  static final Rgba8 transparent = Rgba8(0, 0, 0, 0);
  static final Rgba8 black = Rgba8(0, 0, 0, 255);
  static final Rgba8 white = Rgba8(255, 255, 255, 255);
  static final Rgba8 red = Rgba8(255, 0, 0, 255);
  static final Rgba8 green = Rgba8(0, 255, 0, 255);
  static final Rgba8 blue = Rgba8(0, 0, 255, 255);
  static final Rgba8 yellow = Rgba8(255, 255, 0, 255);
  static final Rgba8 cyan = Rgba8(0, 255, 255, 255);
  static final Rgba8 magenta = Rgba8(255, 0, 255, 255);
  static final Rgba8 gray = Rgba8(128, 128, 128, 255);
  static final Rgba8 lightGray = Rgba8(192, 192, 192, 255);
  static final Rgba8 darkGray = Rgba8(64, 64, 64, 255);
}

// ============================================================================
// Color Blending Functions
// ============================================================================

/// Blend source over destination using alpha
Rgba8 blendSrcOver(Rgba8 dst, Rgba8 src, int cover) {
  if (src.a == 0) return dst;
  
  final alpha = Rgba8.multiply(src.a, cover);
  if (alpha == Rgba8.baseMask) {
    return Rgba8(src.r, src.g, src.b, Rgba8.baseMask);
  }
  
  final invAlpha = Rgba8.baseMask - alpha;
  return Rgba8(
    Rgba8.lerp(dst.r, src.r, alpha),
    Rgba8.lerp(dst.g, src.g, alpha),
    Rgba8.lerp(dst.b, src.b, alpha),
    dst.a + alpha - Rgba8.multiply(dst.a, alpha),
  );
}

/// Blend premultiplied source over destination
Rgba8 blendSrcOverPre(Rgba8 dst, Rgba8 src, int cover) {
  final alpha = Rgba8.multiply(src.a, cover);
  final invAlpha = Rgba8.baseMask - alpha;
  
  return Rgba8(
    ((src.r * cover + dst.r * invAlpha) >> 8).clamp(0, 255),
    ((src.g * cover + dst.g * invAlpha) >> 8).clamp(0, 255),
    ((src.b * cover + dst.b * invAlpha) >> 8).clamp(0, 255),
    (dst.a + alpha - Rgba8.multiply(dst.a, alpha)).clamp(0, 255),
  );
}
