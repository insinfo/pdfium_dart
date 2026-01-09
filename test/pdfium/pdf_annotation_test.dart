import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:test/test.dart';

void main() {
  group('AnnotationSubtype', () {
    test('subtypeFromString converts correctly', () {
      expect(
        PdfAnnotation.subtypeFromString('Text'),
        AnnotationSubtype.text,
      );
      expect(
        PdfAnnotation.subtypeFromString('Link'),
        AnnotationSubtype.link,
      );
      expect(
        PdfAnnotation.subtypeFromString('Highlight'),
        AnnotationSubtype.highlight,
      );
      expect(
        PdfAnnotation.subtypeFromString('Unknown'),
        AnnotationSubtype.unknown,
      );
    });
    
    test('subtypeToString converts correctly', () {
      expect(
        PdfAnnotation.subtypeToString(AnnotationSubtype.text),
        'Text',
      );
      expect(
        PdfAnnotation.subtypeToString(AnnotationSubtype.link),
        'Link',
      );
      expect(
        PdfAnnotation.subtypeToString(AnnotationSubtype.highlight),
        'Highlight',
      );
    });
    
    test('case insensitive parsing', () {
      expect(
        PdfAnnotation.subtypeFromString('text'),
        AnnotationSubtype.text,
      );
      expect(
        PdfAnnotation.subtypeFromString('TEXT'),
        AnnotationSubtype.text,
      );
      expect(
        PdfAnnotation.subtypeFromString('FreeText'),
        AnnotationSubtype.freeText,
      );
    });
  });
  
  group('AnnotationFlags', () {
    test('flag values are correct', () {
      expect(AnnotationFlags.invisible, 1);
      expect(AnnotationFlags.hidden, 2);
      expect(AnnotationFlags.print, 4);
      expect(AnnotationFlags.noZoom, 8);
      expect(AnnotationFlags.noRotate, 16);
      expect(AnnotationFlags.noView, 32);
      expect(AnnotationFlags.readOnly, 64);
      expect(AnnotationFlags.locked, 128);
    });
    
    test('hasFlag works correctly', () {
      const flags = AnnotationFlags.print | AnnotationFlags.locked;
      
      expect(AnnotationFlags.hasFlag(flags, AnnotationFlags.print), true);
      expect(AnnotationFlags.hasFlag(flags, AnnotationFlags.locked), true);
      expect(AnnotationFlags.hasFlag(flags, AnnotationFlags.hidden), false);
      expect(AnnotationFlags.hasFlag(flags, AnnotationFlags.readOnly), false);
    });
  });
  
  group('PdfAnnotation', () {
    test('creates from dictionary', () {
      final dict = PdfDictionary();
      dict.set('Subtype', PdfName('Text'));
      dict.set('Rect', PdfArray.fromNumbers([0, 0, 100, 50]));
      dict.set('Contents', PdfString('Test note'));
      
      final annotation = PdfAnnotation(dict);
      
      expect(annotation.subtype, AnnotationSubtype.text);
      expect(annotation.rect, isNotNull);
      expect(annotation.rect.left, 0);
      expect(annotation.rect.right, 100);
      expect(annotation.contents, 'Test note');
    });
    
    test('default values for missing properties', () {
      final dict = PdfDictionary();
      final annotation = PdfAnnotation(dict);
      
      expect(annotation.subtype, AnnotationSubtype.unknown);
      expect(annotation.flags, 0);
      expect(annotation.isHidden, false);
      expect(annotation.isPrintable, false);
      expect(annotation.contents, isNull);
      expect(annotation.name, isNull);
    });
    
    test('flag properties work', () {
      final dict = PdfDictionary();
      dict.set('F', PdfNumber(AnnotationFlags.print | AnnotationFlags.hidden));
      
      final annotation = PdfAnnotation(dict);
      
      expect(annotation.isHidden, true);
      expect(annotation.isPrintable, true);
      expect(annotation.isReadOnly, false);
      expect(annotation.isLocked, false);
    });
    
    test('isTextMarkup identifies markup annotations', () {
      final highlightDict = PdfDictionary();
      highlightDict.set('Subtype', PdfName('Highlight'));
      
      final underlineDict = PdfDictionary();
      underlineDict.set('Subtype', PdfName('Underline'));
      
      final linkDict = PdfDictionary();
      linkDict.set('Subtype', PdfName('Link'));
      
      expect(PdfAnnotation(highlightDict).isTextMarkup, true);
      expect(PdfAnnotation(underlineDict).isTextMarkup, true);
      expect(PdfAnnotation(linkDict).isTextMarkup, false);
    });
    
    test('border properties work', () {
      final dict = PdfDictionary();
      dict.set('Border', PdfArray.fromNumbers([0, 0, 2]));
      
      final annotation = PdfAnnotation(dict);
      
      expect(annotation.borderWidth, 2);
      expect(annotation.border, [0, 0, 2]);
    });
    
    test('color property works', () {
      final dict = PdfDictionary();
      dict.set('C', PdfArray.fromNumbers([1, 0, 0])); // Red
      
      final annotation = PdfAnnotation(dict);
      
      expect(annotation.color, [1, 0, 0]);
    });
  });
  
  group('PdfLinkAnnotation', () {
    test('creates with URI action', () {
      final actionDict = PdfDictionary();
      actionDict.set('S', PdfName('URI'));
      actionDict.set('URI', PdfString('https://example.com'));
      
      final dict = PdfDictionary();
      dict.set('Subtype', PdfName('Link'));
      dict.set('A', actionDict);
      dict.set('Rect', PdfArray.fromNumbers([0, 0, 100, 20]));
      
      final link = PdfLinkAnnotation(dict);
      
      expect(link.uri, 'https://example.com');
      expect(link.action?.type, ActionType.uri);
    });
    
    test('highlight mode defaults to I', () {
      final dict = PdfDictionary();
      final link = PdfLinkAnnotation(dict);
      
      expect(link.highlightMode, 'I');
    });
  });
  
  group('PdfTextAnnotation', () {
    test('parses icon name', () {
      final dict = PdfDictionary();
      dict.set('Subtype', PdfName('Text'));
      dict.set('Name', PdfName('Comment'));
      
      final annotation = PdfTextAnnotation(dict);
      
      expect(annotation.iconName, 'Comment');
    });
    
    test('default icon is Note', () {
      final dict = PdfDictionary();
      final annotation = PdfTextAnnotation(dict);
      
      expect(annotation.iconName, 'Note');
    });
  });
  
  group('PdfFreeTextAnnotation', () {
    test('parses quadding', () {
      final dict = PdfDictionary();
      dict.set('Q', PdfNumber(1)); // Center
      
      final annotation = PdfFreeTextAnnotation(dict);
      
      expect(annotation.quadding, 1);
    });
    
    test('default quadding is 0 (left)', () {
      final dict = PdfDictionary();
      final annotation = PdfFreeTextAnnotation(dict);
      
      expect(annotation.quadding, 0);
    });
  });
  
  group('PdfLineAnnotation', () {
    test('parses line coordinates', () {
      final dict = PdfDictionary();
      dict.set('L', PdfArray.fromNumbers([10, 20, 100, 200]));
      
      final annotation = PdfLineAnnotation(dict);
      
      expect(annotation.lineCoordinates, [10, 20, 100, 200]);
      expect(annotation.startPoint?.x, 10);
      expect(annotation.startPoint?.y, 20);
      expect(annotation.endPoint?.x, 100);
      expect(annotation.endPoint?.y, 200);
    });
  });
  
  group('PdfStampAnnotation', () {
    test('parses stamp name', () {
      final dict = PdfDictionary();
      dict.set('Name', PdfName('Approved'));
      
      final annotation = PdfStampAnnotation(dict);
      
      expect(annotation.stampName, 'Approved');
    });
    
    test('default stamp is Draft', () {
      final dict = PdfDictionary();
      final annotation = PdfStampAnnotation(dict);
      
      expect(annotation.stampName, 'Draft');
    });
  });
  
  group('PdfAction', () {
    test('parses GoTo action', () {
      final dict = PdfDictionary();
      dict.set('S', PdfName('GoTo'));
      dict.set('D', PdfArray()..add(PdfNumber(0))..add(PdfName('Fit')));
      
      final action = PdfAction(dict);
      
      expect(action.type, ActionType.goTo);
      expect(action.destination?.fitType, 'Fit');
    });
    
    test('parses URI action', () {
      final dict = PdfDictionary();
      dict.set('S', PdfName('URI'));
      dict.set('URI', PdfString('https://dart.dev'));
      
      final action = PdfAction(dict);
      
      expect(action.type, ActionType.uri);
      expect(action.uri, 'https://dart.dev');
    });
    
    test('parses Named action', () {
      final dict = PdfDictionary();
      dict.set('S', PdfName('Named'));
      dict.set('N', PdfName('NextPage'));
      
      final action = PdfAction(dict);
      
      expect(action.type, ActionType.named);
      expect(action.namedAction, 'NextPage');
    });
    
    test('parses JavaScript action', () {
      final dict = PdfDictionary();
      dict.set('S', PdfName('JavaScript'));
      dict.set('JS', PdfString('alert("Hello");'));
      
      final action = PdfAction(dict);
      
      expect(action.type, ActionType.javaScript);
      expect(action.javaScript, 'alert("Hello");');
    });
    
    test('parses sub-actions', () {
      final subAction = PdfDictionary();
      subAction.set('S', PdfName('URI'));
      subAction.set('URI', PdfString('https://example.com'));
      
      final dict = PdfDictionary();
      dict.set('S', PdfName('Named'));
      dict.set('N', PdfName('NextPage'));
      dict.set('Next', subAction);
      
      final action = PdfAction(dict);
      
      expect(action.subActions.length, 1);
      expect(action.subActions[0].type, ActionType.uri);
    });
  });
  
  group('PdfDestination', () {
    test('parses array destination', () {
      final arr = PdfArray();
      arr.add(PdfNumber(5)); // page index
      arr.add(PdfName('FitH'));
      arr.add(PdfNumber(100)); // top parameter
      
      final dest = PdfDestination.fromObject(arr, null);
      
      expect(dest?.pageIndex, 5);
      expect(dest?.fitType, 'FitH');
      expect(dest?.parameters, [100]);
    });
    
    test('parses named destination', () {
      final dest = PdfDestination.fromObject(PdfName('Chapter1'), null);
      
      expect(dest?.pageName, 'Chapter1');
      expect(dest?.fitType, 'Named');
    });
  });
  
  group('PdfAnnotationList', () {
    test('creates empty list', () {
      final pageDict = PdfDictionary();
      final list = PdfAnnotationList.fromPage(pageDict);
      
      expect(list.isEmpty, true);
      expect(list.length, 0);
    });
    
    test('loads annotations from page', () {
      final annot1 = PdfDictionary();
      annot1.set('Subtype', PdfName('Text'));
      annot1.set('Rect', PdfArray.fromNumbers([0, 0, 20, 20]));
      
      final annot2 = PdfDictionary();
      annot2.set('Subtype', PdfName('Link'));
      annot2.set('Rect', PdfArray.fromNumbers([30, 30, 100, 50]));
      
      final annots = PdfArray();
      annots.add(annot1);
      annots.add(annot2);
      
      final pageDict = PdfDictionary();
      pageDict.set('Annots', annots);
      
      final list = PdfAnnotationList.fromPage(pageDict);
      
      expect(list.length, 2);
      expect(list[0], isA<PdfTextAnnotation>());
      expect(list[1], isA<PdfLinkAnnotation>());
    });
    
    test('getBySubtype filters correctly', () {
      final textAnnot = PdfDictionary();
      textAnnot.set('Subtype', PdfName('Text'));
      
      final linkAnnot = PdfDictionary();
      linkAnnot.set('Subtype', PdfName('Link'));
      
      final anotherTextAnnot = PdfDictionary();
      anotherTextAnnot.set('Subtype', PdfName('Text'));
      
      final annots = PdfArray();
      annots.add(textAnnot);
      annots.add(linkAnnot);
      annots.add(anotherTextAnnot);
      
      final pageDict = PdfDictionary();
      pageDict.set('Annots', annots);
      
      final list = PdfAnnotationList.fromPage(pageDict);
      
      expect(list.getBySubtype(AnnotationSubtype.text).length, 2);
      expect(list.getBySubtype(AnnotationSubtype.link).length, 1);
    });
    
    test('links getter returns link annotations', () {
      final linkAnnot = PdfDictionary();
      linkAnnot.set('Subtype', PdfName('Link'));
      
      final textAnnot = PdfDictionary();
      textAnnot.set('Subtype', PdfName('Text'));
      
      final annots = PdfArray();
      annots.add(linkAnnot);
      annots.add(textAnnot);
      
      final pageDict = PdfDictionary();
      pageDict.set('Annots', annots);
      
      final list = PdfAnnotationList.fromPage(pageDict);
      
      expect(list.links.length, 1);
      expect(list.links[0], isA<PdfLinkAnnotation>());
    });
    
    test('findAtPoint returns annotation', () {
      final annot = PdfDictionary();
      annot.set('Subtype', PdfName('Text'));
      annot.set('Rect', PdfArray.fromNumbers([10, 10, 50, 50]));
      
      final annots = PdfArray();
      annots.add(annot);
      
      final pageDict = PdfDictionary();
      pageDict.set('Annots', annots);
      
      final list = PdfAnnotationList.fromPage(pageDict);
      
      expect(list.findAtPoint(25, 25), isNotNull);
      expect(list.findAtPoint(0, 0), isNull);
      expect(list.findAtPoint(100, 100), isNull);
    });
    
    test('visible filters hidden annotations', () {
      final visibleAnnot = PdfDictionary();
      visibleAnnot.set('Subtype', PdfName('Text'));
      visibleAnnot.set('F', PdfNumber(0));
      
      final hiddenAnnot = PdfDictionary();
      hiddenAnnot.set('Subtype', PdfName('Text'));
      hiddenAnnot.set('F', PdfNumber(AnnotationFlags.hidden));
      
      final annots = PdfArray();
      annots.add(visibleAnnot);
      annots.add(hiddenAnnot);
      
      final pageDict = PdfDictionary();
      pageDict.set('Annots', annots);
      
      final list = PdfAnnotationList.fromPage(pageDict);
      
      expect(list.length, 2);
      expect(list.visible.length, 1);
    });
    
    test('printable filters by print flag', () {
      final printableAnnot = PdfDictionary();
      printableAnnot.set('Subtype', PdfName('Text'));
      printableAnnot.set('F', PdfNumber(AnnotationFlags.print));
      
      final nonPrintableAnnot = PdfDictionary();
      nonPrintableAnnot.set('Subtype', PdfName('Text'));
      nonPrintableAnnot.set('F', PdfNumber(0));
      
      final annots = PdfArray();
      annots.add(printableAnnot);
      annots.add(nonPrintableAnnot);
      
      final pageDict = PdfDictionary();
      pageDict.set('Annots', annots);
      
      final list = PdfAnnotationList.fromPage(pageDict);
      
      expect(list.printable.length, 1);
    });
  });
}
