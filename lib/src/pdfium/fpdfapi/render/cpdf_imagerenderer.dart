import '../../fxge/cfx_renderdevice.dart';
import '../../fxcrt/fx_coordinates.dart';
import '../page/pdf_page_object.dart';

class CPDF_ImageRenderer {
  static void renderImage(CFX_RenderDevice device, PdfImageObject imageObj, FxMatrix deviceMatrix) {
      // Calculate total transformation: Image Space (0..1) -> User Space -> Device Space
      final matrix = imageObj.matrix.concat(deviceMatrix);
      
      // Calculate transformed quad
      final p1 = matrix.transformPoint(const FxPoint(0,0));
      final p2 = matrix.transformPoint(const FxPoint(1,0));
      final p3 = matrix.transformPoint(const FxPoint(1,1));
      final p4 = matrix.transformPoint(const FxPoint(0,1));
      
      // Compute bounding box of transformed quad (Device Space)
      double minX = p1.x, maxX = p1.x;
      double minY = p1.y, maxY = p1.y;
      
      for (final p in [p2, p3, p4]) {
          if (p.x < minX) minX = p.x;
          if (p.x > maxX) maxX = p.x;
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
      }
      
      // Draw placeholder gray box
      // TODO: Decode image stream and draw actual bitmap
      device.fillRect(FxRect(minX, minY, maxX, maxY), 0xFFCCCCCC);
  }
}
