class BarcodeService {
  bool isLikelyBarcode(String value) {
    final text = value.trim();
    return text.length >= 8 && text.length <= 18;
  }
}
