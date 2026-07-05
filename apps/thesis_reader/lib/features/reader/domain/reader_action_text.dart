String readerActionPreview(String text, {int maxLength = 52}) {
  final compact = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.length <= maxLength) {
    return compact;
  }

  final bodyLength = (maxLength - 3).clamp(1, maxLength);
  final wordBoundary = compact.lastIndexOf(' ', bodyLength);
  final end = wordBoundary <= 0 ? bodyLength : wordBoundary;
  return '${compact.substring(0, end).trimRight()}...';
}
