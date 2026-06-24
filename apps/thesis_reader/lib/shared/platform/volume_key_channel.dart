import 'dart:async';

import 'package:flutter/services.dart';

enum VolumeKeyEvent { next, previous }

final class VolumeKeyChannel {
  VolumeKeyChannel({
    MethodChannel methodChannel = const MethodChannel(channelName),
  }) : _methodChannel = methodChannel {
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  static const channelName = 'thesis_reader/volume_keys';
  static final instance = VolumeKeyChannel();

  final MethodChannel _methodChannel;
  final _events = StreamController<VolumeKeyEvent>.broadcast();

  Stream<VolumeKeyEvent> get events => _events.stream;

  Future<void> dispose() async {
    _methodChannel.setMethodCallHandler(null);
    await _events.close();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'volumeDown':
        _events.add(VolumeKeyEvent.next);
      case 'volumeUp':
        _events.add(VolumeKeyEvent.previous);
    }
  }
}
