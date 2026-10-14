import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../data/controller.dart';
import 'edit_pair_screen.dart';
import 'format.dart';

IconData modeIcon(TravelMode m) => switch (m) {
  TravelMode.walk => Icons.directions_walk_rounded,
  TravelMode.drive => Icons.directions_car_rounded,
  TravelMode.twoWheeler => Icons.two_wheeler_rounded,
  TravelMode.bicycle => Icons.pedal_bike_rounded,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<CommuteController>().refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) context.read<CommuteController>().refresh(); // TTL-gated
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CommuteController>();
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commute'),
        actions: [
          IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () => _settings(context)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditPairScreen())),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () => c.refresh(force: true),
        child: c.pairs.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Text(
                      'Add a route to compare walk, car and bike times.',
                      style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                header: _Header(c: c),
                itemCount: c.pairs.length,
                onReorderItem: c.reorder,
                buildDefaultDragHandles: false,
                itemBuilder: (_, i) {
                  final p = c.pairs[i];
                  return Padding(
                    key: ValueKey(p.id),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Dismissible(
                      key: ValueKey('d${p.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: Icon(Icons.delete_outline_rounded, color: t.colorScheme.error),
                      ),
                      onDismissed: (_) {
                        c.remove(p.id);
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('Removed ${p.title}'),
                              action: SnackBarAction(label: 'Undo', onPressed: () => c.insertAt(i, p)),
                            ),
                          );
                      },
                      child: ReorderableDelayedDragStartListener(
                        index: i,
                        child: _PairCard(pair: p),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _settings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Consumer<CommuteController>(
        builder: (_, c, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in TravelMode.values)
                  SwitchListTile(
                    secondary: Icon(modeIcon(m)),
                    title: Text(m == TravelMode.twoWheeler ? 'Bike (two-wheeler)' : m.label),
                    subtitle: m == TravelMode.bicycle ? const Text('Limited coverage in India') : null,
                    value: c.modes.contains(m),
                    onChanged: (v) => c.toggleMode(m, v),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final CommuteController c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // Overall fastest across all pairs.
    String? headline;
    int? bestSec;
    for (final p in c.pairs) {
      final m = c.bestFor(p);
      final r = m == null ? null : c.cache.get(p.id, m);
      if (r != null && (bestSec == null || r.durationSec! < bestSec)) {
        bestSec = r.durationSec;
        headline = '${p.destination.label} by ${m!.label.toLowerCase()}';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headline != null) ...[
            Text(
              'Fastest right now',
              style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${fmtDuration(bestSec!)} min',
                    style: TextStyle(color: t.colorScheme.primary),
                  ),
                  TextSpan(text: '  ·  $headline'),
                ],
              ),
              style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text(
                fmtAgo(c.lastUpdated, DateTime.now()),
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              if (c.loading) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
              ],
            ],
          ),
          if (c.banner != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                c.banner!,
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({required this.pair});
  final CommutePair pair;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CommuteController>();
    final t = Theme.of(context);
    final best = c.bestFor(pair);
    final now = DateTime.now();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPairScreen(pair: pair))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pair.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
              ),
              if (pair.name.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${pair.origin.label} → ${pair.destination.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (i, m) in c.orderedModes.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _ModeTile(
                        mode: m,
                        result: c.cache.get(pair.id, m),
                        best: m == best,
                        stale: !c.cache.isFresh(pair, m, now),
                        routeKey: pair.routeKey,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.result,
    required this.best,
    required this.stale,
    required this.routeKey,
  });
  final TravelMode mode;
  final LegResult? result;
  final bool best;
  final bool stale;
  final String routeKey;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    final r = (result != null && result!.routeKey == routeKey) ? result : null;
    final fg = best ? s.onPrimary : s.onSurface;
    final sub = best ? s.onPrimary.withValues(alpha: 0.8) : s.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: best ? s.primary : s.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Opacity(
        opacity: stale && !best ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(modeIcon(mode), size: 18, color: sub),
            const SizedBox(height: 8),
            if (r == null)
              Text('—', style: t.textTheme.titleLarge?.copyWith(color: sub))
            else if (!r.ok)
              Text('n/a', style: t.textTheme.titleMedium?.copyWith(color: sub))
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: fmtDuration(r.durationSec!)),
                    TextSpan(
                      text: ' min',
                      style: t.textTheme.bodySmall?.copyWith(color: sub),
                    ),
                  ],
                ),
                style: t.textTheme.titleLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              r == null ? mode.label : (r.ok ? fmtDistance(r.distanceMeters) : (r.error ?? '')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.labelSmall?.copyWith(color: sub),
            ),
          ],
        ),
      ),
    );
  }
}
