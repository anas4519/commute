import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../data/controller.dart';
import 'place_picker.dart';

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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final editing = widget.pair != null;
    final canSave = _from != null && _to != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit route' : 'New route'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                context.read<CommuteController>().remove(widget.pair!.id);
                Navigator.pop(context);
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PlaceField(label: 'From', place: _from, onTap: () => _pick(true)),
          Align(
            child: IconButton(
              tooltip: 'Swap',
              icon: const Icon(Icons.swap_vert_rounded),
              onPressed: () => setState(() {
                final f = _from;
                _from = _to;
                _to = f;
              }),
            ),
          ),
          _PlaceField(label: 'To', place: _to, onTap: () => _pick(false)),
          const SizedBox(height: 28),
          Text('Name (optional)', style: t.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: 'e.g. Via Station A'),
          ),
          const SizedBox(height: 32),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _PlaceField extends StatelessWidget {
  const _PlaceField({required this.label, required this.place, required this.onTap});
  final String label;
  final Place? place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        onTap: onTap,
        title: Text(label, style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        subtitle: Text(
          place?.label ?? 'Choose a place',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.textTheme.titleMedium?.copyWith(
            color: place == null ? t.colorScheme.onSurfaceVariant : t.colorScheme.onSurface,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
