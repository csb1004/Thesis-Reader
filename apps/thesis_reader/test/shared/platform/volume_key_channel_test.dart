import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/shared/platform/volume_key_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = StandardMethodCodec();

  test('maps Android volume methods to navigation events', () async {
    final channel = VolumeKeyChannel();
    final events = <VolumeKeyEvent>[];
    final subscription = channel.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(channel.dispose);

    await _sendMethodCall('volumeDown', codec);
    await _sendMethodCall('volumeUp', codec);
    await _sendMethodCall('ignoredMethod', codec);

    expect(events, [VolumeKeyEvent.next, VolumeKeyEvent.previous]);
  });
}

Future<void> _sendMethodCall(String method, MethodCodec codec) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        VolumeKeyChannel.channelName,
        codec.encodeMethodCall(MethodCall(method)),
        (_) {},
      );
}
