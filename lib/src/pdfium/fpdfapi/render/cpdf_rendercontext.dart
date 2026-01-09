import '../../fxcrt/fx_coordinates.dart';
import '../../fxge/cfx_renderdevice.dart';
import '../page/pdf_page_object.dart';
import '../parser/pdf_document.dart';
import '../parser/pdf_dictionary.dart';
import 'cpdf_renderoptions.dart';

class RenderLayer {
  final List<PdfPageObject> objects;
  final FxMatrix matrix;
  RenderLayer(this.objects, this.matrix);
}

class CPDF_RenderContext {
  final PdfDocument document;
  final PdfDictionary? pageResources;
  
  final List<RenderLayer> _layers = [];
  
  CPDF_RenderContext(this.document, this.pageResources);

  void appendLayer(List<PdfPageObject> objects, FxMatrix matrix) {
    _layers.add(RenderLayer(objects, matrix));
  }
  
  void render(CFX_RenderDevice device, [RenderOptions? options]) { 
     // TODO: Implement CPDF_RenderStatus and delegate rendering
     // For each layer, for each object -> RenderStatus.RenderObject
  }
}
