// PDF Annotation Module
// Port from PDFium's core/fpdfdoc/cpdf_annot.cpp

import '../fpdfapi/parser/pdf_dictionary.dart';
import '../fpdfapi/parser/pdf_array.dart';
import '../fpdfapi/parser/pdf_stream.dart';
import '../fpdfapi/parser/pdf_name.dart';
import '../fpdfapi/parser/pdf_string.dart';
import '../fpdfapi/parser/pdf_number.dart';
import '../fpdfapi/parser/pdf_document.dart';
import '../fxcrt/fx_coordinates.dart';

/// Annotation subtypes as defined in PDF 1.7 spec, Table 8.20
enum AnnotationSubtype {
  unknown,
  text,
  link,
  freeText,
  line,
  square,
  circle,
  polygon,
  polyline,
  highlight,
  underline,
  squiggly,
  strikeOut,
  stamp,
  caret,
  ink,
  popup,
  fileAttachment,
  sound,
  movie,
  widget,
  screen,
  printerMark,
  trapNet,
  watermark,
  threeDimensional,
  richMedia,
  xfaWidget,
  redact,
}

/// Annotation flags as defined in PDF 1.7 spec, Table 8.16
class AnnotationFlags {
  static const int invisible = 1 << 0;
  static const int hidden = 1 << 1;
  static const int print = 1 << 2;
  static const int noZoom = 1 << 3;
  static const int noRotate = 1 << 4;
  static const int noView = 1 << 5;
  static const int readOnly = 1 << 6;
  static const int locked = 1 << 7;
  static const int toggleNoView = 1 << 8;
  static const int lockedContents = 1 << 9;
  
  /// Check if a flag is set
  static bool hasFlag(int flags, int flag) => (flags & flag) != 0;
}

/// Appearance mode for annotation display
enum AppearanceMode {
  normal,
  rollover,
  down,
}

/// Border style for annotations
enum BorderStyle {
  solid,
  dashed,
  beveled,
  inset,
  underline,
}

/// PDF Annotation
/// Represents an annotation in a PDF document
class PdfAnnotation {
  final PdfDictionary dict;
  final PdfDocument? document;
  PdfAnnotation? _popupAnnot;
  bool _openState = false;
  
  PdfAnnotation(this.dict, [this.document]);
  
  /// Get annotation subtype from string
  static AnnotationSubtype subtypeFromString(String subtype) {
    switch (subtype.toLowerCase()) {
      case 'text': return AnnotationSubtype.text;
      case 'link': return AnnotationSubtype.link;
      case 'freetext': return AnnotationSubtype.freeText;
      case 'line': return AnnotationSubtype.line;
      case 'square': return AnnotationSubtype.square;
      case 'circle': return AnnotationSubtype.circle;
      case 'polygon': return AnnotationSubtype.polygon;
      case 'polyline': return AnnotationSubtype.polyline;
      case 'highlight': return AnnotationSubtype.highlight;
      case 'underline': return AnnotationSubtype.underline;
      case 'squiggly': return AnnotationSubtype.squiggly;
      case 'strikeout': return AnnotationSubtype.strikeOut;
      case 'stamp': return AnnotationSubtype.stamp;
      case 'caret': return AnnotationSubtype.caret;
      case 'ink': return AnnotationSubtype.ink;
      case 'popup': return AnnotationSubtype.popup;
      case 'fileattachment': return AnnotationSubtype.fileAttachment;
      case 'sound': return AnnotationSubtype.sound;
      case 'movie': return AnnotationSubtype.movie;
      case 'widget': return AnnotationSubtype.widget;
      case 'screen': return AnnotationSubtype.screen;
      case 'printermark': return AnnotationSubtype.printerMark;
      case 'trapnet': return AnnotationSubtype.trapNet;
      case 'watermark': return AnnotationSubtype.watermark;
      case '3d': return AnnotationSubtype.threeDimensional;
      case 'richmedia': return AnnotationSubtype.richMedia;
      case 'xfawidget': return AnnotationSubtype.xfaWidget;
      case 'redact': return AnnotationSubtype.redact;
      default: return AnnotationSubtype.unknown;
    }
  }
  
  /// Convert subtype to string
  static String subtypeToString(AnnotationSubtype subtype) {
    switch (subtype) {
      case AnnotationSubtype.text: return 'Text';
      case AnnotationSubtype.link: return 'Link';
      case AnnotationSubtype.freeText: return 'FreeText';
      case AnnotationSubtype.line: return 'Line';
      case AnnotationSubtype.square: return 'Square';
      case AnnotationSubtype.circle: return 'Circle';
      case AnnotationSubtype.polygon: return 'Polygon';
      case AnnotationSubtype.polyline: return 'PolyLine';
      case AnnotationSubtype.highlight: return 'Highlight';
      case AnnotationSubtype.underline: return 'Underline';
      case AnnotationSubtype.squiggly: return 'Squiggly';
      case AnnotationSubtype.strikeOut: return 'StrikeOut';
      case AnnotationSubtype.stamp: return 'Stamp';
      case AnnotationSubtype.caret: return 'Caret';
      case AnnotationSubtype.ink: return 'Ink';
      case AnnotationSubtype.popup: return 'Popup';
      case AnnotationSubtype.fileAttachment: return 'FileAttachment';
      case AnnotationSubtype.sound: return 'Sound';
      case AnnotationSubtype.movie: return 'Movie';
      case AnnotationSubtype.widget: return 'Widget';
      case AnnotationSubtype.screen: return 'Screen';
      case AnnotationSubtype.printerMark: return 'PrinterMark';
      case AnnotationSubtype.trapNet: return 'TrapNet';
      case AnnotationSubtype.watermark: return 'Watermark';
      case AnnotationSubtype.threeDimensional: return '3D';
      case AnnotationSubtype.richMedia: return 'RichMedia';
      case AnnotationSubtype.xfaWidget: return 'XFAWidget';
      case AnnotationSubtype.redact: return 'Redact';
      case AnnotationSubtype.unknown: return '';
    }
  }
  
  /// Get the subtype of this annotation
  AnnotationSubtype get subtype {
    final subtypeObj = dict.get('Subtype');
    if (subtypeObj is PdfName) {
      return subtypeFromString(subtypeObj.name);
    }
    return AnnotationSubtype.unknown;
  }
  
  /// Get the annotation flags
  int get flags {
    final f = dict.get('F');
    if (f is PdfNumber) {
      return f.intValue;
    }
    return 0;
  }
  
  /// Check if annotation is hidden
  bool get isHidden => AnnotationFlags.hasFlag(flags, AnnotationFlags.hidden);
  
  /// Check if annotation is printable
  bool get isPrintable => AnnotationFlags.hasFlag(flags, AnnotationFlags.print);
  
  /// Check if annotation is read only
  bool get isReadOnly => AnnotationFlags.hasFlag(flags, AnnotationFlags.readOnly);
  
  /// Check if annotation is locked
  bool get isLocked => AnnotationFlags.hasFlag(flags, AnnotationFlags.locked);
  
  /// Get the annotation rectangle
  FxRect get rect {
    final rectArray = dict.get('Rect');
    if (rectArray is PdfArray && rectArray.length >= 4) {
      return FxRect(
        rectArray.getNumberAt(0),
        rectArray.getNumberAt(1),
        rectArray.getNumberAt(2),
        rectArray.getNumberAt(3),
      );
    }
    return const FxRect.zero();
  }
  
  /// Get the annotation contents (text)
  String? get contents {
    final c = dict.get('Contents');
    if (c is PdfString) {
      return c.text;
    }
    return null;
  }
  
  /// Get the annotation name (unique identifier)
  String? get name {
    final nm = dict.get('NM');
    if (nm is PdfString) {
      return nm.text;
    }
    return null;
  }
  
  /// Get the modification date
  String? get modificationDate {
    final m = dict.get('M');
    if (m is PdfString) {
      return m.text;
    }
    return null;
  }
  
  /// Get border color
  List<double>? get color {
    final c = dict.get('C');
    if (c is PdfArray) {
      return List.generate(c.length, (i) => c.getNumberAt(i));
    }
    return null;
  }
  
  /// Get border array [horizontal corner radius, vertical corner radius, border width]
  List<double>? get border {
    final b = dict.get('Border');
    if (b is PdfArray) {
      return List.generate(b.length, (i) => b.getNumberAt(i));
    }
    return null;
  }
  
  /// Get border width
  double get borderWidth {
    final b = border;
    if (b != null && b.length >= 3) {
      return b[2];
    }
    
    // Check BS dictionary
    final bs = dict.get('BS');
    if (bs is PdfDictionary) {
      final w = bs.get('W');
      if (w is PdfNumber) {
        return w.numberValue;
      }
    }
    
    return 1.0; // Default border width
  }
  
  /// Get border style
  BorderStyle get borderStyle {
    final bs = dict.get('BS');
    if (bs is PdfDictionary) {
      final s = bs.get('S');
      if (s is PdfName) {
        switch (s.name) {
          case 'S': return BorderStyle.solid;
          case 'D': return BorderStyle.dashed;
          case 'B': return BorderStyle.beveled;
          case 'I': return BorderStyle.inset;
          case 'U': return BorderStyle.underline;
        }
      }
    }
    return BorderStyle.solid;
  }
  
  /// Get the appearance dictionary
  PdfDictionary? get appearanceDict {
    final ap = dict.get('AP');
    if (ap is PdfDictionary) {
      return ap;
    }
    return null;
  }
  
  /// Get appearance stream for a mode
  PdfStream? getAppearanceStream(AppearanceMode mode) {
    final ap = appearanceDict;
    if (ap == null) return null;
    
    String key;
    switch (mode) {
      case AppearanceMode.normal: key = 'N';
      case AppearanceMode.rollover: key = 'R';
      case AppearanceMode.down: key = 'D';
    }
    
    var appearance = ap.get(key);
    
    // Fallback to normal appearance
    if (appearance == null && mode != AppearanceMode.normal) {
      appearance = ap.get('N');
    }
    
    if (appearance is PdfStream) {
      return appearance;
    }
    
    // Could be a dictionary of named appearances
    if (appearance is PdfDictionary) {
      final as_ = dict.get('AS');
      if (as_ is PdfName) {
        final named = appearance.get(as_.name);
        if (named is PdfStream) {
          return named;
        }
      }
    }
    
    return null;
  }
  
  /// Get popup annotation (if any)
  PdfAnnotation? get popupAnnotation => _popupAnnot;
  
  /// Set popup annotation
  set popupAnnotation(PdfAnnotation? popup) => _popupAnnot = popup;
  
  /// Get/set open state (for popup annotations)
  bool get isOpen => _openState;
  set isOpen(bool value) => _openState = value;
  
  /// Check if this is a text markup annotation
  bool get isTextMarkup {
    switch (subtype) {
      case AnnotationSubtype.highlight:
      case AnnotationSubtype.underline:
      case AnnotationSubtype.squiggly:
      case AnnotationSubtype.strikeOut:
        return true;
      default:
        return false;
    }
  }
  
  /// Get quad points for text markup annotations
  List<FxRect> get quadPoints {
    final qp = dict.get('QuadPoints');
    if (qp is! PdfArray) return [];
    
    final rects = <FxRect>[];
    // Each quad point has 8 numbers (4 points x 2 coords)
    final numQuads = qp.length ~/ 8;
    
    for (var i = 0; i < numQuads; i++) {
      final baseIndex = i * 8;
      final points = <double>[];
      for (var j = 0; j < 8; j++) {
        points.add(qp.getNumberAt(baseIndex + j));
      }
      
      // Convert quad points to rect (take bounding box)
      final xs = [points[0], points[2], points[4], points[6]];
      final ys = [points[1], points[3], points[5], points[7]];
      
      xs.sort();
      ys.sort();
      
      rects.add(FxRect(xs.first, ys.first, xs.last, ys.last));
    }
    
    return rects;
  }
  
  @override
  String toString() =>
      'PdfAnnotation(${subtypeToString(subtype)}, rect: $rect)';
}

/// Link Annotation
class PdfLinkAnnotation extends PdfAnnotation {
  PdfLinkAnnotation(super.dict, [super.document]);
  
  /// Get the destination
  PdfDestination? get destination {
    final dest = dict.get('Dest');
    if (dest != null) {
      return PdfDestination.fromObject(dest, document);
    }
    
    // Check action for GoTo destination
    final action = this.action;
    if (action != null && action.type == ActionType.goTo) {
      return action.destination;
    }
    
    return null;
  }
  
  /// Get the action (if any)
  PdfAction? get action {
    final a = dict.get('A');
    if (a is PdfDictionary) {
      return PdfAction(a, document);
    }
    return null;
  }
  
  /// Get the URI (if link action is URI)
  String? get uri {
    final action = this.action;
    if (action?.type == ActionType.uri) {
      return action?.uri;
    }
    return null;
  }
  
  /// Highlight mode
  String get highlightMode {
    final h = dict.get('H');
    if (h is PdfName) {
      return h.name;
    }
    return 'I'; // Invert (default)
  }
}

/// Text Annotation (Note)
class PdfTextAnnotation extends PdfAnnotation {
  PdfTextAnnotation(super.dict, [super.document]);
  
  /// Get the icon name
  String get iconName {
    final name = dict.get('Name');
    if (name is PdfName) {
      return name.name;
    }
    return 'Note'; // Default icon
  }
  
  /// Get the state
  String? get state {
    final s = dict.get('State');
    if (s is PdfString) {
      return s.text;
    }
    return null;
  }
  
  /// Get the state model
  String? get stateModel {
    final sm = dict.get('StateModel');
    if (sm is PdfString) {
      return sm.text;
    }
    return null;
  }
}

/// FreeText Annotation
class PdfFreeTextAnnotation extends PdfAnnotation {
  PdfFreeTextAnnotation(super.dict, [super.document]);
  
  /// Get the default appearance string
  String? get defaultAppearance {
    final da = dict.get('DA');
    if (da is PdfString) {
      return da.text;
    }
    return null;
  }
  
  /// Get the text alignment (0=Left, 1=Center, 2=Right)
  int get quadding {
    final q = dict.get('Q');
    if (q is PdfNumber) {
      return q.intValue;
    }
    return 0; // Left aligned
  }
  
  /// Get the default style
  String? get defaultStyle {
    final ds = dict.get('DS');
    if (ds is PdfString) {
      return ds.text;
    }
    return null;
  }
  
  /// Get the callout line points
  List<double>? get calloutLine {
    final cl = dict.get('CL');
    if (cl is PdfArray) {
      return List.generate(cl.length, (i) => cl.getNumberAt(i));
    }
    return null;
  }
  
  /// Get the intent
  String? get intent {
    final it = dict.get('IT');
    if (it is PdfName) {
      return it.name;
    }
    return null;
  }
}

/// Ink Annotation
class PdfInkAnnotation extends PdfAnnotation {
  PdfInkAnnotation(super.dict, [super.document]);
  
  /// Get ink list (array of arrays of coordinates)
  List<List<double>> get inkList {
    final il = dict.get('InkList');
    if (il is! PdfArray) return [];
    
    final result = <List<double>>[];
    for (var i = 0; i < il.length; i++) {
      final stroke = il.getAt(i);
      if (stroke is PdfArray) {
        result.add(List.generate(
          stroke.length,
          (j) => stroke.getNumberAt(j),
        ));
      }
    }
    return result;
  }
}

/// Line Annotation
class PdfLineAnnotation extends PdfAnnotation {
  PdfLineAnnotation(super.dict, [super.document]);
  
  /// Get line coordinates [x1, y1, x2, y2]
  List<double>? get lineCoordinates {
    final l = dict.get('L');
    if (l is PdfArray && l.length >= 4) {
      return List.generate(4, (i) => l.getNumberAt(i));
    }
    return null;
  }
  
  /// Get start point
  FxPoint? get startPoint {
    final coords = lineCoordinates;
    if (coords != null) {
      return FxPoint(coords[0], coords[1]);
    }
    return null;
  }
  
  /// Get end point
  FxPoint? get endPoint {
    final coords = lineCoordinates;
    if (coords != null) {
      return FxPoint(coords[2], coords[3]);
    }
    return null;
  }
  
  /// Get line ending styles
  List<String>? get lineEndings {
    final le = dict.get('LE');
    if (le is PdfArray && le.length >= 2) {
      final result = <String>[];
      for (var i = 0; i < 2; i++) {
        final item = le.getAt(i);
        if (item is PdfName) {
          result.add(item.name);
        }
      }
      return result.length == 2 ? result : null;
    }
    return null;
  }
  
  /// Get interior color
  List<double>? get interiorColor {
    final ic = dict.get('IC');
    if (ic is PdfArray) {
      return List.generate(ic.length, (i) => ic.getNumberAt(i));
    }
    return null;
  }
}

/// Stamp Annotation
class PdfStampAnnotation extends PdfAnnotation {
  PdfStampAnnotation(super.dict, [super.document]);
  
  /// Get the stamp name
  String get stampName {
    final name = dict.get('Name');
    if (name is PdfName) {
      return name.name;
    }
    return 'Draft'; // Default stamp
  }
}

/// PDF Action types
enum ActionType {
  unknown,
  goTo,
  goToR,
  goToE,
  launch,
  thread,
  uri,
  sound,
  movie,
  hide,
  named,
  submitForm,
  resetForm,
  importData,
  javaScript,
  setOCGState,
  rendition,
  trans,
  goTo3DView,
}

/// PDF Action
class PdfAction {
  final PdfDictionary dict;
  final PdfDocument? document;
  
  PdfAction(this.dict, [this.document]);
  
  /// Get action type
  ActionType get type {
    final s = dict.get('S');
    if (s is! PdfName) return ActionType.unknown;
    
    switch (s.name) {
      case 'GoTo': return ActionType.goTo;
      case 'GoToR': return ActionType.goToR;
      case 'GoToE': return ActionType.goToE;
      case 'Launch': return ActionType.launch;
      case 'Thread': return ActionType.thread;
      case 'URI': return ActionType.uri;
      case 'Sound': return ActionType.sound;
      case 'Movie': return ActionType.movie;
      case 'Hide': return ActionType.hide;
      case 'Named': return ActionType.named;
      case 'SubmitForm': return ActionType.submitForm;
      case 'ResetForm': return ActionType.resetForm;
      case 'ImportData': return ActionType.importData;
      case 'JavaScript': return ActionType.javaScript;
      case 'SetOCGState': return ActionType.setOCGState;
      case 'Rendition': return ActionType.rendition;
      case 'Trans': return ActionType.trans;
      case 'GoTo3DView': return ActionType.goTo3DView;
      default: return ActionType.unknown;
    }
  }
  
  /// Get destination for GoTo action
  PdfDestination? get destination {
    final d = dict.get('D');
    if (d != null) {
      return PdfDestination.fromObject(d, document);
    }
    return null;
  }
  
  /// Get URI for URI action
  String? get uri {
    final u = dict.get('URI');
    if (u is PdfString) {
      return u.text;
    }
    return null;
  }
  
  /// Get JavaScript for JavaScript action
  String? get javaScript {
    final js = dict.get('JS');
    if (js is PdfString) {
      return js.text;
    }
    if (js is PdfStream) {
      // JavaScript can be in a stream
      final data = js.decodedData;
      return String.fromCharCodes(data);
    }
    return null;
  }
  
  /// Get named action
  String? get namedAction {
    final n = dict.get('N');
    if (n is PdfName) {
      return n.name;
    }
    return null;
  }
  
  /// Get file path for Launch/GoToR actions
  String? get filePath {
    final f = dict.get('F');
    if (f is PdfString) {
      return f.text;
    }
    if (f is PdfDictionary) {
      // File specification dictionary
      final uf = f.get('UF');
      if (uf is PdfString) return uf.text;
      final f_ = f.get('F');
      if (f_ is PdfString) return f_.text;
    }
    return null;
  }
  
  /// Get sub-actions
  List<PdfAction> get subActions {
    final next = dict.get('Next');
    if (next is PdfDictionary) {
      return [PdfAction(next, document)];
    }
    if (next is PdfArray) {
      return List.generate(next.length, (i) {
        final item = next.getAt(i);
        if (item is PdfDictionary) {
          return PdfAction(item, document);
        }
        return null;
      }).whereType<PdfAction>().toList();
    }
    return [];
  }
}

/// PDF Destination
class PdfDestination {
  final int? pageIndex;
  final String? pageName;
  final String fitType;
  final List<double?> parameters;
  
  PdfDestination({
    this.pageIndex,
    this.pageName,
    required this.fitType,
    required this.parameters,
  });
  
  /// Create destination from PDF object
  static PdfDestination? fromObject(dynamic obj, PdfDocument? doc) {
    if (obj is PdfName) {
      // Named destination - lookup in document
      return PdfDestination(
        pageName: obj.name,
        fitType: 'Named',
        parameters: [],
      );
    }
    
    if (obj is PdfString) {
      return PdfDestination(
        pageName: obj.text,
        fitType: 'Named',
        parameters: [],
      );
    }
    
    if (obj is! PdfArray || obj.isEmpty) return null;
    
    // First element is page reference or index
    int? pageIndex;
    final pageRef = obj.getAt(0);
    if (pageRef is PdfNumber) {
      pageIndex = pageRef.intValue;
    }
    // If it's a reference, would need to resolve to get page index
    
    // Second element is fit type
    String fitType = 'Fit';
    if (obj.length > 1) {
      final ft = obj.getAt(1);
      if (ft is PdfName) {
        fitType = ft.name;
      }
    }
    
    // Remaining elements are parameters
    final params = <double?>[];
    for (var i = 2; i < obj.length; i++) {
      final p = obj.getAt(i);
      if (p is PdfNumber) {
        params.add(p.numberValue);
      } else {
        params.add(null);
      }
    }
    
    return PdfDestination(
      pageIndex: pageIndex,
      fitType: fitType,
      parameters: params,
    );
  }
  
  @override
  String toString() =>
      'PdfDestination(page: ${pageIndex ?? pageName}, fit: $fitType)';
}

/// Annotation List for a page
class PdfAnnotationList {
  final List<PdfAnnotation> _annotations = [];
  
  /// Get all annotations
  List<PdfAnnotation> get annotations => List.unmodifiable(_annotations);
  
  /// Get annotation count
  int get length => _annotations.length;
  
  /// Get annotation at index
  PdfAnnotation operator [](int index) => _annotations[index];
  
  /// Check if empty
  bool get isEmpty => _annotations.isEmpty;
  
  /// Load annotations from page dictionary
  static PdfAnnotationList fromPage(PdfDictionary pageDict, [PdfDocument? doc]) {
    final list = PdfAnnotationList();
    
    final annots = pageDict.get('Annots');
    if (annots is! PdfArray) return list;
    
    // First pass: create all annotations
    final annotMap = <PdfDictionary, PdfAnnotation>{};
    
    for (var i = 0; i < annots.length; i++) {
      final annotObj = annots.getAt(i);
      if (annotObj is! PdfDictionary) continue;
      
      final annotation = _createAnnotation(annotObj, doc);
      list._annotations.add(annotation);
      annotMap[annotObj] = annotation;
    }
    
    // Second pass: link popup annotations
    for (final annot in list._annotations) {
      final popup = annot.dict.get('Popup');
      if (popup is PdfDictionary) {
        final popupAnnot = annotMap[popup];
        if (popupAnnot != null) {
          annot.popupAnnotation = popupAnnot;
        }
      }
    }
    
    return list;
  }
  
  /// Create appropriate annotation type
  static PdfAnnotation _createAnnotation(PdfDictionary dict, PdfDocument? doc) {
    final subtypeObj = dict.get('Subtype');
    if (subtypeObj is! PdfName) {
      return PdfAnnotation(dict, doc);
    }
    
    final subtype = PdfAnnotation.subtypeFromString(subtypeObj.name);
    
    switch (subtype) {
      case AnnotationSubtype.link:
        return PdfLinkAnnotation(dict, doc);
      case AnnotationSubtype.text:
        return PdfTextAnnotation(dict, doc);
      case AnnotationSubtype.freeText:
        return PdfFreeTextAnnotation(dict, doc);
      case AnnotationSubtype.ink:
        return PdfInkAnnotation(dict, doc);
      case AnnotationSubtype.line:
        return PdfLineAnnotation(dict, doc);
      case AnnotationSubtype.stamp:
        return PdfStampAnnotation(dict, doc);
      default:
        return PdfAnnotation(dict, doc);
    }
  }
  
  /// Get annotations by subtype
  List<PdfAnnotation> getBySubtype(AnnotationSubtype subtype) {
    return _annotations.where((a) => a.subtype == subtype).toList();
  }
  
  /// Get all link annotations
  List<PdfLinkAnnotation> get links =>
      _annotations.whereType<PdfLinkAnnotation>().toList();
  
  /// Get all text annotations
  List<PdfTextAnnotation> get textAnnotations =>
      _annotations.whereType<PdfTextAnnotation>().toList();
  
  /// Find annotation at point
  PdfAnnotation? findAtPoint(double x, double y) {
    final point = FxPoint(x, y);
    for (final annot in _annotations.reversed) {
      if (annot.rect.contains(point)) {
        return annot;
      }
    }
    return null;
  }
  
  /// Get printable annotations
  List<PdfAnnotation> get printable =>
      _annotations.where((a) => a.isPrintable && !a.isHidden).toList();
  
  /// Get visible annotations
  List<PdfAnnotation> get visible =>
      _annotations.where((a) => !a.isHidden).toList();
}
