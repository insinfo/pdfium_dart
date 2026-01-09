import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FormFieldType', () {
    test('all types are defined', () {
      expect(FormFieldType.values.length, 8);
      expect(FormFieldType.unknown, isNotNull);
      expect(FormFieldType.pushButton, isNotNull);
      expect(FormFieldType.checkBox, isNotNull);
      expect(FormFieldType.radioButton, isNotNull);
      expect(FormFieldType.comboBox, isNotNull);
      expect(FormFieldType.listBox, isNotNull);
      expect(FormFieldType.textField, isNotNull);
      expect(FormFieldType.signature, isNotNull);
    });
  });
  
  group('FormFieldFlags', () {
    test('common flags are correct', () {
      expect(FormFieldFlags.readOnly, 1);
      expect(FormFieldFlags.required, 2);
      expect(FormFieldFlags.noExport, 4);
    });
    
    test('button flags are correct', () {
      expect(FormFieldFlags.buttonPushButton, 1 << 16);
      expect(FormFieldFlags.buttonRadio, 1 << 15);
    });
    
    test('text flags are correct', () {
      expect(FormFieldFlags.textMultiline, 1 << 12);
      expect(FormFieldFlags.textPassword, 1 << 13);
      expect(FormFieldFlags.textComb, 1 << 24);
    });
    
    test('choice flags are correct', () {
      expect(FormFieldFlags.choiceCombo, 1 << 17);
      expect(FormFieldFlags.choiceEdit, 1 << 18);
      expect(FormFieldFlags.choiceMultiSelect, 1 << 21);
    });
    
    test('hasFlag works correctly', () {
      const flags = FormFieldFlags.readOnly | FormFieldFlags.required;
      
      expect(FormFieldFlags.hasFlag(flags, FormFieldFlags.readOnly), true);
      expect(FormFieldFlags.hasFlag(flags, FormFieldFlags.required), true);
      expect(FormFieldFlags.hasFlag(flags, FormFieldFlags.noExport), false);
    });
  });
  
  group('PdfFormControl', () {
    test('creates from dictionary', () {
      final dict = PdfDictionary();
      dict.set('Rect', PdfArray.fromNumbers([0, 0, 100, 20]));
      dict.set('AS', PdfName('Yes'));
      
      final control = PdfFormControl(dict);
      
      expect(control.rect.width, 100);
      expect(control.rect.height, 20);
      expect(control.appearanceState, 'Yes');
      expect(control.isChecked, true);
    });
    
    test('isChecked returns false for Off', () {
      final dict = PdfDictionary();
      dict.set('AS', PdfName('Off'));
      
      final control = PdfFormControl(dict);
      
      expect(control.isChecked, false);
    });
    
    test('reads MK dictionary properties', () {
      final mk = PdfDictionary();
      mk.set('BG', PdfArray.fromNumbers([1, 1, 1])); // white background
      mk.set('BC', PdfArray.fromNumbers([0, 0, 0])); // black border
      mk.set('CA', PdfString('Submit'));
      mk.set('R', PdfNumber(90));
      
      final dict = PdfDictionary();
      dict.set('MK', mk);
      
      final control = PdfFormControl(dict);
      
      expect(control.backgroundColor, [1, 1, 1]);
      expect(control.borderColor, [0, 0, 0]);
      expect(control.normalCaption, 'Submit');
      expect(control.rotation, 90);
    });
  });
  
  group('PdfFormField', () {
    test('determines text field type', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Tx'));
      
      final field = PdfFormField(dict);
      
      expect(field.type, FormFieldType.textField);
    });
    
    test('determines checkbox type', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Btn'));
      dict.set('Ff', PdfNumber(0)); // No push button or radio flags
      
      final field = PdfFormField(dict);
      
      expect(field.type, FormFieldType.checkBox);
    });
    
    test('determines radio button type', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Btn'));
      dict.set('Ff', PdfNumber(FormFieldFlags.buttonRadio));
      
      final field = PdfFormField(dict);
      
      expect(field.type, FormFieldType.radioButton);
    });
    
    test('determines push button type', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Btn'));
      dict.set('Ff', PdfNumber(FormFieldFlags.buttonPushButton));
      
      final field = PdfFormField(dict);
      
      expect(field.type, FormFieldType.pushButton);
    });
    
    test('determines combo box type', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Ch'));
      dict.set('Ff', PdfNumber(FormFieldFlags.choiceCombo));
      
      final field = PdfFormField(dict);
      
      expect(field.type, FormFieldType.comboBox);
    });
    
    test('determines list box type', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Ch'));
      dict.set('Ff', PdfNumber(0)); // No combo flag
      
      final field = PdfFormField(dict);
      
      expect(field.type, FormFieldType.listBox);
    });
    
    test('determines signature type', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Sig'));
      
      final field = PdfFormField(dict);
      
      expect(field.type, FormFieldType.signature);
    });
    
    test('reads partial name', () {
      final dict = PdfDictionary();
      dict.set('T', PdfString('firstName'));
      
      final field = PdfFormField(dict);
      
      expect(field.partialName, 'firstName');
      expect(field.fullName, 'firstName');
    });
    
    test('flag properties work', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Tx'));
      dict.set('Ff', PdfNumber(
        FormFieldFlags.readOnly | FormFieldFlags.required
      ));
      
      final field = PdfFormField(dict);
      
      expect(field.isReadOnly, true);
      expect(field.isRequired, true);
      expect(field.isNoExport, false);
    });
    
    test('reads text value', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Tx'));
      dict.set('V', PdfString('Hello World'));
      
      final field = PdfFormField(dict);
      
      expect(field.value, 'Hello World');
      expect(field.textValue, 'Hello World');
    });
    
    test('reads choice options', () {
      final opt = PdfArray();
      opt.add(PdfString('Option 1'));
      opt.add(PdfString('Option 2'));
      opt.add(PdfString('Option 3'));
      
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Ch'));
      dict.set('Ff', PdfNumber(FormFieldFlags.choiceCombo));
      dict.set('Opt', opt);
      
      final field = PdfFormField(dict);
      
      expect(field.options.length, 3);
      expect(field.options[0].displayValue, 'Option 1');
      expect(field.options[1].displayValue, 'Option 2');
    });
    
    test('reads choice options with export values', () {
      final opt1 = PdfArray();
      opt1.add(PdfString('US'));
      opt1.add(PdfString('United States'));
      
      final opt2 = PdfArray();
      opt2.add(PdfString('CA'));
      opt2.add(PdfString('Canada'));
      
      final opt = PdfArray();
      opt.add(opt1);
      opt.add(opt2);
      
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Ch'));
      dict.set('Opt', opt);
      
      final field = PdfFormField(dict);
      
      expect(field.options.length, 2);
      expect(field.options[0].exportValue, 'US');
      expect(field.options[0].displayValue, 'United States');
      expect(field.options[1].exportValue, 'CA');
      expect(field.options[1].displayValue, 'Canada');
    });
    
    test('reads max length', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Tx'));
      dict.set('MaxLen', PdfNumber(100));
      
      final field = PdfFormField(dict);
      
      expect(field.maxLength, 100);
    });
    
    test('text field properties work', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Tx'));
      dict.set('Ff', PdfNumber(
        FormFieldFlags.textMultiline | FormFieldFlags.textPassword
      ));
      
      final field = PdfFormField(dict);
      
      expect(field.isMultiline, true);
      expect(field.isPassword, true);
      expect(field.isComb, false);
    });
    
    test('text alignment works', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Tx'));
      dict.set('Q', PdfNumber(1)); // Center
      
      final field = PdfFormField(dict);
      
      expect(field.textAlignment, FormTextAlignment.center);
    });
  });
  
  group('ChoiceOption', () {
    test('creates with values', () {
      const option = ChoiceOption(
        exportValue: 'val1',
        displayValue: 'Value 1',
      );
      
      expect(option.exportValue, 'val1');
      expect(option.displayValue, 'Value 1');
      expect(option.toString(), 'Value 1');
    });
  });
  
  group('PdfInteractiveForm', () {
    test('creates from dictionary', () {
      final fieldsArray = PdfArray();
      
      final textField = PdfDictionary();
      textField.set('FT', PdfName('Tx'));
      textField.set('T', PdfString('name'));
      fieldsArray.add(textField);
      
      final checkBox = PdfDictionary();
      checkBox.set('FT', PdfName('Btn'));
      checkBox.set('T', PdfString('agree'));
      fieldsArray.add(checkBox);
      
      final formDict = PdfDictionary();
      formDict.set('Fields', fieldsArray);
      
      final form = PdfInteractiveForm(formDict);
      
      expect(form.fieldCount, 2);
      expect(form.isNotEmpty, true);
      expect(form.textFields.length, 1);
      expect(form.checkBoxes.length, 1);
    });
    
    test('gets field by name', () {
      final textField = PdfDictionary();
      textField.set('FT', PdfName('Tx'));
      textField.set('T', PdfString('email'));
      
      final fieldsArray = PdfArray();
      fieldsArray.add(textField);
      
      final formDict = PdfDictionary();
      formDict.set('Fields', fieldsArray);
      
      final form = PdfInteractiveForm(formDict);
      
      expect(form.getFieldByName('email'), isNotNull);
      expect(form.getFieldByName('unknown'), isNull);
    });
    
    test('reads default appearance', () {
      final formDict = PdfDictionary();
      formDict.set('DA', PdfString('/Helv 12 Tf 0 g'));
      formDict.set('Fields', PdfArray());
      
      final form = PdfInteractiveForm(formDict);
      
      expect(form.defaultAppearance, '/Helv 12 Tf 0 g');
    });
    
    test('reads default quadding', () {
      final formDict = PdfDictionary();
      formDict.set('Q', PdfNumber(2)); // Right
      formDict.set('Fields', PdfArray());
      
      final form = PdfInteractiveForm(formDict);
      
      expect(form.defaultQuadding, FormTextAlignment.right);
    });
    
    test('handles empty form', () {
      final formDict = PdfDictionary();
      
      final form = PdfInteractiveForm(formDict);
      
      expect(form.isEmpty, true);
      expect(form.fieldCount, 0);
    });
    
    test('handles signature flags', () {
      final formDict = PdfDictionary();
      formDict.set('SigFlags', PdfNumber(3));
      formDict.set('Fields', PdfArray());
      
      final form = PdfInteractiveForm(formDict);
      
      expect(form.signaturesExist, true);
      expect(form.appendOnly, true);
    });
  });
  
  group('extractFormData', () {
    test('extracts field values', () {
      final field1 = PdfDictionary();
      field1.set('FT', PdfName('Tx'));
      field1.set('T', PdfString('name'));
      field1.set('V', PdfString('John Doe'));
      
      final field2 = PdfDictionary();
      field2.set('FT', PdfName('Tx'));
      field2.set('T', PdfString('email'));
      field2.set('V', PdfString('john@example.com'));
      
      final fieldsArray = PdfArray();
      fieldsArray.add(field1);
      fieldsArray.add(field2);
      
      final formDict = PdfDictionary();
      formDict.set('Fields', fieldsArray);
      
      final form = PdfInteractiveForm(formDict);
      final data = extractFormData(form);
      
      expect(data['name'], 'John Doe');
      expect(data['email'], 'john@example.com');
    });
  });
  
  group('Field extensions', () {
    test('ButtonFieldExtension isChecked', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Btn'));
      dict.set('V', PdfName('Yes'));
      
      final field = PdfFormField(dict);
      
      expect(field.isChecked, true);
    });
    
    test('ButtonFieldExtension isChecked off', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Btn'));
      dict.set('V', PdfName('Off'));
      
      final field = PdfFormField(dict);
      
      expect(field.isChecked, false);
    });
    
    test('ChoiceFieldExtension selectedValues', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Ch'));
      dict.set('V', PdfString('Selected Option'));
      
      final field = PdfFormField(dict);
      
      expect(field.selectedValues, ['Selected Option']);
    });
    
    test('TextFieldExtension textValue', () {
      final dict = PdfDictionary();
      dict.set('FT', PdfName('Tx'));
      dict.set('V', PdfString('Hello'));
      
      final field = PdfFormField(dict);
      
      expect(field.textValue, 'Hello');
    });
  });
}
