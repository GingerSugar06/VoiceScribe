import 'engine.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String clock(double sec) {
  final s = sec.floor();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, r = s % 60;
  return h > 0 ? '${_two(h)}:${_two(m)}:${_two(r)}' : '${_two(m)}:${_two(r)}';
}

String _srtTime(double sec) {
  final ms = (sec * 1000).round();
  final h = ms ~/ 3600000, m = (ms % 3600000) ~/ 60000, s = (ms % 60000) ~/ 1000, r = ms % 1000;
  return '${_two(h)}:${_two(m)}:${_two(s)},${r.toString().padLeft(3, '0')}';
}

String toPlain(List<Segment> segs, {bool stamps = false}) => segs
    .map((s) => stamps ? '[${clock(s.start)}] ${s.text}' : s.text)
    .join(stamps ? '\n' : ' ');

String toSrt(List<Segment> segs) {
  final b = StringBuffer();
  for (var i = 0; i < segs.length; i++) {
    b.writeln(i + 1);
    b.writeln('${_srtTime(segs[i].start)} --> ${_srtTime(segs[i].end)}');
    b.writeln(segs[i].text);
    b.writeln();
  }
  return b.toString();
}

int wordCount(List<Segment> segs) =>
    segs.fold(0, (a, s) => a + s.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);
