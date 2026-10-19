import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/maps_link.dart';
import '../data/ride_launcher.dart';

import '../core/models.dart';
import '../data/controller.dart';
import 'edit_pair_screen.dart';
import 'format.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

IconData modeIcon(TravelMode m) => switch (m) {
  TravelMode.walk => Icons.directions_walk_rounded,
  TravelMode.drive => Icons.directions_car_filled_rounded,
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
    if (s == AppLifecycleState.resumed) context.read<CommuteController>().refresh();
  }

  void _add() => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditPairScreen()));

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CommuteController>();
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () => c.refresh(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.md, Space.xxl),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: Space.xl),
                            Text('Commute', style: t.displaySmall),
                            const SizedBox(height: Space.sm),
                            Row(
                              children: [
                                Text(
                                  fmtAgo(c.lastUpdated, DateTime.now()),
                                  style: t.bodySmall?.copyWith(color: p.textMuted),
                                ),
                                if (c.loading) ...[
                                  const SizedBox(width: Space.sm),
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 1.4, color: p.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.tune_rounded),
                        onPressed: () => showSettings(context),
                      ),
                      IconButton(tooltip: 'Add route', icon: const Icon(Icons.add_rounded), onPressed: _add),
                    ],
                  ),
                ),
              ),
            ),
            if (c.banner != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
                sliver: SliverToBoxAdapter(child: _Banner(text: c.banner!)),
              ),
            if (c.pairs.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _Empty(onAdd: _add))
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xxxl + bottom),
                sliver: SliverReorderableList(
                  itemCount: c.pairs.length,
                  onReorderItem: c.reorder,
                  proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
                  itemBuilder: (context, i) {
                    final pair = c.pairs[i];
                    return Padding(
                      key: ValueKey(pair.id),
                      padding: const EdgeInsets.only(bottom: Space.lg),
                      child: ReorderableDelayedDragStartListener(
                        index: i,
                        child: Dismissible(
                          key: ValueKey('d${pair.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: Space.xxl),
                            child: Icon(Icons.delete_outline_rounded, color: p.danger),
                          ),
                          onDismissed: (_) {
                            c.remove(pair.id);
                            ScaffoldMessenger.of(context)
                              ..clearSnackBars()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text('Route removed'),
                                  action: SnackBarAction(label: 'Undo', onPressed: () => c.insertAt(i, pair)),
                                ),
                              );
                          },
                          child: _RouteCard(pair: pair),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: p.danger.withValues(alpha: 0.08),
        border: Border.all(color: p.danger.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(Space.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: p.danger),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.text)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.xxl, 0, Space.xxl, Space.xxxl * 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: p.border),
            ),
            child: Icon(Icons.route_rounded, color: p.accent, size: 28),
          ),
          const SizedBox(height: Space.xxl),
          Text('No routes yet', style: t.titleLarge),
          const SizedBox(height: Space.sm),
          Text(
            'Add the trips you take, like home to each metro station, and see which way is fastest right now.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: Space.xxl),
          SizedBox(
            width: 200,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add route'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.pair});
  final CommutePair pair;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CommuteController>();
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final best = c.bestFor(pair);
    final now = DateTime.now();
    return Surface(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPairScreen(pair: pair))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pair.name.trim().isNotEmpty) ...[
                      Text(pair.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                      const SizedBox(height: Space.xs),
                    ],
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pair.origin.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pair.name.trim().isEmpty
                                ? t.titleMedium
                                : t.bodyMedium?.copyWith(color: p.textMuted),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                          child: Icon(Icons.arrow_forward_rounded, size: 16, color: p.textMuted),
                        ),
                        Flexible(
                          child: Text(
                            pair.destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pair.name.trim().isEmpty
                                ? t.titleMedium
                                : t.bodyMedium?.copyWith(color: p.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Transform.translate(
                offset: const Offset(Space.sm, -Space.sm),
                child: IconButton(
                  tooltip: 'Open in Maps',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.near_me_outlined, size: 20, color: p.textMuted),
                  onPressed: () => _openMaps(context, best),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              for (final (i, m) in c.orderedModes.indexed) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: _ModeTile(
                    onTap: () => _openMaps(context, m),
                    mode: m,
                    result: c.cache.get(pair.id, m),
                    best: m == best,
                    stale: !c.cache.isFresh(pair, m, now),
                    loading: c.loading,
                    routeKey: pair.routeKey,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              _RideChip(
                label: 'Uber',
                icon: Icons.local_taxi_outlined,
                onTap: () => _ride(context, 'Uber', RideLauncher.uber),
              ),
              const SizedBox(width: Space.sm),
              _RideChip(
                label: 'Rapido',
                icon: Icons.two_wheeler_rounded,
                onTap: () => _ride(context, 'Rapido', RideLauncher.rapido),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _ride(BuildContext context, String name, Future<bool> Function(CommutePair) launch) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launch(pair);
    if (!ok) messenger.showSnackBar(SnackBar(content: Text("Couldn't open $name")));
  }

  Future<void> _openMaps(BuildContext context, TravelMode? mode) async {
    final uri = mapsDirectionsUri(pair.origin.location, pair.destination.location, mode: mode);
    final messenger = ScaffoldMessenger.of(context);
    bool ok;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) messenger.showSnackBar(const SnackBar(content: Text("Couldn't open Google Maps")));
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.result,
    required this.best,
    required this.stale,
    required this.loading,
    required this.routeKey,
    required this.onTap,
  });
  final VoidCallback onTap;
  final TravelMode mode;
  final LegResult? result;
  final bool best, stale, loading;
  final String routeKey;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final r = (result != null && result!.routeKey == routeKey) ? result : null;
    final fg = best ? p.onAccent : p.text;
    final muted = best ? p.onAccent.withValues(alpha: 0.7) : p.textMuted;

    Widget value;
    if (r == null && loading) {
      value = const Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Shimmer(width: 44, height: 22),
      );
    } else if (r == null || !r.ok) {
      value = Text(
        'n/a',
        style: t.titleLarge?.copyWith(color: muted, fontWeight: FontWeight.w500),
      );
    } else {
      value = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: fmtDuration(r.durationSec!)),
            TextSpan(
              text: ' min',
              style: t.labelMedium?.copyWith(color: muted),
            ),
          ],
        ),
        maxLines: 1,
        style: t.headlineSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    final sub = r == null ? '' : (r.ok ? fmtDistance(r.distanceMeters) : (r.error ?? ''));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.sm, Space.md),
        decoration: BoxDecoration(
          color: best ? p.accent : p.surfaceHi,
          borderRadius: BorderRadius.circular(Space.radiusSm),
        ),
        child: Opacity(
          opacity: stale && !best && r != null && r.ok ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(modeIcon(mode), size: 16, color: muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(mode.label, maxLines: 1, style: t.labelSmall?.copyWith(color: muted)),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
              const SizedBox(height: Space.xs),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelSmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideChip extends StatelessWidget {
  const _RideChip({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: p.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: p.textMuted),
                const SizedBox(width: 6),
                Text(label, style: t.labelMedium?.copyWith(color: p.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
