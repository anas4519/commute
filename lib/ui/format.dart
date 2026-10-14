String fmtDuration(int sec) {
  final m = (sec / 60).round();
  if (m < 60) return '$m';
  return '${m ~/ 60}h ${m % 60}';
}

String fmtDistance(int? m) {
  if (m == null) return '';
  return m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(1)} km';
}

String fmtAgo(DateTime? t, DateTime now) {
  if (t == null) return 'Not updated yet';
  final d = now.difference(t);
  if (d.inSeconds < 45) return 'Updated just now';
  if (d.inMinutes < 60) return 'Updated ${d.inMinutes} min ago';
  if (d.inHours < 24) return 'Updated ${d.inHours} h ago';
  return 'Updated ${d.inDays} d ago';
}
