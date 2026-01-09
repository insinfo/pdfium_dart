// Copyright 2024 The PDFium Dart Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// MQ Coder (MQC) - Arithmetic entropy coding.
/// 
/// Port of mqc.c from OpenJPEG library.
/// Implements the MQ arithmetic coder used in JPEG 2000.
library;

import 'dart:typed_data';

// ==========================================================
//   MQ Coder States
// ==========================================================

/// MQ coder state entry
class _MqcState {
  /// Probability estimate
  final int qeval;
  
  /// Next state if MPS (most probable symbol)
  final int nmps;
  
  /// Next state if LPS (least probable symbol)
  final int nlps;
  
  /// Switch flag
  final int switchFlag;

  const _MqcState(this.qeval, this.nmps, this.nlps, this.switchFlag);
}

/// MQ coder state table (47 states)
const List<_MqcState> _mqcStates = [
  _MqcState(0x5601, 1, 1, 1),
  _MqcState(0x3401, 2, 6, 0),
  _MqcState(0x1801, 3, 9, 0),
  _MqcState(0x0AC1, 4, 12, 0),
  _MqcState(0x0521, 5, 29, 0),
  _MqcState(0x0221, 38, 33, 0),
  _MqcState(0x5601, 7, 6, 1),
  _MqcState(0x5401, 8, 14, 0),
  _MqcState(0x4801, 9, 14, 0),
  _MqcState(0x3801, 10, 14, 0),
  _MqcState(0x3001, 11, 17, 0),
  _MqcState(0x2401, 12, 18, 0),
  _MqcState(0x1C01, 13, 20, 0),
  _MqcState(0x1601, 29, 21, 0),
  _MqcState(0x5601, 15, 14, 1),
  _MqcState(0x5401, 16, 14, 0),
  _MqcState(0x5101, 17, 15, 0),
  _MqcState(0x4801, 18, 16, 0),
  _MqcState(0x3801, 19, 17, 0),
  _MqcState(0x3401, 20, 18, 0),
  _MqcState(0x3001, 21, 19, 0),
  _MqcState(0x2801, 22, 19, 0),
  _MqcState(0x2401, 23, 20, 0),
  _MqcState(0x2201, 24, 21, 0),
  _MqcState(0x1C01, 25, 22, 0),
  _MqcState(0x1801, 26, 23, 0),
  _MqcState(0x1601, 27, 24, 0),
  _MqcState(0x1401, 28, 25, 0),
  _MqcState(0x1201, 29, 26, 0),
  _MqcState(0x1101, 30, 27, 0),
  _MqcState(0x0AC1, 31, 28, 0),
  _MqcState(0x09C1, 32, 29, 0),
  _MqcState(0x08A1, 33, 30, 0),
  _MqcState(0x0521, 34, 31, 0),
  _MqcState(0x0441, 35, 32, 0),
  _MqcState(0x02A1, 36, 33, 0),
  _MqcState(0x0221, 37, 34, 0),
  _MqcState(0x0141, 38, 35, 0),
  _MqcState(0x0111, 39, 36, 0),
  _MqcState(0x0085, 40, 37, 0),
  _MqcState(0x0049, 41, 38, 0),
  _MqcState(0x0025, 42, 39, 0),
  _MqcState(0x0015, 43, 40, 0),
  _MqcState(0x0009, 44, 41, 0),
  _MqcState(0x0005, 45, 42, 0),
  _MqcState(0x0001, 45, 43, 0),
  _MqcState(0x5601, 46, 46, 0),
];

// ==========================================================
//   MQ Decoder
// ==========================================================

/// MQ (arithmetic) decoder
class MqDecoder {
  /// Code register
  int _c = 0;
  
  /// Interval register
  int _a = 0;
  
  /// Counter for renormalization
  int _ct = 0;
  
  /// Input data
  Uint8List? _data;
  
  /// Current position in data
  int _pos = 0;
  
  /// End position
  int _end = 0;
  
  /// Context states (index into _mqcStates)
  final Int32List _contexts = Int32List(32);
  
  /// Current context
  int _currentCtx = 0;

  MqDecoder();

  /// Initializes the decoder with input data
  void init(Uint8List data, int start, int length) {
    _data = data;
    _pos = start;
    _end = start + length;
    
    // Initialize code register
    _c = 0;
    
    // Read first bytes into C register
    if (_pos < _end) {
      _c = (_data![_pos++] & 0xFF) << 16;
    }
    if (_pos < _end) {
      _c |= (_data![_pos++] & 0xFF) << 8;
    }
    
    _c <<= 8;
    _ct = 8;
    _a = 0x8000;
    
    // Reset all contexts to state 0
    for (var i = 0; i < _contexts.length; i++) {
      _contexts[i] = 0;
    }
  }

  /// Sets the current context
  void setContext(int ctx) {
    _currentCtx = ctx & 0x1F;
  }

  /// Resets a context to initial state
  void resetContext(int ctx, int mps) {
    _contexts[ctx & 0x1F] = mps != 0 ? 0 : 1; // State 0 or 1 based on MPS
  }

  /// Decodes a symbol
  int decode() {
    final stateIdx = _contexts[_currentCtx];
    final state = _mqcStates[stateIdx];
    final qeval = state.qeval;
    
    _a -= qeval;
    
    int symbol;
    
    if ((_c >> 16) < qeval) {
      // LPS exchange
      symbol = _lpsExchange(stateIdx);
    } else {
      _c -= qeval << 16;
      if ((_a & 0x8000) == 0) {
        // MPS exchange
        symbol = _mpsExchange(stateIdx);
      } else {
        // MPS, no renormalization needed
        symbol = stateIdx & 1; // MPS value
      }
    }
    
    return symbol;
  }

  /// Decodes a symbol in raw (bypass) mode
  int decodeRaw() {
    _ct--;
    if (_ct < 0) {
      _ct = 7;
      if (_pos < _end) {
        _c |= _data![_pos++];
      }
    }
    return (_c >> _ct) & 1;
  }

  /// LPS exchange procedure
  int _lpsExchange(int stateIdx) {
    final state = _mqcStates[stateIdx];
    int symbol;
    
    if (_a < state.qeval) {
      // MPS
      symbol = stateIdx & 1;
      _contexts[_currentCtx] = state.nmps;
    } else {
      // LPS
      symbol = 1 - (stateIdx & 1);
      if (state.switchFlag != 0) {
        _contexts[_currentCtx] = state.nlps ^ 1; // Switch MPS
      } else {
        _contexts[_currentCtx] = state.nlps;
      }
    }
    
    _a = state.qeval;
    _renormalize();
    
    return symbol;
  }

  /// MPS exchange procedure
  int _mpsExchange(int stateIdx) {
    final state = _mqcStates[stateIdx];
    int symbol;
    
    if (_a < state.qeval) {
      // LPS
      symbol = 1 - (stateIdx & 1);
      if (state.switchFlag != 0) {
        _contexts[_currentCtx] = state.nlps ^ 1;
      } else {
        _contexts[_currentCtx] = state.nlps;
      }
    } else {
      // MPS
      symbol = stateIdx & 1;
      _contexts[_currentCtx] = state.nmps;
    }
    
    _renormalize();
    
    return symbol;
  }

  /// Renormalization procedure
  void _renormalize() {
    do {
      if (_ct == 0) {
        _byteIn();
      }
      _a <<= 1;
      _c <<= 1;
      _ct--;
    } while ((_a & 0x8000) == 0);
  }

  /// Byte input procedure
  void _byteIn() {
    if (_pos < _end) {
      final byte = _data![_pos++];
      if (byte == 0xFF) {
        // Check for stuffed zero
        if (_pos < _end && _data![_pos] > 0x8F) {
          // Marker found - don't consume next byte
          _c += 0xFF00;
          _ct = 8;
        } else {
          // Stuffed zero
          if (_pos < _end) {
            _c += _data![_pos++] << 9;
          }
          _ct = 7;
        }
      } else {
        _c += byte << 8;
        _ct = 8;
      }
    } else {
      _c += 0xFF00;
      _ct = 8;
    }
  }

  /// Number of bytes decoded
  int get bytesDecoded => _pos;
}

// ==========================================================
//   MQ Encoder (for completeness)
// ==========================================================

/// MQ (arithmetic) encoder
class MqEncoder {
  /// Code register
  int _c = 0;
  
  /// Interval register
  int _a = 0;
  
  /// Counter
  int _ct = 0;
  
  /// Output buffer
  final BytesBuilder _output = BytesBuilder();
  
  /// Context states
  final Int32List _contexts = Int32List(32);
  
  /// Current context
  int _currentCtx = 0;
  
  /// Carry buffer
  int _bp = 0;

  MqEncoder();

  /// Initializes the encoder
  void init() {
    _a = 0x8000;
    _c = 0;
    _ct = 12;
    _bp = 0;
    _output.clear();
    
    for (var i = 0; i < _contexts.length; i++) {
      _contexts[i] = 0;
    }
  }

  /// Sets the current context
  void setContext(int ctx) {
    _currentCtx = ctx & 0x1F;
  }

  /// Resets a context
  void resetContext(int ctx, int mps) {
    _contexts[ctx & 0x1F] = mps != 0 ? 0 : 1;
  }

  /// Encodes a symbol
  void encode(int symbol) {
    final stateIdx = _contexts[_currentCtx];
    final state = _mqcStates[stateIdx];
    final mps = stateIdx & 1;
    
    if (symbol == mps) {
      // MPS
      _codeMps(stateIdx, state);
    } else {
      // LPS
      _codeLps(stateIdx, state);
    }
  }

  void _codeMps(int stateIdx, _MqcState state) {
    _a -= state.qeval;
    if ((_a & 0x8000) == 0) {
      if (_a < state.qeval) {
        _a = state.qeval;
      }
      _contexts[_currentCtx] = state.nmps;
      _renormalize();
    } else {
      _c += state.qeval;
    }
  }

  void _codeLps(int stateIdx, _MqcState state) {
    _a -= state.qeval;
    if (_a < state.qeval) {
      _c += state.qeval;
    } else {
      _a = state.qeval;
    }
    
    if (state.switchFlag != 0) {
      _contexts[_currentCtx] = state.nlps ^ 1;
    } else {
      _contexts[_currentCtx] = state.nlps;
    }
    
    _renormalize();
  }

  void _renormalize() {
    do {
      _a <<= 1;
      _c <<= 1;
      _ct--;
      if (_ct == 0) {
        _byteOut();
      }
    } while ((_a & 0x8000) == 0);
  }

  void _byteOut() {
    final byte = _c >> 19;
    if (byte > 0xFF) {
      _output.addByte(_bp + 1);
      while (_ct < 8) {
        _output.addByte(0x00);
        _ct += 8;
      }
      _bp = (byte & 0xFF);
    } else if (byte == 0xFF) {
      _output.addByte(_bp);
      _bp = byte;
      _ct = 7;
    } else {
      _output.addByte(_bp);
      _bp = byte;
      _ct = 8;
    }
    _c &= 0x7FFFF;
  }

  /// Flushes the encoder
  void flush() {
    _setbits();
    _c <<= _ct;
    _byteOut();
    _c <<= _ct;
    _byteOut();
    _output.addByte(_bp);
  }

  void _setbits() {
    final temp = _a + _c;
    _c |= 0xFFFF;
    if (_c >= temp) {
      _c -= 0x8000;
    }
  }

  /// Gets the encoded data
  Uint8List getEncodedData() {
    return _output.toBytes();
  }
}
