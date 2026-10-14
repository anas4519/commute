import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../data/controller.dart';
import 'home_screen.dart' show modeIcon;
import 'logs_screen.dart';
import 'theme.dart';
import 'widgets.dart';

void showSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Consumer<CommuteController>(
      builder: (context, c, _) {
        final t = Theme.of(context).textTheme;
        final p = Palette.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: t.titleLarge),
                const SizedBox(height: Space.xxl),
                const SectionLabel('Appearance'),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ],
                    selected: {c.themeMode},
                    onSelectionChanged: (s) => c.setThemeMode(s.first),
                  ),
                ),
                const SizedBox(height: Space.xxl),
                const SectionLabel('Modes'),
                Container(
                  decoration: BoxDecoration(
                    color: p.bg,
                    border: Border.all(color: p.border),
                    borderRadius: BorderRadius.circular(Space.radiusSm),
                  ),
                  child: Column(
                    children: [
                      for (final (i, m) in TravelMode.values.indexed) ...[
                        if (i > 0) Divider(height: 1, color: p.border, indent: Space.lg, endIndent: Space.lg),
                        SwitchListTile(
                          secondary: Icon(modeIcon(m), size: 20),
                          title: Text(m == TravelMode.twoWheeler ? 'Bike' : m.label),
                          subtitle: switch (m) {
                            TravelMode.twoWheeler => const Text('Two-wheeler, live traffic'),
                            TravelMode.drive => const Text('Live traffic'),
                            TravelMode.bicycle => const Text('Limited coverage in India'),
                            _ => null,
                          },
                          value: c.modes.contains(m),
                          onChanged: (v) => c.toggleMode(m, v),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Space.xxl),
                const SectionLabel('Debug'),
                Container(
                  decoration: BoxDecoration(
                    color: p.bg,
                    border: Border.all(color: p.border),
                    borderRadius: BorderRadius.circular(Space.radiusSm),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, size: 20),
                    title: const Text('Logs'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(builder: (_) => const LogsScreen()));
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
