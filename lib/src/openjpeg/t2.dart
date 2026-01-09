// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Tier-2 coding (T2) - Packet parsing and rate control.
/// 
/// Port of t2.c from OpenJPEG library.
/// Implements packet header parsing for JPEG 2000.
library;

import 'dart:typed_data';

import 'openjpeg_stream.dart';
import 'openjpeg_types.dart';
import 't1.dart';

// ==========================================================
//   Packet structures
// ==========================================================

/// Packet information for a layer/resolution/component/precinct
class T2Packet {
  /// Whether packet is present
  bool present;
  
  /// Packet length
  int length;
  
  /// Packet header length
  int headerLength;
  
  /// Code-blocks included in this packet
  List<T2PacketCodeBlock> codeBlocks;

  T2Packet({
    this.present = false,
    this.length = 0,
    this.headerLength = 0,
    List<T2PacketCodeBlock>? codeBlocks,
  }) : codeBlocks = codeBlocks ?? [];
}

/// Code-block info within a packet
class T2PacketCodeBlock {
  /// Code-block index
  int cblkIndex;
  
  /// Number of passes included
  int numPassesIncluded;
  
  /// Length of data
  int dataLength;
  
  /// Number of zero bit-planes
  int numZeroBitPlanes;

  T2PacketCodeBlock({
    this.cblkIndex = 0,
    this.numPassesIncluded = 0,
    this.dataLength = 0,
    this.numZeroBitPlanes = 0,
  });
}

// ==========================================================
//   T2 Decoder
// ==========================================================

/// Tier-2 decoder for packet parsing
class T2Decoder {
  /// Bit reader state
  int _bitBuffer = 0;
  int _bitCount = 0;
  
  /// Data stream
  Uint8List? _data;
  int _dataPos = 0;
  int _dataLen = 0;

  T2Decoder();

  /// Decodes packets for a tile
  bool decodePackets(
    Uint8List data,
    int tileIndex,
    int numResolutions,
    int numLayers,
    int numComponents,
    OpjProgressionOrder progressionOrder,
    List<T2Packet> Function(int layer, int res, int comp, int prec) getPacket,
    void Function(int layer, int res, int comp, int prec, T2Packet packet) onPacketDecoded,
  ) {
    _data = data;
    _dataPos = 0;
    _dataLen = data.length;
    _bitBuffer = 0;
    _bitCount = 0;

    // Decode packets according to progression order
    switch (progressionOrder) {
      case OpjProgressionOrder.lrcp:
        return _decodeLrcp(numLayers, numResolutions, numComponents, getPacket, onPacketDecoded);
      case OpjProgressionOrder.rlcp:
        return _decodeRlcp(numLayers, numResolutions, numComponents, getPacket, onPacketDecoded);
      case OpjProgressionOrder.rpcl:
        return _decodeRpcl(numLayers, numResolutions, numComponents, getPacket, onPacketDecoded);
      case OpjProgressionOrder.pcrl:
        return _decodePcrl(numLayers, numResolutions, numComponents, getPacket, onPacketDecoded);
      case OpjProgressionOrder.cprl:
        return _decodeCprl(numLayers, numResolutions, numComponents, getPacket, onPacketDecoded);
      default:
        return false;
    }
  }

  bool _decodeLrcp(
    int numLayers,
    int numResolutions,
    int numComponents,
    List<T2Packet> Function(int, int, int, int) getPacket,
    void Function(int, int, int, int, T2Packet) onPacketDecoded,
  ) {
    for (var layer = 0; layer < numLayers; layer++) {
      for (var res = 0; res < numResolutions; res++) {
        for (var comp = 0; comp < numComponents; comp++) {
          // Simplified: assume one precinct per resolution
          for (var prec = 0; prec < 1; prec++) {
            if (!_decodePacket(layer, res, comp, prec, getPacket, onPacketDecoded)) {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  bool _decodeRlcp(
    int numLayers,
    int numResolutions,
    int numComponents,
    List<T2Packet> Function(int, int, int, int) getPacket,
    void Function(int, int, int, int, T2Packet) onPacketDecoded,
  ) {
    for (var res = 0; res < numResolutions; res++) {
      for (var layer = 0; layer < numLayers; layer++) {
        for (var comp = 0; comp < numComponents; comp++) {
          for (var prec = 0; prec < 1; prec++) {
            if (!_decodePacket(layer, res, comp, prec, getPacket, onPacketDecoded)) {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  bool _decodeRpcl(
    int numLayers,
    int numResolutions,
    int numComponents,
    List<T2Packet> Function(int, int, int, int) getPacket,
    void Function(int, int, int, int, T2Packet) onPacketDecoded,
  ) {
    for (var res = 0; res < numResolutions; res++) {
      for (var prec = 0; prec < 1; prec++) {
        for (var comp = 0; comp < numComponents; comp++) {
          for (var layer = 0; layer < numLayers; layer++) {
            if (!_decodePacket(layer, res, comp, prec, getPacket, onPacketDecoded)) {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  bool _decodePcrl(
    int numLayers,
    int numResolutions,
    int numComponents,
    List<T2Packet> Function(int, int, int, int) getPacket,
    void Function(int, int, int, int, T2Packet) onPacketDecoded,
  ) {
    for (var prec = 0; prec < 1; prec++) {
      for (var comp = 0; comp < numComponents; comp++) {
        for (var res = 0; res < numResolutions; res++) {
          for (var layer = 0; layer < numLayers; layer++) {
            if (!_decodePacket(layer, res, comp, prec, getPacket, onPacketDecoded)) {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  bool _decodeCprl(
    int numLayers,
    int numResolutions,
    int numComponents,
    List<T2Packet> Function(int, int, int, int) getPacket,
    void Function(int, int, int, int, T2Packet) onPacketDecoded,
  ) {
    for (var comp = 0; comp < numComponents; comp++) {
      for (var prec = 0; prec < 1; prec++) {
        for (var res = 0; res < numResolutions; res++) {
          for (var layer = 0; layer < numLayers; layer++) {
            if (!_decodePacket(layer, res, comp, prec, getPacket, onPacketDecoded)) {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  bool _decodePacket(
    int layer,
    int res,
    int comp,
    int prec,
    List<T2Packet> Function(int, int, int, int) getPacket,
    void Function(int, int, int, int, T2Packet) onPacketDecoded,
  ) {
    if (_dataPos >= _dataLen) {
      return true; // End of data
    }

    // Read packet header
    _byteAlign();
    
    // Read packet present bit
    final present = _readBit();
    
    final packet = T2Packet(present: present != 0);
    
    if (!packet.present) {
      onPacketDecoded(layer, res, comp, prec, packet);
      return true;
    }

    // TODO: Full packet header parsing
    // For now, we'll do simplified parsing
    final headerStart = _dataPos;
    
    // Skip to packet data (find 0xFF91/0xFF92 markers or end)
    while (_dataPos < _dataLen - 1) {
      if (_data![_dataPos] == 0xFF) {
        final next = _data![_dataPos + 1];
        if (next == 0x91 || next == 0x92) {
          // SOP or EPH marker - skip
          _dataPos += 2;
          break;
        }
      }
      _dataPos++;
    }
    
    packet.headerLength = _dataPos - headerStart;
    
    onPacketDecoded(layer, res, comp, prec, packet);
    return true;
  }

  int _readBit() {
    if (_bitCount == 0) {
      if (_dataPos >= _dataLen) return 0;
      _bitBuffer = _data![_dataPos++];
      _bitCount = 8;
      
      // Handle bit stuffing after 0xFF
      if (_dataPos > 1 && _data![_dataPos - 2] == 0xFF) {
        _bitCount = 7;
      }
    }
    
    _bitCount--;
    return (_bitBuffer >> _bitCount) & 1;
  }

  int _readBits(int n) {
    var result = 0;
    for (var i = 0; i < n; i++) {
      result = (result << 1) | _readBit();
    }
    return result;
  }

  void _byteAlign() {
    _bitCount = 0;
    _bitBuffer = 0;
  }

  /// Current position in data
  int get position => _dataPos;
}

// ==========================================================
//   Packet Iterator
// ==========================================================

/// Iterates through packets in progression order
class PacketIterator {
  final int numLayers;
  final int numResolutions;
  final int numComponents;
  final int numPrecincts;
  final OpjProgressionOrder progressionOrder;
  
  int _layer = 0;
  int _resolution = 0;
  int _component = 0;
  int _precinct = 0;
  bool _done = false;

  PacketIterator({
    required this.numLayers,
    required this.numResolutions,
    required this.numComponents,
    this.numPrecincts = 1,
    this.progressionOrder = OpjProgressionOrder.lrcp,
  });

  bool get isDone => _done;
  
  int get layer => _layer;
  int get resolution => _resolution;
  int get component => _component;
  int get precinct => _precinct;

  /// Advances to next packet
  void next() {
    if (_done) return;

    switch (progressionOrder) {
      case OpjProgressionOrder.lrcp:
        _nextLrcp();
        break;
      case OpjProgressionOrder.rlcp:
        _nextRlcp();
        break;
      case OpjProgressionOrder.rpcl:
        _nextRpcl();
        break;
      case OpjProgressionOrder.pcrl:
        _nextPcrl();
        break;
      case OpjProgressionOrder.cprl:
        _nextCprl();
        break;
      default:
        _done = true;
    }
  }

  void _nextLrcp() {
    _precinct++;
    if (_precinct >= numPrecincts) {
      _precinct = 0;
      _component++;
      if (_component >= numComponents) {
        _component = 0;
        _resolution++;
        if (_resolution >= numResolutions) {
          _resolution = 0;
          _layer++;
          if (_layer >= numLayers) {
            _done = true;
          }
        }
      }
    }
  }

  void _nextRlcp() {
    _precinct++;
    if (_precinct >= numPrecincts) {
      _precinct = 0;
      _component++;
      if (_component >= numComponents) {
        _component = 0;
        _layer++;
        if (_layer >= numLayers) {
          _layer = 0;
          _resolution++;
          if (_resolution >= numResolutions) {
            _done = true;
          }
        }
      }
    }
  }

  void _nextRpcl() {
    _layer++;
    if (_layer >= numLayers) {
      _layer = 0;
      _component++;
      if (_component >= numComponents) {
        _component = 0;
        _precinct++;
        if (_precinct >= numPrecincts) {
          _precinct = 0;
          _resolution++;
          if (_resolution >= numResolutions) {
            _done = true;
          }
        }
      }
    }
  }

  void _nextPcrl() {
    _layer++;
    if (_layer >= numLayers) {
      _layer = 0;
      _resolution++;
      if (_resolution >= numResolutions) {
        _resolution = 0;
        _component++;
        if (_component >= numComponents) {
          _component = 0;
          _precinct++;
          if (_precinct >= numPrecincts) {
            _done = true;
          }
        }
      }
    }
  }

  void _nextCprl() {
    _layer++;
    if (_layer >= numLayers) {
      _layer = 0;
      _resolution++;
      if (_resolution >= numResolutions) {
        _resolution = 0;
        _precinct++;
        if (_precinct >= numPrecincts) {
          _precinct = 0;
          _component++;
          if (_component >= numComponents) {
            _done = true;
          }
        }
      }
    }
  }

  /// Resets the iterator
  void reset() {
    _layer = 0;
    _resolution = 0;
    _component = 0;
    _precinct = 0;
    _done = false;
  }
}
