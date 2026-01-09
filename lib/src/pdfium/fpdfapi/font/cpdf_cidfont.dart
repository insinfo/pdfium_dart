// Copyright 2016 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Original code copyright 2014 Foxit Software Inc. http://www.foxitsoftware.com

/// CID character sets
enum CIDSet {
  unknown,
  gb1,
  cns1,
  japan1,
  korea1,
  unicode,
}

/// CID transformation data
class CIDTransform {
  final int cid;
  final int a;
  final int b;
  final int c;
  final int d;
  final int e;
  final int f;

  const CIDTransform({
    required this.cid,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
  });

  /// Convert CID transform byte to float
  static double cidTransformToFloat(int ch) {
    if (ch < 128) {
      return ch * (1.0 / 127);
    }
    return (-256 + ch) * (1.0 / 127);
  }
}
