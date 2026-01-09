import '../fxcrt/fx_coordinates.dart';
import 'cpdf_textpage.dart';

class PdfTextPageFind {
  final PdfTextPage textPage;
  String _findWhat = '';
  int _flags = 0;
  int _startIndex = 0;
  List<int> _resStart = [];
  List<int> _resEnd = [];
  int _resIndex = -1;

  PdfTextPageFind(this.textPage);

  bool findFirst(String findWhat, int flags, [int startIndex = 0]) {
    _findWhat = findWhat;
    _flags = flags;
    _startIndex = startIndex;
    _resIndex = -1;
    _resStart.clear();
    _resEnd.clear();

    if (_findWhat.isEmpty) return false;

    // Search logic here...
    // Populate _resStart and _resEnd
    String fullText = textPage.getText(0);
    int found = fullText.indexOf(_findWhat, startIndex);
    if (found != -1) {
        _resStart.add(found);
        _resEnd.add(found + _findWhat.length);
        _resIndex = 0;
        return true;
    }

    return false;
  }

  bool findNext() {
    if (_resIndex + 1 < _resStart.length) {
        _resIndex++;
        return true;
    }
    return false;
  }

  bool findPrev() {
      if (_resIndex > 0) {
          _resIndex--;
          return true;
      }
      return false;
  }

  int getResStart() {
      if (_resIndex >= 0 && _resIndex < _resStart.length) return _resStart[_resIndex];
      return -1;
  }
  
  int getResEnd() {
       if (_resIndex >= 0 && _resIndex < _resEnd.length) return _resEnd[_resIndex];
      return -1;
  }
}
