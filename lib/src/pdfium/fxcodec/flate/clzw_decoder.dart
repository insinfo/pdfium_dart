import 'dart:typed_data';
import 'dart:math';

class CLZWDecoder {
  final Uint8List srcSpan;
  final int earlyChange;

  final Uint8List _decodeStack = Uint8List(4000);
  final Uint32List _codes = Uint32List(5021);
  Uint8List _destBuf = Uint8List(0);
  
  int _srcBitPos = 0;
  int _destBytePos = 0;
  int _stackLen = 0;
  int _codeLen = 9;
  int _currentCode = 0;

  CLZWDecoder(this.srcSpan, bool earlyChange) : earlyChange = earlyChange ? 1 : 0;

  void _addCode(int prefixCode, int appendChar) {
    if (_currentCode + earlyChange == 4094) {
      return;
    }

    _codes[_currentCode++] = (prefixCode << 16) | appendChar;
    if (_currentCode + earlyChange == 512 - 258) {
      _codeLen = 10;
    } else if (_currentCode + earlyChange == 1024 - 258) {
      _codeLen = 11;
    } else if (_currentCode + earlyChange == 2048 - 258) {
      _codeLen = 12;
    }
  }

  void _decodeString(int code) {
    while (true) {
      int index = code - 258;
      if (index < 0 || index >= _currentCode) {
        break;
      }

      int data = _codes[index];
      if (_stackLen >= _decodeStack.length) {
        return;
      }

      _decodeStack[_stackLen++] = data & 0xFF; // cast to uint8
      code = data >> 16;
    }
    if (_stackLen >= _decodeStack.length) {
      return;
    }

    _decodeStack[_stackLen++] = code & 0xFF;
  }

  bool _expandDestBuf(int additionalSize) {
    int newSize = max(_destBuf.length ~/ 2, additionalSize);
    newSize += _destBuf.length;
    
    try {
      var newBuf = Uint8List(newSize);
      newBuf.setRange(0, _destBytePos, _destBuf);
      _destBuf = newBuf;
      return true;
    } catch (e) {
      _destBuf = Uint8List(0);
      return false;
    }
  }

  bool decode() {
    int oldCode = 0xFFFFFFFF;
    int lastChar = 0;

    _destBuf = Uint8List(512);

    while (true) {
      if (_srcBitPos + _codeLen > srcSpan.length * 8) {
        break;
      }

      int bytePos = _srcBitPos ~/ 8;
      int bitPos = _srcBitPos % 8;
      int bitLeft = _codeLen;
      int code = 0;

      if (bitPos != 0) {
        bitLeft -= 8 - bitPos;
        code = (srcSpan[bytePos++] & ((1 << (8 - bitPos)) - 1)) << bitLeft;
      }
      
      if (bitLeft < 8) {
        code |= srcSpan[bytePos] >> (8 - bitLeft);
      } else {
        bitLeft -= 8;
        code |= srcSpan[bytePos++] << bitLeft;
        if (bitLeft != 0) {
          code |= srcSpan[bytePos] >> (8 - bitLeft);
        }
      }
      _srcBitPos += _codeLen;

      if (code < 256) {
        if (_destBytePos >= _destBuf.length) {
          if (!_expandDestBuf(_destBytePos - _destBuf.length + 1)) {
            return false;
          }
        }

        _destBuf[_destBytePos] = code;
        _destBytePos++;
        lastChar = code;
        if (oldCode != 0xFFFFFFFF) {
          _addCode(oldCode, lastChar);
        }
        oldCode = code;
        continue;
      }

      if (code == 256) {
        _codeLen = 9;
        _currentCode = 0;
        oldCode = 0xFFFFFFFF;
        continue;
      }

      if (code == 257) {
        break;
      }

      // Case where code is 258 or greater
      if (oldCode == 0xFFFFFFFF) {
        return false;
      }

      // DCHECK(old_code < 256 || old_code >= 258);
      _stackLen = 0;
      if (code - 258 >= _currentCode) {
        if (_stackLen < _decodeStack.length) {
          _decodeStack[_stackLen++] = lastChar;
        }
        _decodeString(oldCode);
      } else {
        _decodeString(code);
      }

      int requiredSize = _destBytePos + _stackLen;
      if (requiredSize > _destBuf.length) {
        if (!_expandDestBuf(requiredSize - _destBuf.length)) {
          return false;
        }
      }

      for (int i = 0; i < _stackLen; i++) {
        _destBuf[_destBytePos + i] = _decodeStack[_stackLen - i - 1];
      }
      _destBytePos += _stackLen;
      lastChar = _decodeStack[_stackLen - 1];
      
      if (oldCode >= 258 && oldCode - 258 >= _currentCode) {
        break;
      }

      _addCode(oldCode, lastChar);
      oldCode = code;
    }

    return _destBytePos != 0;
  }

  Uint8List takeDestBuf() {
    return _destBuf.sublist(0, _destBytePos);
  }

  int getSrcSize() {
    return (_srcBitPos + 7) ~/ 8;
  }
}
