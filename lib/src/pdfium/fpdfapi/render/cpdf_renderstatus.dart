import '../../fxge/cfx_renderdevice.dart';
import '../../fxcrt/fx_coordinates.dart';
import '../page/pdf_page_object.dart';
import 'cpdf_rendercontext.dart';
import 'cpdf_renderoptions.dart';
import 'cpdf_textrenderer.dart';
import 'cpdf_imagerenderer.dart';

class CPDF_RenderStatus {
  final CPDF_RenderContext context;
  final CFX_RenderDevice device;
  final RenderOptions options;
  
  CPDF_RenderStatus({
    required this.context,
    required this.device,
    required this.options,
  });

  void renderObjectList(List<PdfPageObject> objects, FxMatrix matrix) {
    for (final obj in objects) {
      _renderSingleObject(obj, matrix);
    }
  }

  void _renderSingleObject(PdfPageObject obj, FxMatrix matrix) {
    // TODO: Handle ClipPath and Extended Graphics State here
    
    // Matrix transformation logic (Object to Device)
    final deviceMatrix = obj.matrix.concat(matrix);
    
    if (obj is PdfPathObject) {
       _renderPathObject(obj, deviceMatrix);
    } else if (obj is PdfTextObject) {
       // TextRenderer expects the Page-to-Device matrix (context matrix)
       // because it combines it with obj.matrix internally.
       _renderTextObject(obj, matrix);
    } else if (obj is PdfImageObject) {
       // ImageRenderer expects Context Matrix too
       _renderImageObject(obj, matrix);
    } else if (obj is PdfFormObject) {
       _renderFormObject(obj, deviceMatrix);
    }
  }
  
  void _renderPathObject(PdfPathObject obj, FxMatrix deviceMatrix) {
      // Stub
      // device.drawPath(obj.path, ...);
  }
  
  void _renderTextObject(PdfTextObject obj, FxMatrix deviceMatrix) {
      CPDF_TextRenderer.renderText(device, obj, deviceMatrix);
  }
  
  void _renderImageObject(PdfImageObject obj, FxMatrix deviceMatrix) {
      CPDF_ImageRenderer.renderImage(device, obj, deviceMatrix);
  }
  
  void _renderFormObject(PdfFormObject obj, FxMatrix deviceMatrix) {
     // Form object has a list of objects.
     // Recursively render
     renderObjectList(obj.objects, deviceMatrix);
  }
}
