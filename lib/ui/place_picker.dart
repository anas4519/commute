import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/coord_parser.dart';
import '../core/link_utils.dart';
import '../core/log.dart';
import '../core/models.dart';
import '../data/places_client.dart';
import 'theme.dart';

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
    final raw = _paste.text.trim();
    setState(() => _pasteError = null);
    // Plain coordinates first, then the first URL inside share text.
    var ll = CoordParser.parse(raw);
    final url = LinkUtils.extractFirstUrl(raw);
    if (ll == null && url != null) ll = CoordParser.parse(url);
    if (ll == null && url != null && CoordParser.isShortMapsLink(url)) {
      setState(() => _busy = true);
      ResolveResult r;
      try {
        // Outer guard on top of the client's own deadline.
        r = await _places
            .resolveShortLink(url)
            .timeout(const Duration(seconds: 30), onTimeout: () => const ResolveResult(error: 'Timed out'));
      } catch (e) {
        AppLog.d('ui', 'resolve threw ${e.runtimeType}: $e');
        r = ResolveResult(error: '$e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
      if (r.location == null) {
        setState(
          () => _pasteError = kDebugMode
              ? "Couldn't resolve the link: ${r.error}"
              : "Couldn't resolve the link (${r.error}). Paste the full URL or coordinates.",
        );
        return;
      }
      ll = r.location;
    }
    if (ll == null) {
      setState(() => _pasteError = 'No coordinates found. Try "28.6139, 77.2090".');
      return;
    }
    // Default label: first non-URL line of shared text, else the coordinates.
    final firstLine = raw
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'(https?|intent)://\S+'), '').trim())
        .firstWhere((l) => l.isNotEmpty && CoordParser.parse(l) == null, orElse: () => '');
    final typed = _pasteLabel.text.trim();
    final label = typed.isNotEmpty ? typed : (firstLine.isNotEmpty ? firstLine : ll.key);
    if (mounted) Navigator.pop(context, Place(label: label, location: ll));
  }

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final search = <Widget>[
      TextField(
        controller: _query,
        autofocus: true,
        onChanged: _onQuery,
        textInputAction: TextInputAction.search,
        style: t.bodyLarge,
        decoration: const InputDecoration(
          hintText: 'Search a place or station',
          prefixIcon: Icon(Icons.search_rounded, size: 20),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: Space.md),
          child: Text(_error!, style: t.bodySmall?.copyWith(color: p.danger)),
        ),
      const SizedBox(height: Space.lg),
      if (_results.isEmpty && _query.text.trim().length < 3)
        Padding(
          padding: const EdgeInsets.only(top: Space.xxl),
          child: Text(
            'Type at least 3 letters',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: p.textMuted),
          ),
        ),
      if (_results.isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.border),
            borderRadius: BorderRadius.circular(Space.radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, s) in _results.indexed) ...[
                if (i > 0) Divider(height: 1, color: p.border, indent: 56),
                ListTile(
                  leading: Icon(Icons.place_outlined, size: 20, color: p.textMuted),
                  title: Text(s.main, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _select(s),
                ),
              ],
            ],
          ),
        ),
      if (_results.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Space.md, right: Space.xs),
          child: Text(
            'Powered by Google',
            textAlign: TextAlign.end,
            style: t.labelSmall?.copyWith(color: p.textMuted),
          ),
        ),
    ];
    final paste = <Widget>[
      TextField(
        controller: _paste,
        minLines: 2,
        maxLines: 4,
        style: t.bodyLarge,
        decoration: InputDecoration(
          hintText: '28.6139, 77.2090\nor a Google Maps link',
          errorText: _pasteError,
        ),
      ),
      const SizedBox(height: Space.md),
      TextField(
        controller: _pasteLabel,
        textCapitalization: TextCapitalization.words,
        style: t.bodyLarge,
        decoration: const InputDecoration(hintText: 'Label, e.g. Home'),
      ),
      const SizedBox(height: Space.xxl),
      FilledButton(onPressed: _busy ? null : _usePaste, child: const Text('Use location')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.xl),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Search')),
                    ButtonSegment(value: 1, label: Text('Paste')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: _tab == 0 ? search : paste,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
