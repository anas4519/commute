import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../data/controller.dart';
import 'place_picker.dart';
import 'theme.dart';
import 'widgets.dart';

class EditPairScreen extends StatefulWidget {
  const EditPairScreen({super.key, this.pair});
  final CommutePair? pair;
  @override
  State<EditPairScreen> createState() => _EditPairScreenState();
}

class _EditPairScreenState extends State<EditPairScreen> {
  late final _name = TextEditingController(text: widget.pair?.name ?? '');
  Place? _from, _to;

  @override
  void initState() {
    super.initState();
    _from = widget.pair?.origin;
    _to = widget.pair?.destination;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final p = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => PlacePicker(title: from ? 'From' : 'To')),
    );
    if (p != null) setState(() => from ? _from = p : _to = p);
  }

  Future<void> _delete() async {
    final p = Palette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: const Text('Delete route?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: p.danger)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<CommuteController>().remove(widget.pair!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final editing = widget.pair != null;
    final canSave = _from != null && _to != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit route' : 'New route'),
        actions: [
          if (editing)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
                children: [
                  const SectionLabel('Route'),
                  Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border.all(color: p.border),
                      borderRadius: BorderRadius.circular(Space.radius),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            _PlaceRow(
                              label: 'From',
                              place: _from,
                              dot: p.textMuted,
                              onTap: () => _pick(true),
                            ),
                            Divider(height: 1, color: p.border, indent: 52),
                            _PlaceRow(label: 'To', place: _to, dot: p.accent, onTap: () => _pick(false)),
                          ],
                        ),
                        Positioned(
                          right: Space.sm,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Material(
                              color: p.surfaceHi,
                              shape: CircleBorder(side: BorderSide(color: p.border)),
                              child: IconButton(
                                tooltip: 'Swap',
                                icon: const Icon(Icons.swap_vert_rounded, size: 20),
                                onPressed: () => setState(() {
                                  final f = _from;
                                  _from = _to;
                                  _to = f;
                                }),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  const SectionLabel('Name · optional'),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    style: t.bodyLarge,
                    decoration: const InputDecoration(hintText: 'e.g. Via Rajiv Chowk'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.lg),
              child: FilledButton(
                onPressed: canSave
                    ? () {
                        context.read<CommuteController>().upsert(
                          id: widget.pair?.id,
                          name: _name.text.trim(),
                          origin: _from!,
                          dest: _to!,
                        );
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(editing ? 'Save changes' : 'Add route'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.label, required this.place, required this.dot, required this.onTap});
  final String label;
  final Place? place;
  final Color dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, 72, Space.lg),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: Space.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.labelSmall?.copyWith(color: p.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    place?.label ?? 'Choose a place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(
                      color: place == null ? p.textMuted : p.text,
                      fontWeight: place == null ? FontWeight.w400 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
