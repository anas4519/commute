import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/coord_parser.dart';
import '../core/models.dart';
import '../data/places_client.dart';

/// Search (Places Autocomplete) or paste coordinates / a Maps link.
class PlacePicker extends StatefulWidget {
  const PlacePicker({super.key, required this.title});
  final String title;
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  late final PlacesClient _places = context.read<PlacesClient>();
  final _query = TextEditingController();
  final _paste = TextEditingController();
  final _pasteLabel = TextEditingController();
  Timer? _debounce;
  List<Suggestion> _results = [];
  String? _error;
  String? _pasteError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _places.newSession(); // one billing session per picker opening
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _paste.dispose();
    _pasteLabel.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await _places.autocomplete(q.trim());
        if (mounted && _query.text.trim() == q.trim()) {
          setState(() {
            _results = r;
            _error = null;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      }
    });
  }

  Future<void> _select(Suggestion s) async {
    setState(() => _busy = true);
    try {
      final p = await _places.details(s.placeId);
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _usePaste() async {
    var text = _paste.text.trim();
    setState(() => _pasteError = null);
    if (CoordParser.isShortMapsLink(text)) {
      setState(() => _busy = true);
      final resolved = await _places.resolveShortLink(text);
      if (!mounted) return;
      setState(() => _busy = false);
      if (resolved == null) {
        setState(() => _pasteError = "Couldn't open the short link. Paste the full URL or coordinates.");
        return;
      }
      text = resolved;
    }
    final ll = CoordParser.parse(text);
    if (ll == null) {
      setState(() => _pasteError = 'No coordinates found. Try "28.6139, 77.2090".');
      return;
    }
    final label = _pasteLabel.text.trim().isEmpty ? ll.key : _pasteLabel.text.trim();
    if (mounted) Navigator.pop(context, Place(label: label, location: ll));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Search'),
              Tab(text: 'Paste'),
            ],
            dividerColor: Colors.transparent,
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: _onQuery,
                      decoration: const InputDecoration(
                        hintText: 'Search a place or station',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                      ),
                    const SizedBox(height: 8),
                    for (final s in _results)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Icon(Icons.place_outlined, color: t.colorScheme.onSurfaceVariant),
                        title: Text(s.main),
                        subtitle: Text(s.secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _select(s),
                      ),
                    if (_results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Powered by Google',
                          textAlign: TextAlign.end,
                          style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      controller: _paste,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '28.6139, 77.2090  or a Google Maps link',
                        errorText: _pasteError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pasteLabel,
                      decoration: const InputDecoration(hintText: 'Label (e.g. Home)'),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _usePaste,
                      child: const Text('Use location'),
                    ),
                  ],
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}
