import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/log.dart';
import 'theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    AppLog.I.addListener(_changed);
  }

  @override
  void dispose() {
    AppLog.I.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    final lines = AppLog.I.lines;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: lines.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Copied ${lines.length} lines')));
              }
            },
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            onPressed: AppLog.I.clear,
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: SafeArea(
        child: lines.isEmpty
            ? Center(
                child: Text('No log lines yet', style: t.bodyMedium?.copyWith(color: p.textMuted)),
              )
            : Container(
                margin: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border.all(color: p.border),
                  borderRadius: BorderRadius.circular(Space.radiusSm),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  padding: const EdgeInsets.all(Space.md),
                  child: SelectableText(
                    lines.join('\n'),
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.45, color: p.text),
                  ),
                ),
              ),
      ),
    );
  }
}
