// PDF Interactive Forms (AcroForms) Module
// Port from PDFium's core/fpdfdoc/cpdf_formfield.cpp and cpdf_interactiveform.cpp

import '../fpdfapi/parser/pdf_dictionary.dart';
import '../fpdfapi/parser/pdf_array.dart';
import '../fpdfapi/parser/pdf_name.dart';
import '../fpdfapi/parser/pdf_string.dart';
import '../fpdfapi/parser/pdf_number.dart';
import '../fpdfapi/parser/pdf_document.dart';
import '../fxcrt/fx_coordinates.dart';

/// Form field types as defined in PDF spec
enum FormFieldType {
  unknown,
  pushButton,
  checkBox,
  radioButton,
  comboBox,
  listBox,
  textField,
  signature,
}

/// Field flags common to all field types (PDF 1.7 spec, table 8.70)
class FormFieldFlags {
  static const int readOnly = 1 << 0;
  static const int required = 1 << 1;
  static const int noExport = 1 << 2;
  
  // Button field flags (PDF 1.7 spec, table 8.75)
  static const int buttonNoToggleToOff = 1 << 14;
  static const int buttonRadio = 1 << 15;
  static const int buttonPushButton = 1 << 16;
  static const int buttonRadiosInUnison = 1 << 25;
  
  // Text field flags (PDF 1.7 spec, table 8.77)
  static const int textMultiline = 1 << 12;
  static const int textPassword = 1 << 13;
  static const int textFileSelect = 1 << 20;
  static const int textDoNotSpellCheck = 1 << 22;
  static const int textDoNotScroll = 1 << 23;
  static const int textComb = 1 << 24;
  static const int textRichText = 1 << 25;
  
  // Choice field flags (PDF 1.7 spec, table 8.79)
  static const int choiceCombo = 1 << 17;
  static const int choiceEdit = 1 << 18;
  static const int choiceSort = 1 << 19;
  static const int choiceMultiSelect = 1 << 21;
  static const int choiceDoNotSpellCheck = 1 << 22;
  static const int choiceCommitOnSelChange = 1 << 26;
  
  static bool hasFlag(int flags, int flag) => (flags & flag) != 0;
}

/// Text alignment for form fields
enum FormTextAlignment {
  left,
  center,
  right,
}

/// Form field control appearance state
enum AppearanceState {
  normal,
  on,
  off,
}

/// Base class for form field controls
class PdfFormControl {
  final PdfDictionary dict;
  final PdfFormField? field;
  
  PdfFormControl(this.dict, [this.field]);
  
  /// Get the appearance state
  String? get appearanceState {
    final as_ = dict.get('AS');
    if (as_ is PdfName) {
      return as_.name;
    }
    return null;
  }
  
  /// Get the rectangle
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
  
  /// Get background color
  List<double>? get backgroundColor {
    final mk = dict.get('MK');
    if (mk is PdfDictionary) {
      final bg = mk.get('BG');
      if (bg is PdfArray) {
        return List.generate(bg.length, (i) => bg.getNumberAt(i));
      }
    }
    return null;
  }
  
  /// Get border color
  List<double>? get borderColor {
    final mk = dict.get('MK');
    if (mk is PdfDictionary) {
      final bc = mk.get('BC');
      if (bc is PdfArray) {
        return List.generate(bc.length, (i) => bc.getNumberAt(i));
      }
    }
    return null;
  }
  
  /// Get the normal caption
  String? get normalCaption {
    final mk = dict.get('MK');
    if (mk is PdfDictionary) {
      final ca = mk.get('CA');
      if (ca is PdfString) {
        return ca.text;
      }
    }
    return null;
  }
  
  /// Get the rollover caption
  String? get rolloverCaption {
    final mk = dict.get('MK');
    if (mk is PdfDictionary) {
      final rc = mk.get('RC');
      if (rc is PdfString) {
        return rc.text;
      }
    }
    return null;
  }
  
  /// Get the down caption (when pressed)
  String? get downCaption {
    final mk = dict.get('MK');
    if (mk is PdfDictionary) {
      final ac = mk.get('AC');
      if (ac is PdfString) {
        return ac.text;
      }
    }
    return null;
  }
  
  /// Get rotation
  int get rotation {
    final mk = dict.get('MK');
    if (mk is PdfDictionary) {
      final r = mk.get('R');
      if (r is PdfNumber) {
        return r.intValue;
      }
    }
    return 0;
  }
  
  /// Check if checked (for checkboxes/radio buttons)
  bool get isChecked {
    final state = appearanceState;
    return state != null && state != 'Off';
  }
  
  /// Get export value for checkbox/radio button
  String get exportValue {
    final ap = dict.get('AP');
    if (ap is PdfDictionary) {
      final n = ap.get('N');
      if (n is PdfDictionary) {
        // Find non-Off key
        for (final key in n.keys) {
          if (key != 'Off') {
            return key;
          }
        }
      }
    }
    return 'Yes';
  }
}

/// Form Field - represents a field in an interactive form
class PdfFormField {
  final PdfDictionary dict;
  final PdfInteractiveForm? form;
  final List<PdfFormControl> _controls = [];
  PdfFormField? _parent;
  final List<PdfFormField> _children = [];
  
  PdfFormField(this.dict, [this.form]);
  
  /// Get field type from FT entry
  FormFieldType get type {
    final ft = _getInherited('FT');
    if (ft is! PdfName) return FormFieldType.unknown;
    
    final flags = this.flags;
    
    switch (ft.name) {
      case 'Btn':
        if (FormFieldFlags.hasFlag(flags, FormFieldFlags.buttonPushButton)) {
          return FormFieldType.pushButton;
        }
        if (FormFieldFlags.hasFlag(flags, FormFieldFlags.buttonRadio)) {
          return FormFieldType.radioButton;
        }
        return FormFieldType.checkBox;
        
      case 'Tx':
        return FormFieldType.textField;
        
      case 'Ch':
        if (FormFieldFlags.hasFlag(flags, FormFieldFlags.choiceCombo)) {
          return FormFieldType.comboBox;
        }
        return FormFieldType.listBox;
        
      case 'Sig':
        return FormFieldType.signature;
        
      default:
        return FormFieldType.unknown;
    }
  }
  
  /// Get field flags (Ff)
  int get flags {
    final ff = _getInherited('Ff');
    if (ff is PdfNumber) {
      return ff.intValue;
    }
    return 0;
  }
  
  /// Check if field is read only
  bool get isReadOnly => FormFieldFlags.hasFlag(flags, FormFieldFlags.readOnly);
  
  /// Check if field is required
  bool get isRequired => FormFieldFlags.hasFlag(flags, FormFieldFlags.required);
  
  /// Check if field should not be exported
  bool get isNoExport => FormFieldFlags.hasFlag(flags, FormFieldFlags.noExport);
  
  /// Get the partial field name (T entry)
  String? get partialName {
    final t = dict.get('T');
    if (t is PdfString) {
      return t.text;
    }
    return null;
  }
  
  /// Get the full field name (hierarchical)
  String get fullName {
    final parts = <String>[];
    var current = this;
    
    while (true) {
      final name = current.partialName;
      if (name != null) {
        parts.insert(0, name);
      }
      
      if (current._parent == null) break;
      current = current._parent!;
    }
    
    return parts.join('.');
  }
  
  /// Get alternate name (TU - user-friendly name)
  String? get alternateName {
    final tu = _getInherited('TU');
    if (tu is PdfString) {
      return tu.text;
    }
    return null;
  }
  
  /// Get mapping name (TM - for export)
  String? get mappingName {
    final tm = _getInherited('TM');
    if (tm is PdfString) {
      return tm.text;
    }
    return null;
  }
  
  /// Get field value
  dynamic get value {
    final v = _getInherited('V');
    if (v is PdfString) {
      return v.text;
    }
    if (v is PdfName) {
      return v.name;
    }
    if (v is PdfNumber) {
      return v.numberValue;
    }
    if (v is PdfArray) {
      // Multiple selections
      return List.generate(v.length, (i) {
        final item = v.getAt(i);
        if (item is PdfString) return item.text;
        if (item is PdfName) return item.name;
        return item.toString();
      });
    }
    return null;
  }
  
  /// Get default value
  dynamic get defaultValue {
    final dv = _getInherited('DV');
    if (dv is PdfString) {
      return dv.text;
    }
    if (dv is PdfName) {
      return dv.name;
    }
    return null;
  }
  
  /// Get default appearance string
  String? get defaultAppearance {
    final da = _getInherited('DA');
    if (da is PdfString) {
      return da.text;
    }
    return null;
  }
  
  /// Get text alignment
  FormTextAlignment get textAlignment {
    final q = _getInherited('Q');
    if (q is PdfNumber) {
      switch (q.intValue) {
        case 0: return FormTextAlignment.left;
        case 1: return FormTextAlignment.center;
        case 2: return FormTextAlignment.right;
      }
    }
    return FormTextAlignment.left;
  }
  
  /// Get maximum length (for text fields)
  int? get maxLength {
    final maxLen = dict.get('MaxLen');
    if (maxLen is PdfNumber) {
      return maxLen.intValue;
    }
    return null;
  }
  
  /// Get options for choice fields (combo/list box)
  List<ChoiceOption> get options {
    final opt = dict.get('Opt');
    if (opt is! PdfArray) return [];
    
    final result = <ChoiceOption>[];
    for (var i = 0; i < opt.length; i++) {
      final item = opt.getAt(i);
      
      if (item is PdfArray && item.length >= 2) {
        // [export value, display value]
        final export = item.getAt(0);
        final display = item.getAt(1);
        result.add(ChoiceOption(
          exportValue: export is PdfString ? export.text : export.toString(),
          displayValue: display is PdfString ? display.text : display.toString(),
        ));
      } else if (item is PdfString) {
        result.add(ChoiceOption(
          exportValue: item.text,
          displayValue: item.text,
        ));
      }
    }
    return result;
  }
  
  /// Get selected indices for choice fields
  List<int> get selectedIndices {
    final i = dict.get('I');
    if (i is! PdfArray) return [];
    
    return List.generate(i.length, (idx) => i.getIntAt(idx));
  }
  
  /// Get top index for scrollable list box
  int get topIndex {
    final ti = dict.get('TI');
    if (ti is PdfNumber) {
      return ti.intValue;
    }
    return 0;
  }
  
  // Text field specific
  
  /// Check if multiline text field
  bool get isMultiline => 
      type == FormFieldType.textField && 
      FormFieldFlags.hasFlag(flags, FormFieldFlags.textMultiline);
  
  /// Check if password text field
  bool get isPassword =>
      type == FormFieldType.textField &&
      FormFieldFlags.hasFlag(flags, FormFieldFlags.textPassword);
  
  /// Check if file select text field
  bool get isFileSelect =>
      type == FormFieldType.textField &&
      FormFieldFlags.hasFlag(flags, FormFieldFlags.textFileSelect);
  
  /// Check if comb text field
  bool get isComb =>
      type == FormFieldType.textField &&
      FormFieldFlags.hasFlag(flags, FormFieldFlags.textComb);
  
  /// Check if rich text field
  bool get isRichText =>
      type == FormFieldType.textField &&
      FormFieldFlags.hasFlag(flags, FormFieldFlags.textRichText);
  
  // Choice field specific
  
  /// Check if editable combo box
  bool get isEditableCombo =>
      type == FormFieldType.comboBox &&
      FormFieldFlags.hasFlag(flags, FormFieldFlags.choiceEdit);
  
  /// Check if multi-select list box
  bool get isMultiSelect =>
      type == FormFieldType.listBox &&
      FormFieldFlags.hasFlag(flags, FormFieldFlags.choiceMultiSelect);
  
  /// Check if choice options are sorted
  bool get isSorted =>
      (type == FormFieldType.comboBox || type == FormFieldType.listBox) &&
      FormFieldFlags.hasFlag(flags, FormFieldFlags.choiceSort);
  
  /// Get controls for this field
  List<PdfFormControl> get controls => List.unmodifiable(_controls);
  
  /// Get child fields
  List<PdfFormField> get children => List.unmodifiable(_children);
  
  /// Get parent field
  PdfFormField? get parent => _parent;
  
  /// Get inherited attribute
  dynamic _getInherited(String key) {
    // Check this field first
    final value = dict.get(key);
    if (value != null) return value;
    
    // Walk up parent chain
    var current = _parent;
    while (current != null) {
      final parentValue = current.dict.get(key);
      if (parentValue != null) return parentValue;
      current = current._parent;
    }
    
    return null;
  }
  
  @override
  String toString() => 'PdfFormField($fullName, type: $type)';
}

/// Option for choice fields
class ChoiceOption {
  final String exportValue;
  final String displayValue;
  
  const ChoiceOption({
    required this.exportValue,
    required this.displayValue,
  });
  
  @override
  String toString() => displayValue;
}

/// Interactive Form (AcroForm)
/// 
/// Manages all form fields in a PDF document
class PdfInteractiveForm {
  final PdfDictionary dict;
  final PdfDocument? document;
  final List<PdfFormField> _fields = [];
  final Map<String, PdfFormField> _fieldsByName = {};
  
  PdfInteractiveForm(this.dict, [this.document]) {
    _loadFields();
  }
  
  /// Create from document's AcroForm dictionary
  static PdfInteractiveForm? fromDocument(PdfDocument doc) {
    final root = doc.root;
    if (root == null) return null;
    
    final acroForm = root.get('AcroForm');
    if (acroForm is! PdfDictionary) return null;
    
    return PdfInteractiveForm(acroForm, doc);
  }
  
  /// Check if form needs appearances generated
  bool get needsAppearances {
    final na = dict.get('NeedAppearances');
    if (na is PdfName) {
      return na.name.toLowerCase() == 'true';
    }
    return false;
  }
  
  /// Get signature flags
  int get signatureFlags {
    final sigFlags = dict.get('SigFlags');
    if (sigFlags is PdfNumber) {
      return sigFlags.intValue;
    }
    return 0;
  }
  
  /// Check if form has signatures that exist
  bool get signaturesExist => (signatureFlags & 1) != 0;
  
  /// Check if form requires signatures to append only
  bool get appendOnly => (signatureFlags & 2) != 0;
  
  /// Get calculation order (fields with Calculate action)
  List<PdfFormField> get calculationOrder {
    final co = dict.get('CO');
    if (co is! PdfArray) return [];
    
    // For now, return empty - would need reference resolution
    // ignore: unused_local_variable
    for (var i = 0; i < co.length; i++) {
      // Would need to resolve reference to field
    }
    return [];
  }
  
  /// Get default resources dictionary
  PdfDictionary? get defaultResources {
    final dr = dict.get('DR');
    if (dr is PdfDictionary) {
      return dr;
    }
    return null;
  }
  
  /// Get default appearance string
  String? get defaultAppearance {
    final da = dict.get('DA');
    if (da is PdfString) {
      return da.text;
    }
    return null;
  }
  
  /// Get default quadding (text alignment)
  FormTextAlignment get defaultQuadding {
    final q = dict.get('Q');
    if (q is PdfNumber) {
      switch (q.intValue) {
        case 0: return FormTextAlignment.left;
        case 1: return FormTextAlignment.center;
        case 2: return FormTextAlignment.right;
      }
    }
    return FormTextAlignment.left;
  }
  
  /// Get all fields
  List<PdfFormField> get fields => List.unmodifiable(_fields);
  
  /// Get field count
  int get fieldCount => _fields.length;
  
  /// Get field by index
  PdfFormField operator [](int index) => _fields[index];
  
  /// Get field by full name
  PdfFormField? getFieldByName(String name) => _fieldsByName[name];
  
  /// Get fields by type
  List<PdfFormField> getFieldsByType(FormFieldType type) {
    return _fields.where((f) => f.type == type).toList();
  }
  
  /// Get all text fields
  List<PdfFormField> get textFields => getFieldsByType(FormFieldType.textField);
  
  /// Get all checkboxes
  List<PdfFormField> get checkBoxes => getFieldsByType(FormFieldType.checkBox);
  
  /// Get all radio buttons
  List<PdfFormField> get radioButtons => getFieldsByType(FormFieldType.radioButton);
  
  /// Get all combo boxes
  List<PdfFormField> get comboBoxes => getFieldsByType(FormFieldType.comboBox);
  
  /// Get all list boxes
  List<PdfFormField> get listBoxes => getFieldsByType(FormFieldType.listBox);
  
  /// Get all push buttons
  List<PdfFormField> get pushButtons => getFieldsByType(FormFieldType.pushButton);
  
  /// Get all signature fields
  List<PdfFormField> get signatureFields => getFieldsByType(FormFieldType.signature);
  
  /// Load fields from the Fields array
  void _loadFields() {
    final fieldsArray = dict.get('Fields');
    if (fieldsArray is! PdfArray) return;
    
    for (var i = 0; i < fieldsArray.length; i++) {
      final fieldObj = fieldsArray.getAt(i);
      if (fieldObj is PdfDictionary) {
        _loadFieldTree(fieldObj, null);
      }
    }
  }
  
  /// Recursively load field tree
  void _loadFieldTree(PdfDictionary fieldDict, PdfFormField? parent) {
    final field = PdfFormField(fieldDict, this);
    field._parent = parent;
    
    if (parent != null) {
      parent._children.add(field);
    }
    
    // Check for Kids (child fields or controls)
    final kids = fieldDict.get('Kids');
    if (kids is PdfArray) {
      for (var i = 0; i < kids.length; i++) {
        final kid = kids.getAt(i);
        if (kid is PdfDictionary) {
          // Check if it's a field or a widget annotation
          final ft = kid.get('FT');
          final subtype = kid.get('Subtype');
          
          if (ft != null || (subtype == null && kid.get('T') != null)) {
            // It's a field
            _loadFieldTree(kid, field);
          } else {
            // It's a widget annotation (control)
            final control = PdfFormControl(kid, field);
            field._controls.add(control);
          }
        }
      }
    } else {
      // Field is also its own widget
      final control = PdfFormControl(fieldDict, field);
      field._controls.add(control);
    }
    
    // Only add root-level and leaf fields
    if (field._children.isEmpty || parent == null) {
      _fields.add(field);
      _fieldsByName[field.fullName] = field;
    }
  }
  
  /// Check if form is empty
  bool get isEmpty => _fields.isEmpty;
  
  /// Check if form has any fields
  bool get isNotEmpty => _fields.isNotEmpty;
  
  @override
  String toString() => 'PdfInteractiveForm(${_fields.length} fields)';
}

/// Utility to extract all form data as a map
Map<String, dynamic> extractFormData(PdfInteractiveForm form) {
  final data = <String, dynamic>{};
  
  for (final field in form.fields) {
    final value = field.value;
    if (value != null) {
      data[field.fullName] = value;
    }
  }
  
  return data;
}

/// Form field for text input
extension TextFieldExtension on PdfFormField {
  /// Get text value
  String get textValue {
    final v = value;
    return v is String ? v : '';
  }
}

/// Form field for choice (combo/list box)
extension ChoiceFieldExtension on PdfFormField {
  /// Get selected display values
  List<String> get selectedValues {
    final v = value;
    if (v is String) {
      return [v];
    }
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return [];
  }
  
  /// Get selected option by index
  ChoiceOption? getOption(int index) {
    final opts = options;
    if (index >= 0 && index < opts.length) {
      return opts[index];
    }
    return null;
  }
}

/// Form field for checkbox/radio button
extension ButtonFieldExtension on PdfFormField {
  /// Check if checkbox/radio is checked
  bool get isChecked {
    final v = value;
    if (v is String) {
      return v.toLowerCase() != 'off';
    }
    return false;
  }
}
