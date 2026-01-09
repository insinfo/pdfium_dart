enum FxCodecStatus {
  error(-1),
  frameReady,
  frameToBeContinued,
  decodeReady,
  decodeToBeContinued,
  decodeFinished;

  final int? value;
  const FxCodecStatus([this.value]);
}

enum FxCodecImageType {
  unknown(0),
  jpg,
  bmp,
  png,
  gif,
  tiff;

  final int value;
  const FxCodecImageType([int? v]) : value = v ?? -1; 
}
