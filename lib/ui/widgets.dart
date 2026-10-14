import 'package:flutter/material.dart';

import 'theme.dart';

/// Lifted surface with a soft 1px border and 20px radius.
class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Space.xl)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Space.radius),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Gentle pulsing placeholder used while loading.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width = 48, this.height = 22});
  final double width, height;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 0.9).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm, left: Space.xs),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: Palette.of(context).textMuted, letterSpacing: 1.0),
    ),
  );
}
