import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesis_reader/shared/platform/volume_key_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = StandardMethodCodec();
  const testChannelName = 'test/volume_keys';
  const methodChannel = MethodChannel(testChannelName);

  test('maps Android volume methods to navigation events', () async {
    final channel = VolumeKeyChannel(methodChannel: methodChannel);
    final events = <VolumeKeyEvent>[];
    final subscription = channel.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(channel.dispose);

    await _sendMethodCall(testChannelName, 'volumeDown', codec);
    await _sendMethodCall(testChannelName, 'volumeUp', codec);
    await _sendMethodCall(testChannelName, 'ignoredMethod', codec);

    expect(events, [VolumeKeyEvent.next, VolumeKeyEvent.previous]);
  });

  test('sends native volume navigation enabled state', () async {
    final channel = VolumeKeyChannel(methodChannel: methodChannel);
    final calls = <MethodCall>[];
    addTearDown(channel.dispose);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          return null;
        });

    await channel.setVolumeKeyNavigationEnabled(true);
    await channel.setVolumeKeyNavigationEnabled(false);

    expect(calls, [
      isMethodCall('setVolumeKeyNavigationEnabled', arguments: true),
      isMethodCall('setVolumeKeyNavigationEnabled', arguments: false),
    ]);
  });
}

Future<void> _sendMethodCall(
  String channelName,
  String method,
  MethodCodec codec,
) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channelName,
        codec.encodeMethodCall(MethodCall(method)),
        (_) {},
      );
}
