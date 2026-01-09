import 'dart:typed_data';
import 'dart:io';

import '../scanlinedecoder.dart';
import '../../fxcrt/pause_indicator.dart';
import 'clzw_decoder.dart';
import 'predictors.dart';
import '../data_and_bytes_consumed.dart';

class FlateModule {
  static ScanlineDecoder createDecoder(
    Uint8List srcSpan,
    int width,
    int height,
    int nComps,
    int bpc,
    int predictor,
    int colors,
    int bitsPerComponent,
    int columns,
  ) {
    var type = getPredictor(predictor);
    if (type == PredictorType.none) {
      return FlateScanlineDecoder(srcSpan, width, height, nComps, bpc);
    }
    return FlatePredictorScanlineDecoder(
      srcSpan, width, height, nComps, bpc, type, colors, bitsPerComponent, columns,
    );
  }

  static DataAndBytesConsumed flateOrLZWDecode(
    bool bLZW,
    Uint8List srcSpan,
    bool bEarlyChange,
    int predictor,
    int colors,
    int bitsPerComponent,
    int columns,
    int estimatedSize,
  ) {
    Uint8List destBuf;
    int bytesConsumed = 0;
    var predictorType = getPredictor(predictor);

    if (bLZW) {
      var decoder = CLZWDecoder(srcSpan, bEarlyChange);
      if (!decoder.decode()) {
        return DataAndBytesConsumed(Uint8List(0), 0);
      }
      destBuf = decoder.takeDestBuf();
      bytesConsumed = decoder.getSrcSize();
    } else {
      // Flate decode
      try {
        var decoder = ZLibDecoder();
        destBuf = Uint8List.fromList(decoder.convert(srcSpan));
        bytesConsumed = srcSpan.length; // We assume all consumed unless zlib stops early
      } catch (e) {
        return DataAndBytesConsumed(Uint8List(0), 0);
      }
    }

    if (predictorType == PredictorType.none) {
      return DataAndBytesConsumed(destBuf, bytesConsumed);
    } else if (predictorType == PredictorType.png) {
      var predicted = pngPredictor(colors, bitsPerComponent, columns, destBuf);
      return DataAndBytesConsumed(predicted ?? destBuf, bytesConsumed);
    } else {
      // Flate predictor (TIFF)
      tiffPredictor(colors, bitsPerComponent, columns, destBuf);
      return DataAndBytesConsumed(destBuf, bytesConsumed);
    }
  }

  static Uint8List encode(Uint8List srcSpan) {
    return Uint8List.fromList(ZLibEncoder().convert(srcSpan));
  }
}

class FlateScanlineDecoder extends ScanlineDecoder {
  final Uint8List srcBuf;
  Uint8List? _decodedData;
  int _currentOffset = 0;

  FlateScanlineDecoder(this.srcBuf, int width, int height, int nComps, int bpc)
      : super(
          origWidth: width,
          origHeight: height,
          outputWidth: width,
          outputHeight: height,
          comps: nComps,
          bpc: bpc,
          pitch: calculatePitch8(bpc, nComps, width),
        );

  @override
  int getSrcOffset() {
    // Eager decoding means we consumed all input effectively?
    // Or we should track. For now return length.
    return srcBuf.length;
  }

  @override
  bool rewind() {
    _currentOffset = 0;
    try {
        // Decode all at once for now
        if (_decodedData == null) {
            _decodedData = Uint8List.fromList(ZLibDecoder().convert(srcBuf));
        }
        return true;
    } catch (e) {
        return false;
    }
  }

  @override
  Uint8List? getNextLine() {
    if (_decodedData == null) return null;
    if (_currentOffset + pitch > _decodedData!.length) return null;
    
    var line = Uint8List.view(_decodedData!.buffer, _decodedData!.offsetInBytes + _currentOffset, pitch);
    _currentOffset += pitch;
    return line;
  }
}

class FlatePredictorScanlineDecoder extends FlateScanlineDecoder {
  final PredictorType predictor;
  final int colors;
  final int bitsPerComponent;
  final int columns;
  
  // Buffers for line processing if we were streaming.
  // Since we eager decode, we can run predictor on the whole buffer or line by line.
  // Line by line is better to match ScanlineDecoder interface semantics.
  
  // But wait, PNG predictor depends on previous line.
  // We can just implement getNextLine to process on the fly from the raw decoded data.
  
  int _predictPitch = 0;
  Uint8List? _lastLine;
  
  FlatePredictorScanlineDecoder(
    Uint8List srcSpan,
    int width,
    int height,
    int nComps,
    int bpc,
    this.predictor,
    this.colors,
    this.bitsPerComponent,
    this.columns,
  ) : super(srcSpan, width, height, nComps, bpc) {
      _predictPitch = calculatePitch8(bitsPerComponent, colors, columns);
      _lastLine = Uint8List(_predictPitch);
  }


  @override
  Uint8List? getNextLine() {
    // Super.getNextLine gets raw uncompressed data (which is encoded with predictor)
    // We need to decode the predictor.
    
    // NOTE: The pitch of the FlateScanlineDecoder (superclass) calculates pitch based on bpc/comps/width.
    // Ideally this matches _predictPitch if parameters are consistent.
    // However, PNG predictor adds a tag byte at the beginning of each line.
    // So the raw line length in ZLib stream is _predictPitch + 1 (for PNG) or similar.
    // We need to handle this.
    
    // In C++ constructor:
    // predict_pitch_ = fxge::CalculatePitch8OrDie(bits_per_component_, colors_, columns_);
    
    // If predictor is PNG, the row size in stream is predict_pitch + 1.
    // If predictor is Flate(TIFF), row size is predict_pitch.
    
    // But FlateScanlineDecoder (superclass) uses `pitch` field.
    // We should probably override `pitch` or how `getNextLine` works.
    
    // Easier approach: Just use `_decodedData` from super, and manage offsets manually here.
    // But `_decodedData` is private in super (if I made it private). I made it `_decodedData`.
    // I should make it protected or just have this class handle decoding itself?
    // Or just use super.getNextLine() assuming super's pitch is correct.
    
    // If PNG, super's pitch should be predictPitch + 1.
    // Let's check init:
    // C++: FlateScanlineDecoder init uses calculated pitch.
    // C++ FlatePredictorScanlineDecoder:
    // ScanlineDecoder params: width, height, comps, bpc, pitch.
    // It passes calculated pitch to super.
    
    // In getNextLineWithPredictedPitch (C++):
    // It reads from `flate_` into `predict_raw_` (buffer).
    // Then calls PNG_PredictLine.
    
    // Problem: `super.getNextLine()` advances `_currentOffset` by `super.pitch`.
    // If we use PNG, we need `super.pitch` to include the tag byte?
    // C++ code doesn't change `pitch_` in super, but `FlateScanlineDecoder` doesn't use `pitch_` to drive zlib output directly in the way my "eager" implementation does.
    // My eager implementation assumes `super.pitch` is the stride of the decoded data.
    
    // Implementation Plan:
    // 1. Override `rewind` to eager decode zlib data into a local `_rawDecodedData`.
    // 2. Override `getNextLine` to take from `_rawDecodedData`, apply predictor, and return result.
    // 3. Ignore `super.getNextLine`.
    
    return _getNextLineInternal();
  }
  
  Uint8List? _rawDecodedData;
  int _rawOffset = 0;
  
  @override 
  bool rewind() {
     _rawOffset = 0;
     _lastLine?.fillRange(0, _lastLine!.length, 0);
     try {
       if (_rawDecodedData == null) {
         _rawDecodedData = Uint8List.fromList(ZLibDecoder().convert(srcBuf));
       }
       return true;
     } catch (e) {
       return false;
     }
  }
  
  Uint8List _outputBuffer = Uint8List(0);

  Uint8List? _getNextLineInternal() {
    if (_rawDecodedData == null) return null;
    
    if (predictor == PredictorType.png) {
        // Needed: predictPitch + 1
        int bytesNeeded = _predictPitch + 1;
        if (_rawOffset + bytesNeeded > _rawDecodedData!.length) return null;
        
        var srcLine = Uint8List.view(_rawDecodedData!.buffer, _rawDecodedData!.offsetInBytes + _rawOffset, bytesNeeded);
        _rawOffset += bytesNeeded;
        
        // Output buffer
        if (_outputBuffer.length != _predictPitch) {
            _outputBuffer = Uint8List(_predictPitch);
        }
        
        var destLine = _outputBuffer; // We reuse buffer, so caller must consume immediately. 
        // Or create new one. ScanlineDecoder usually usually returns pointer to internal buffer (last_scanline_).
        // So reusing is fine.
        
        pngPredictLine(destLine, srcLine, _lastLine, _predictPitch, (colors * bitsPerComponent + 7) ~/ 8);
        
        // Copy to lastLine for next iteration
        _lastLine!.setRange(0, _predictPitch, destLine);
        
        return destLine;
    } else {
        // TIFF
        int bytesNeeded = _predictPitch;
        if (_rawOffset + bytesNeeded > _rawDecodedData!.length) return null;
        
        var srcLine = Uint8List.fromList(_rawDecodedData!.sublist(_rawOffset, _rawOffset + bytesNeeded)); // Copy to modify
        _rawOffset += bytesNeeded;
        
        tiffPredictLine(srcLine, bitsPerComponent, colors, columns);
        return srcLine;
    }
  }
}
