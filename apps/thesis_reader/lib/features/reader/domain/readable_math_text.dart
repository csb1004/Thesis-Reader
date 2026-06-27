final _subscriptMarkerPattern = RegExp(
  r'_\{([^{}\r\n]{1,16})\}|₍([\u0370-\u03ff]{1,8})₎',
);

final class ReadableMathTextToken {
  const ReadableMathTextToken(this.text, {required this.isSubscript});

  final String text;
  final bool isSubscript;
}

final class ReadableMathLayoutText {
  const ReadableMathLayoutText(this.text, this._sourceOffsets);

  final String text;
  final List<int> _sourceOffsets;

  int sourceOffsetAt(int displayOffset) {
    final clamped = displayOffset.clamp(0, _sourceOffsets.length - 1);
    return _sourceOffsets[clamped];
  }
}

bool hasReadableMathMarkers(String text) =>
    _subscriptMarkerPattern.hasMatch(text);

List<ReadableMathTextToken> parseReadableMathText(String text) {
  final tokens = <ReadableMathTextToken>[];
  var offset = 0;

  for (final match in _subscriptMarkerPattern.allMatches(text)) {
    if (offset < match.start) {
      tokens.add(
        ReadableMathTextToken(
          text.substring(offset, match.start),
          isSubscript: false,
        ),
      );
    }

    tokens.add(
      ReadableMathTextToken(
        match.group(1) ?? match.group(2) ?? '',
        isSubscript: true,
      ),
    );
    offset = match.end;
  }

  if (offset < text.length) {
    tokens.add(
      ReadableMathTextToken(text.substring(offset), isSubscript: false),
    );
  }

  return List.unmodifiable(tokens);
}

ReadableMathLayoutText buildReadableMathLayoutText(String text) {
  if (!hasReadableMathMarkers(text)) {
    return ReadableMathLayoutText(
      text,
      List<int>.generate(text.length + 1, (index) => index),
    );
  }

  final display = StringBuffer();
  final sourceOffsets = <int>[0];
  var offset = 0;

  void appendPlain(int start, int end) {
    for (var index = start; index < end; index += 1) {
      display.write(text[index]);
      sourceOffsets.add(index + 1);
    }
  }

  void appendSubscript(String value, int sourceEnd) {
    for (var index = 0; index < value.length; index += 1) {
      display.write(value[index]);
      sourceOffsets.add(sourceEnd);
    }
  }

  for (final match in _subscriptMarkerPattern.allMatches(text)) {
    appendPlain(offset, match.start);
    appendSubscript(match.group(1) ?? match.group(2) ?? '', match.end);
    offset = match.end;
  }
  appendPlain(offset, text.length);

  return ReadableMathLayoutText(
    display.toString(),
    List.unmodifiable(sourceOffsets),
  );
}
