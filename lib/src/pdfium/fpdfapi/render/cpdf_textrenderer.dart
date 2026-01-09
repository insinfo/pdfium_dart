import '../../fxge/cfx_renderdevice.dart';
import '../../fxcrt/fx_coordinates.dart';
import '../page/pdf_page_object.dart';

class CPDF_TextRenderer {
  static void renderText(CFX_RenderDevice device, PdfTextObject textObj, FxMatrix deviceMatrix) {
    final font = textObj.font;
    if (font == null) return;
    
    final text = textObj.text;
    final charPositions = textObj.charPositions;
    final fontSize = textObj.fontSize;
    final textMatrix = textObj.matrix;
    
    // Matrix for glyph shape scaling (ignoring translation)
    final scaleMatrix = FxMatrix(fontSize, 0, 0, fontSize, 0, 0);
    // Note: concat() order is (this * other). We want Scale * TextMatrix * DeviceMatrix.
    final shapeMatrix = scaleMatrix.concat(textMatrix).concat(deviceMatrix);
    
    final fillColor = textObj.fillColor;
    
    for (int i = 0; i < text.length; i++) {
        if (i >= charPositions.length) break;
        
        final charCode = text.codeUnitAt(i);
        final origin = charPositions[i];
        
        // Transform origin to device space
        final devPoint = deviceMatrix.transformPoint(origin); // origin is in Page Space (post-CTM)
        
        // Construct final matrix for this glyph
        final glyphMatrix = FxMatrix(
            shapeMatrix.a, shapeMatrix.b,
            shapeMatrix.c, shapeMatrix.d,
            devPoint.x, devPoint.y
        );
        
        device.drawChar(
             font,
             charCode,
             glyphMatrix,
             fillColor
        );
    }
  }
}
