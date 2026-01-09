import 'dart:math';
import 'dart:typed_data';

enum PredictorType { none, flate, png }

PredictorType getPredictor(int predictor) {
  if (predictor >= 10) return PredictorType.png;
  if (predictor == 2) return PredictorType.flate;
  return PredictorType.none;
}

int calculatePitch8(int bpc, int components, int width) {
  int totalBits = bpc * components * width;
  return (totalBits + 7) ~/ 8;
}

int pathPredictor(int a, int b, int c) {
  int p = a + b - c;
  int pa = (p - a).abs();
  int pb = (p - b).abs();
  int pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

void pngPredictLine(
    Uint8List destSpan,
    Uint8List srcSpan,
    Uint8List? lastSpan, // Can be null for first line
    int rowSize,
    int bytesPerPixel) {
  
  if (srcSpan.isEmpty) return;
  
  int tag = srcSpan[0];
  // srcSpan includes tag at [0], so data starts at [1]
  // destSpan is just data
  
  // remainingSrcSpan is srcSpan[1:] in C++
  if (srcSpan.length < 1 + rowSize) {
    // Should handle error or partial
  }
  
  switch (tag) {
    case 0: // None
      // Just copy
      for (int i = 0; i < rowSize; i++) {
        destSpan[i] = srcSpan[i + 1];
      }
      break;
    case 1: // Sub
      for (int i = 0; i < rowSize; i++) {
        int left = (i >= bytesPerPixel) ? destSpan[i - bytesPerPixel] : 0;
        destSpan[i] = (srcSpan[i + 1] + left) & 0xFF;
      }
      break;
    case 2: // Up
      for (int i = 0; i < rowSize; i++) {
        int up = (lastSpan != null) ? lastSpan[i] : 0;
        destSpan[i] = (srcSpan[i + 1] + up) & 0xFF;
      }
      break;
    case 3: // Average
      for (int i = 0; i < rowSize; i++) {
        int left = (i >= bytesPerPixel) ? destSpan[i - bytesPerPixel] : 0;
        int up = (lastSpan != null) ? lastSpan[i] : 0;
        destSpan[i] = (srcSpan[i + 1] + ((left + up) >> 1)) & 0xFF;
      }
      break;
    case 4: // Paeth
      for (int i = 0; i < rowSize; i++) {
        int left = (i >= bytesPerPixel) ? destSpan[i - bytesPerPixel] : 0;
        int up = (lastSpan != null) ? lastSpan[i] : 0;
        int upperLeft = (lastSpan != null && i >= bytesPerPixel)
            ? lastSpan[i - bytesPerPixel]
            : 0;
        destSpan[i] = (srcSpan[i + 1] + pathPredictor(left, up, upperLeft)) & 0xFF;
      }
      break;
    default:
      // Treat as None
       for (int i = 0; i < rowSize; i++) {
        destSpan[i] = srcSpan[i + 1];
      }
      break;
  }
}

void tiffPredictLine(Uint8List destSpan, int bitsPerComponent, int colors, int columns) {
  if (bitsPerComponent == 1) {
    int rowBits = min(bitsPerComponent * colors * columns, destSpan.length * 8);
    int indexPre = 0;
    int colPre = 0;
    
    // C++ logic seems to do:
    // for (int i = 1; i < row_bits; i++) ...
    for (int i = 1; i < rowBits; i++) {
      int col = i % 8;
      int index = i ~/ 8;
      
      int val = (destSpan[index] >> (7 - col)) & 1;
      int prevVal = (destSpan[indexPre] >> (7 - colPre)) & 1;
      
      if ((val ^ prevVal) != 0) {
        destSpan[index] |= (1 << (7 - col));
      } else {
        destSpan[index] &= ~(1 << (7 - col));
      }
      indexPre = index;
      colPre = col;
    }
    return;
  }
  
  int bytesPerPixel = (bitsPerComponent * colors) ~/ 8;
  if (bitsPerComponent == 16) {
     for (int i = bytesPerPixel; i + 1 < destSpan.length; i += 2) {
      int pixel = (destSpan[i - bytesPerPixel] << 8) | destSpan[i - bytesPerPixel + 1];
      int current = (destSpan[i] << 8) | destSpan[i + 1];
      pixel += current;
      destSpan[i] = pixel >> 8;
      destSpan[i + 1] = pixel & 0xFF;
    }
  } else {
    for (int i = bytesPerPixel; i < destSpan.length; i++) {
      destSpan[i] = (destSpan[i] + destSpan[i - bytesPerPixel]) & 0xFF;
    }
  }
}

// Full buffer predictors
Uint8List? pngPredictor(int colors, int bitsPerComponent, int columns, Uint8List srcSpan) {
  final int rowSize = calculatePitch8(bitsPerComponent, colors, columns);
  if (rowSize == 0) return null;
  
  final int srcRowSize = rowSize + 1; // +1 for tag
  if (srcRowSize == 0) return null;
  
  final int rowCount = (srcSpan.length + rowSize) ~/ srcRowSize;
  if (rowCount == 0) return null;
  
  // Calculate dest size.
  // Last row might be partial handling in C++?
  // "if (last_row_size) dest_size -= src_row_size - last_row_size"
  // But wait, "src_span.size() % src_row_size"
  // Is it possible to have partial pixels?
  // Let's assume full rows for now or handle simple case.
  
  int destSize = rowCount * rowSize;
  int lastRowExtra = srcSpan.length % srcRowSize;
  if (lastRowExtra != 0) {
      // Logic from C++:
      // const uint32_t last_row_size = src_span.size() % src_row_size;
      // size_t dest_size = Fx2DSizeOrDie(row_size, row_count);
      // if (last_row_size) {
      //   dest_size -= src_row_size - last_row_size; 
      // }
      // This logic actually reduces dest_size if the last row is shorter than expected?
      // Wait, if last_row_size != 0, it means the last source row is incomplete or shorter.
      // But src_row_size includes the tag.
      // If we have less than full row, we copy fewer bytes.
  }
  
  final Uint8List destBuf = Uint8List(destSize); 
  
  int srcOffset = 0;
  int destOffset = 0;
  
  Uint8List? prevDestSpan;
  final int bytesPerPixel = (colors * bitsPerComponent + 7) ~/ 8;
  
  for (int row = 0; row < rowCount; row++) {
    // remainingSrcSpan
    int remainingSrcLen = srcSpan.length - srcOffset;
    if (remainingSrcLen <= 0) break;
    
    // rowSize is dest bytes per row
    int currentDestRowSize = rowSize;
    if (destOffset + currentDestRowSize > destBuf.length) {
       currentDestRowSize = destBuf.length - destOffset;
    }

    // src bytes needed for this row = 1 tag + currentDestRowSize
    // But we are limited by srcSpan
    
    // In C++ it calls PNG_PredictLine with subspan.
    // remaining_row_size = min(row_size, remaining_src_span.size() - 1);
    int remainingRowSize = min(rowSize, remainingSrcLen - 1);
    
    // make slices
    var currentSrc = srcSpan.sublist(srcOffset, srcOffset + remainingRowSize + 1);
    var currentDest = destBuf.sublist(destOffset, destOffset + remainingRowSize); // Actually view would be better but sublist is safer for write locally if not view
    // But we need to write to destBuf.
    // Use views for direct write?
    // Uint8List.view expects ByteBuffer.
    var currentDestView = Uint8List.view(destBuf.buffer, destBuf.offsetInBytes + destOffset, remainingRowSize);
    
    pngPredictLine(currentDestView, currentSrc, prevDestSpan, remainingRowSize, bytesPerPixel);
    
    prevDestSpan = currentDestView;
    srcOffset += remainingRowSize + 1;
    destOffset += remainingRowSize;
  }
  
  return destBuf;
}

bool tiffPredictor(int colors, int bitsPerComponent, int columns, Uint8List dataSpan) {
  final int rowSize = calculatePitch8(bitsPerComponent, colors, columns);
  if (rowSize == 0) return false;
  
  int offset = 0;
  while (offset < dataSpan.length) {
    int len = min(rowSize, dataSpan.length - offset);
    var rowSpan = Uint8List.view(dataSpan.buffer, dataSpan.offsetInBytes + offset, len);
    tiffPredictLine(rowSpan, bitsPerComponent, colors, columns);
    offset += len;
  }
  return true;
}
