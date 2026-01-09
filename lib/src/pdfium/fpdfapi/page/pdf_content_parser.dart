// Copyright 2016 The PDFium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// PDF Content Parser
/// 
/// Parses content stream into PDF page objects.
/// Port of core/fpdfapi/page/cpdf_contentparser.cpp

import 'package:meta/meta.dart';

import '../../fxcrt/fx_coordinates.dart';
import '../../fxcrt/fx_types.dart';
import '../parser/pdf_array.dart';
import '../parser/pdf_dictionary.dart';
import '../parser/pdf_name.dart';
import '../parser/pdf_number.dart';
import '../parser/pdf_string.dart';
import '../parser/pdf_stream.dart';
import '../parser/pdf_object.dart';
import '../font/pdf_font.dart';
import 'pdf_page.dart';
import 'pdf_page_object.dart';
import 'content_stream_parser.dart';
import 'graphics_state.dart';

class PdfContentParser {
  final PdfPage page;
  final GraphicsStateStack _stateStack = GraphicsStateStack();
  final List<PdfPageObject> _objects = [];
  
  // Current text state for building text objects
  PdfTextObject? _currentTextObject;
  TextPosition _textPosition = TextPosition();
  bool _inTextBlock = false;
  
  // Current path state
  final List<PathSegment> _currentPathSegments = [];
  FxPoint _pathStart = const FxPoint(0, 0);
  FxPoint _currentPoint = const FxPoint(0, 0);
  
  final Map<String, PdfFont> _fontCache = {};

  PdfContentParser(this.page);
  
  List<PdfPageObject> parse() {
    _objects.clear();
    _fontCache.clear();
    _stateStack.reset();
    _textPosition = TextPosition();
    _inTextBlock = false;
    _currentPathSegments.clear();
    
    // Get content streams
    final streams = page.getContents();
    if (streams.isEmpty) return [];
    
    // Create parser
    final parser = ContentStreamParser.fromStreams(
      streams,
      page.resources,
    );
    
    // Parse operations
    final operations = parser.parseAll();
    
    for (final op in operations) {
      _executeOperation(op);
    }
    
    return _objects;
  }
  
  GraphicsState get state => _stateStack.current;
  
  void _executeOperation(ContentOperation op) {
    switch (op.operator) {
      // Graphics State
      case ContentOperator.gsave:
        _stateStack.save();
        break;
      case ContentOperator.grestore:
        _stateStack.restore();
        break;
      case ContentOperator.ctm:
        _handleCTM(op);
        break;
      
      // Path Construction
      case ContentOperator.moveTo:
        _handleMoveTo(op);
        break;
      case ContentOperator.lineTo:
        _handleLineTo(op);
        break;
      case ContentOperator.curveTo:
        _handleCurveTo(op);
        break;
      case ContentOperator.rect:
        _handleRect(op);
        break;
      case ContentOperator.closePath:
        _handleClosePath();
        break;
        
      // Path Painting
      case ContentOperator.stroke:
      case ContentOperator.closeStroke:
      case ContentOperator.fill:
      case ContentOperator.fillEvenOdd:
      case ContentOperator.fillStroke:
      case ContentOperator.fillStrokeEvenOdd:
      case ContentOperator.closeFillStroke:
      case ContentOperator.closeFillStrokeEvenOdd:
        _handlePathPaint(op);
        break;
      case ContentOperator.endPath:
        _currentPathSegments.clear();
        break;
        
      // Text Objects
      case ContentOperator.beginText:
        _stateStack.current.text = TextState(); // Reset text state? Check spec. 
        // Spec says BT resets text matrix and line matrix to identity.
        _textPosition = TextPosition(); 
        _inTextBlock = true;
        break;
      case ContentOperator.endText:
        _inTextBlock = false;
        _currentTextObject = null;
        break;
        
      // Text State
      case ContentOperator.charSpace:
        state.text.charSpace = op.getNumber(0);
        break;
      case ContentOperator.wordSpace:
        state.text.wordSpace = op.getNumber(0);
        break;
      case ContentOperator.hScale:
        state.text.horizontalScale = op.getNumber(0);
        break;
      case ContentOperator.textLeading:
        state.text.leading = op.getNumber(0);
        break;
      case ContentOperator.font:
        state.text.fontName = op.getName(0);
        state.text.fontSize = op.getNumber(1);
        break;
      case ContentOperator.textRender:
        state.text.renderMode = op.getInt(0);
        break;
      case ContentOperator.textRise:
        state.text.rise = op.getNumber(0);
        break;
        
      // Text Positioning
      case ContentOperator.textMove:
        _handleTextMove(op);
        break;
      case ContentOperator.textMoveSet:
        _handleTextMoveSet(op);
        break;
      case ContentOperator.textMatrix:
        _handleTextMatrix(op);
        break;
      case ContentOperator.textNewLine:
        _handleTextNewLine();
        break;
        
      // Text Showing
      case ContentOperator.showText:
        _handleShowText(op);
        break;
      case ContentOperator.showTextNewLine:
        _handleTextNewLine();
        _handleShowText(op);
        break;
      case ContentOperator.showTextSpacing:
        state.text.wordSpace = op.getNumber(0);
        state.text.charSpace = op.getNumber(1);
        _handleShowText(op, 2);
        break;
      case ContentOperator.showTextArray:
        _handleShowTextArray(op);
        break;
        
      // Color
      // Simplified: Just store in state.
      // We need to implement proper CS lookup if we want fidelity.
      case ContentOperator.strokeGray:
        state.color.setStrokeGray(op.getNumber(0));
        break;
      case ContentOperator.fillGray:
        state.color.setFillGray(op.getNumber(0));
        break;
      case ContentOperator.strokeRGB:
        state.color.setStrokeRGB(op.getNumber(0), op.getNumber(1), op.getNumber(2));
        break;
      case ContentOperator.fillRGB:
        state.color.setFillRGB(op.getNumber(0), op.getNumber(1), op.getNumber(2));
        break;
      case ContentOperator.strokeCMYK:
        state.color.setStrokeCMYK(op.getNumber(0), op.getNumber(1), op.getNumber(2), op.getNumber(3));
        break;
      case ContentOperator.fillCMYK:
        state.color.setFillCMYK(op.getNumber(0), op.getNumber(1), op.getNumber(2), op.getNumber(3));
        break;
        
      // XObject
      case ContentOperator.xobject:
        _handleXObject(op);
        break;
        
      default:
        break;
    }
  }
  
  void _handleCTM(ContentOperation op) {
    if (op.operands.length < 6) return;
    final a = op.getNumber(0);
    final b = op.getNumber(1);
    final c = op.getNumber(2);
    final d = op.getNumber(3);
    final e = op.getNumber(4);
    final f = op.getNumber(5);
    
    state.ctm = state.ctm.concat(FxMatrix(a, b, c, d, e, f));
  }
  
  // Text Handling logic simplified for structure
  
  void _handleTextMove(ContentOperation op) {
    final tx = op.getNumber(0);
    final ty = op.getNumber(1);
    _textPosition.translate(tx, ty);
  }
  
  void _handleTextMoveSet(ContentOperation op) {
    final tx = op.getNumber(0);
    final ty = op.getNumber(1);
    state.text.leading = -ty;
    _textPosition.translate(tx, ty);
  }
  
  void _handleTextMatrix(ContentOperation op) {
    if (op.operands.length < 6) return;
    _textPosition.matrix = FxMatrix(
      op.getNumber(0), op.getNumber(1),
      op.getNumber(2), op.getNumber(3),
      op.getNumber(4), op.getNumber(5)
    );
    _textPosition.lineMatrix = _textPosition.matrix;
  }
  
  void _handleTextNewLine() {
    _handleTextMoveSet(ContentOperation(ContentOperator.textMoveSet, 
        [PdfNumber(0), PdfNumber(-state.text.leading)]));
  }
  
  void _handleShowText(ContentOperation op, [int startIndex = 0]) {
    final stringObj = op.operands.length > startIndex ? op.operands[startIndex] : null;
    if (stringObj is! PdfString) return;
    
    _addTextObject(stringObj.text, 0.0); // No kerneling adjustment
  }
  
  void _handleShowTextArray(ContentOperation op) {
    // Array contains strings and numbers (shifts)
    final array = op.operands.isNotEmpty ? op.operands[0] : null;
    if (array is! PdfArray) return;
    
    for (int i = 0; i < array.length; i++) {
        final item = array.getAt(i);
        if (item is PdfString) {
            _addTextObject(item.text, 0.0);
        } else if (item is PdfNumber) {
            // Apply numeric offset (kerning)
            _applyTextShift(item.numberValue);
        }
    }
  }
  
  PdfFont? _getFont(String fontName) {
    if (_fontCache.containsKey(fontName)) {
      return _fontCache[fontName];
    }
    
    // Look up in resources
    final fontDict = page.resources?.getDict('Font')?.getDict(fontName);
    
    if (fontDict != null) {
       // Create font
       final font = PdfFont.fromDictionary(fontDict);
       _fontCache[fontName] = font;
       return font;
    }
    return null;
  }

  void _addTextObject(String text, double adjustment) {
      final fontName = state.text.fontName ?? '';
      final font = _getFont(fontName);
      
      final textObj = PdfTextObject();
      textObj.text = text;
      textObj.fontName = fontName;
      textObj.font = font;
      textObj.fontSize = state.text.fontSize;
      textObj.renderMode = TextRenderMode.values[state.text.renderMode % TextRenderMode.values.length];
      textObj.fillColor = state.color.fillFxColor.value;
      textObj.strokeColor = state.color.strokeFxColor.value;
      
      // Calculate matrix
      // Text matrix * CTM
      textObj.matrix = _textPosition.matrix.concat(state.ctm);
      textObj.position = FxPoint(textObj.matrix.e, textObj.matrix.f);
      
      // Calculate char positions and advance
      if (font != null) {
          textObj.charPositions = [];
          
          double fontSize = state.text.fontSize;
          double horizScale = state.text.horizontalScale / 100.0;
          double charSpace = state.text.charSpace;
          double wordSpace = state.text.wordSpace;
          double rise = state.text.rise;
          
          // Apply rise (translate Y)
          FxMatrix textMatrix = _textPosition.matrix;
          if (rise != 0) {
            textMatrix = FxMatrix(1, 0, 0, 1, 0, rise).concat(textMatrix);
          }
          
          for (int i = 0; i < text.length; i++) {
             int charCode = text.codeUnitAt(i);
             
             // Calculate position of THIS char
             final charMatrix = textMatrix.concat(state.ctm);
             textObj.charPositions.add(FxPoint(charMatrix.e, charMatrix.f));

             // Advance
             double charWidth = font.getCharWidth(charCode) / 1000.0;
             
             double advance = (charWidth * fontSize + charSpace) * horizScale;
             
             // Word spacing (usually for space char 32)
             if (charCode == 32 && wordSpace != 0) {
                 advance += wordSpace * horizScale;
             }
             
             // Update text matrix (translate tx)
             textMatrix = FxMatrix(1, 0, 0, 1, advance, 0).concat(textMatrix);
          }
          
          // Update _textPosition with final matrix (minus rise)
          // Actually _textPosition should persist.
          // Before loop, we had _textPosition.
          // After loop, we have advanced _textPosition.
          // But 'rise' is temporary for the text object drawing. 
          // PDF Spec: Rise is applied to text space y coordinate. It does not affect Tm?
          // "Ts: Set text rise... vertical displacement... "
          // Effect: (x, y + rise).
          // Does it persist? "state parameter text rise".
          // Yes.
          
          // So if rise is set in state, it applies to all text.
          // But does it affect the 'advance'?
          // Advance happens along the baseline. Rise shifts the baseline up/down.
          // The Advance moves the cursor (Tx, Ty).
          // If we have rise, the cursor (origin) inside loops is shifted.
          // But the stored _textPosition should be the baseline.
          
          // So I should use `_textPosition.matrix` for advancing.
          // And `textObj` should store coordinates with Rise applied?
          // `textObj.matrix` is usually the matrix forming the text space.
          // If I apply rise to `textObj.matrix`, then the whole object is shifted.
          
          if (rise != 0) {
             textObj.matrix = FxMatrix(1, 0, 0, 1, 0, rise).concat(textObj.matrix);
             textObj.position = FxPoint(textObj.matrix.e, textObj.matrix.f);
             // Re-adjust char positions?
             // Since charPositions were calculated using textMatrix which included rise...
             // Wait, I used a local `textMatrix` in loop.
             // If I initialized `textMatrix` with Rise applied, then `charPositions` include Rise. Correct.
          }
          
          // Finally update the persistent _textPosition
          // We advanced local `textMatrix` which had Rise applied.
          // We need to update `_textPosition.matrix` similarly but WITHOUT accumulating Rise shift?
          // No, Rise is a translation.
          // Advance is a translation.
          // Matrix multiplication is associative.
          // Tm_new = Advance * Tm_old.
          // We used Tm_temp = Rise * Tm_old.
          // Tm_temp_new = Advance * Tm_temp = Advance * Rise * Tm_old.
          // Since Advance (horizontal) and Rise (vertical) commute (Translate(tx,0) * Translate(0,ty) = Translate(tx,ty)),
          // Tm_temp_new = Rise * (Advance * Tm_old).
          // We want to store (Advance * Tm_old) back into _textPosition.
          
          // So simply accumulate advance on _textPosition.
          
           for (int i = 0; i < text.length; i++) {
             int charCode = text.codeUnitAt(i);
             double charWidth = font.getCharWidth(charCode) / 1000.0;
             double advance = (charWidth * fontSize + charSpace) * horizScale;
             if (charCode == 32 && wordSpace != 0) {
                 advance += wordSpace * horizScale;
             }
             _textPosition.matrix = FxMatrix(1, 0, 0, 1, advance, 0).concat(_textPosition.matrix);
           }
          
      }
      
      // Handle adjustment (TJ)
      if (adjustment != 0) {
           _applyTextShift(adjustment);
      }
      
      _objects.add(textObj);
  }

  void _applyTextShift(double shift) {
     double fontSize = state.text.fontSize;
     double horizScale = state.text.horizontalScale / 100.0;
     double tx = (-shift / 1000.0 * fontSize) * horizScale;
     _textPosition.matrix = FxMatrix(1, 0, 0, 1, tx, 0).concat(_textPosition.matrix);
  }
  
  // Path Handling
  
  void _handleMoveTo(ContentOperation op) {
    final x = op.getNumber(0);
    final y = op.getNumber(1);
    _pathStart = FxPoint(x, y);
    _currentPoint = _pathStart;
    _currentPathSegments.add(PathSegment.moveTo(FxPoint(x, y)));
  }
  
  void _handleLineTo(ContentOperation op) {
    final x = op.getNumber(0);
    final y = op.getNumber(1);
    _currentPoint = FxPoint(x, y);
    _currentPathSegments.add(PathSegment.lineTo(FxPoint(x, y)));
  }
  
  void _handleCurveTo(ContentOperation op) {
    final x1 = op.getNumber(0);
    final y1 = op.getNumber(1);
    final x2 = op.getNumber(2);
    final y2 = op.getNumber(3);
    final x3 = op.getNumber(4);
    final y3 = op.getNumber(5);
    _currentPoint = FxPoint(x3, y3);
    _currentPathSegments.add(PathSegment.bezierTo(
        FxPoint(x1, y1), 
        FxPoint(x2, y2), 
        FxPoint(x3, y3)));
  }
  
  void _handleRect(ContentOperation op) {
    final x = op.getNumber(0);
    final y = op.getNumber(1);
    final w = op.getNumber(2);
    final h = op.getNumber(3);
    
    _currentPathSegments.add(PathSegment.moveTo(FxPoint(x, y)));
    _currentPathSegments.add(PathSegment.lineTo(FxPoint(x + w, y)));
    _currentPathSegments.add(PathSegment.lineTo(FxPoint(x + w, y + h)));
    _currentPathSegments.add(PathSegment.lineTo(FxPoint(x, y + h)));
    _currentPathSegments.add(PathSegment.close()); 
  }
  
  void _handleClosePath() {
    _currentPoint = _pathStart;
    _currentPathSegments.add(PathSegment.close());
  }
  
  void _handlePathPaint(ContentOperation op) {
    if (_currentPathSegments.isEmpty) return;
    
    final pathObj = PdfPathObject();
    pathObj.segments = List.from(_currentPathSegments);
    pathObj.matrix = state.ctm; // Path coordinates are usually transformed by CTM at render time
    // But PdfPageObject matrix usually stores CTM.
    
    // Set colors
    // Check op to see if fill/stroke
    bool fill = false;
    bool stroke = false;
    
    switch (op.operator) {
        case ContentOperator.fill:
        case ContentOperator.fillEvenOdd:
        case ContentOperator.fillOld:
           fill = true;
           break;
        case ContentOperator.stroke:
        case ContentOperator.closeStroke:
           stroke = true;
           break;
        case ContentOperator.fillStroke:
        case ContentOperator.fillStrokeEvenOdd:
        case ContentOperator.closeFillStroke:
        case ContentOperator.closeFillStrokeEvenOdd:
           fill = true;
           stroke = true;
           break;
        default: break;
    }
    
    if (fill) pathObj.fillColor = state.color.fillFxColor.value;
    if (stroke) pathObj.strokeColor = state.color.strokeFxColor.value;
    pathObj.strokeWidth = state.line.width;
    
    _objects.add(pathObj);
    _currentPathSegments.clear();
  }
  
  void _handleXObject(ContentOperation op) {
     // Lookup resource
     final name = op.getName(0);
     // Dictionary lookup...
     // Placeholder
  }
}

class TextPosition {
  FxMatrix matrix = const FxMatrix.identity();
  FxMatrix lineMatrix = const FxMatrix.identity();
  
  void translate(double tx, double ty) {
      final move = FxMatrix(1, 0, 0, 1, tx, ty);
      lineMatrix = move.concat(lineMatrix);
      matrix = lineMatrix;
  }
}

