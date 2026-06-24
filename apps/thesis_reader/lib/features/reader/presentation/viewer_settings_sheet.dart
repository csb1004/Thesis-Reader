import 'package:flutter/material.dart';
import 'package:thesis_reader/features/reader/domain/reader_settings.dart';

final class ViewerSettingsSheet extends StatelessWidget {
  const ViewerSettingsSheet({
    super.key,
    this.settings = const ReaderSettings(),
    this.onChanged,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.tune),
                const SizedBox(width: 8),
                Text('뷰어 설정', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 18),
            _ReadingModeControl(settings: settings, onChanged: onChanged),
            const SizedBox(height: 18),
            _SettingSlider(
              label: '글자 크기',
              icon: Icons.format_size,
              value: settings.fontScale,
              min: 0.85,
              max: 1.8,
              divisions: 19,
              onChanged: (value) =>
                  onChanged?.call(settings.copyWith(fontScale: value)),
            ),
            _SettingSlider(
              label: '줄 간격',
              icon: Icons.format_line_spacing,
              value: settings.lineHeight,
              min: 1.2,
              max: 2.0,
              divisions: 8,
              onChanged: (value) =>
                  onChanged?.call(settings.copyWith(lineHeight: value)),
            ),
            _SettingSlider(
              label: '여백',
              icon: Icons.width_normal,
              value: settings.marginScale,
              min: 0.75,
              max: 1.5,
              divisions: 15,
              onChanged: (value) =>
                  onChanged?.call(settings.copyWith(marginScale: value)),
            ),
            const SizedBox(height: 8),
            _AssetOpenModeControl(settings: settings, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

final class _ReadingModeControl extends StatelessWidget {
  const _ReadingModeControl({required this.settings, required this.onChanged});

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingLabel(icon: Icons.menu_book, label: '열람 방식'),
        const SizedBox(height: 8),
        SegmentedButton<ReadingMode>(
          segments: const [
            ButtonSegment(
              value: ReadingMode.page,
              icon: Icon(Icons.view_carousel),
              label: Text('페이지'),
            ),
            ButtonSegment(
              value: ReadingMode.scroll,
              icon: Icon(Icons.view_day),
              label: Text('스크롤'),
            ),
          ],
          selected: {settings.readingMode},
          onSelectionChanged: (selection) {
            onChanged?.call(settings.copyWith(readingMode: selection.single));
          },
        ),
      ],
    );
  }
}

final class _AssetOpenModeControl extends StatelessWidget {
  const _AssetOpenModeControl({
    required this.settings,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingLabel(icon: Icons.image, label: '그림 열기'),
        const SizedBox(height: 8),
        SegmentedButton<AssetOpenMode>(
          segments: const [
            ButtonSegment(
              value: AssetOpenMode.bottomSheet,
              icon: Icon(Icons.vertical_align_top),
              label: Text('시트'),
            ),
            ButtonSegment(
              value: AssetOpenMode.fullScreen,
              icon: Icon(Icons.fullscreen),
              label: Text('전체'),
            ),
          ],
          selected: {settings.assetOpenMode},
          onSelectionChanged: (selection) {
            onChanged?.call(settings.copyWith(assetOpenMode: selection.single));
          },
        ),
      ],
    );
  }
}

final class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingLabel(icon: icon, label: label),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

final class _SettingLabel extends StatelessWidget {
  const _SettingLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
