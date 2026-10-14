import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../engine/export.dart';
import '../engine/models.dart';
import '../state/app_state.dart';
import 'fx.dart';
import 'transcript_panel.dart';

String _mmss(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0 ? '${two(h)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}' : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}

// ===========================================================================
// Canlı kayıt
// ===========================================================================

class RecordPage extends StatelessWidget {
  const RecordPage({super.key, required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final l = s.l;
    final showOpened = s.opened != null && s.opened!.source == 'live' && !s.recording;
    final segs = showOpened ? s.opened!.segments : s.liveSegs;
    final status = s.finalizing
        ? l.t('transcribing')
        : s.recording
            ? (s.speaking ? l.t('speaking') : l.t('recording'))
            : l.t('tap_to_record');

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                child: MicOrb(
                  size: 118,
                  level: s.level,
                  active: s.recording,
                  speaking: s.speaking,
                  busy: s.finalizing,
                  onTap: () => s.recording ? s.stopRecording() : s.startRecording(),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        s.recording ? _mmss(s.elapsed) : ' ',
                        key: ValueKey(s.recording),
                        style: ts(30, w: FontWeight.w300, ls: 2).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(status,
                          key: ValueKey(status),
                          style: ts(13.5, c: s.recording ? (s.speaking ? C.cyan : C.dim) : C.dim)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Waveform(levels: s.levels, active: s.recording, height: 54),
        if (s.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(s.error!, style: ts(13, c: C.red)),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: TranscriptPanel(
            l: l,
            segments: segs,
            emptyText: l.t('empty_live'),
            listening: s.recording,
            speaking: s.speaking,
            title: showOpened ? s.opened!.title : null,
            onClear: s.recording ? null : () {
              s.open(null);
              s.clearLive();
            },
            baseName: showOpened ? p.basenameWithoutExtension(s.opened!.title) : 'kayit',
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Dosyadan
// ===========================================================================

class FilePage extends StatefulWidget {
  const FilePage({super.key, required this.s});
  final AppState s;
  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> with SingleTickerProviderStateMixin {
  bool _drag = false;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  AppState get s => widget.s;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles(type: FileType.any);
    if (r.isNotEmpty && r.first.path != null) s.transcribeFile(r.first.path!);
  }

  @override
  Widget build(BuildContext context) {
    final l = s.l;
    final showOpened = s.opened != null && s.opened!.source == 'file' && !s.fileBusy;
    final segs = showOpened ? s.opened!.segments : s.fileSegs;
    final compact = s.fileBusy || segs.isNotEmpty || showOpened;

    return Column(
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _drag = true),
          onDragExited: (_) => setState(() => _drag = false),
          onDragDone: (d) {
            setState(() => _drag = false);
            if (d.files.isNotEmpty) s.transcribeFile(d.files.first.path);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            height: compact ? 112 : 260,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(
                painter: _DashPainter(_c.value, _drag, s.fileBusy),
                child: Center(child: s.fileBusy ? _busy(l) : _idle(l, compact)),
              ),
            ),
          ),
        ),
        if (s.fileError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(s.fileError!, style: ts(13, c: C.red), textAlign: TextAlign.center),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: TranscriptPanel(
            l: l,
            segments: segs,
            emptyText: l.t('empty_file'),
            title: showOpened
                ? s.opened!.title
                : (s.filePath != null ? p.basename(s.filePath!) : null),
            baseName: showOpened
                ? p.basenameWithoutExtension(s.opened!.title)
                : (s.filePath != null ? p.basenameWithoutExtension(s.filePath!) : 'transkript'),
            onClear: s.fileBusy
                ? null
                : () {
                    s.open(null);
                    s.resetFile();
                  },
          ),
        ),
      ],
    );
  }

  Widget _idle(dynamic l, bool compact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: _drag ? 1 : 0),
          duration: const Duration(milliseconds: 300),
          builder: (_, v, __) => Transform.translate(
            offset: Offset(0, -6 * v + 3 * math.sin(_c.value * 2 * math.pi * 4)),
            child: Container(
              width: compact ? 52 : 84,
              height: compact ? 52 : 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [C.violet, C.cyan]),
                boxShadow: [BoxShadow(color: C.violet.withValues(alpha: 0.5), blurRadius: 24 + 16 * v)],
              ),
              child: Icon(Icons.upload_file_rounded, size: compact ? 26 : 40, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('drop_here'), style: ts(compact ? 15 : 18, w: FontWeight.w600)),
            const SizedBox(height: 4),
            if (!compact) Text(l.t('formats'), style: ts(12, c: C.faint)),
            SizedBox(height: compact ? 8 : 16),
            GradButton(label: l.t('choose_file'), icon: Icons.folder_open_rounded, onTap: _pick),
          ],
        ),
      ],
    );
  }

  Widget _busy(dynamic l) {
    final pr = s.fileProgress;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: pr < 0 ? null : pr,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                color: C.cyan,
                backgroundColor: C.edge(0.1),
              ),
              Text(pr < 0 ? '…' : '${(pr * 100).round()}%', style: ts(13, w: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('transcribing'), style: ts(16, w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(s.filePath == null ? '' : p.basename(s.filePath!),
                    overflow: TextOverflow.ellipsis, style: ts(12.5, c: C.dim)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pr < 0 ? null : pr,
                    minHeight: 6,
                    color: C.violet,
                    backgroundColor: C.edge(0.08),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          GhostButton(label: l.t('cancel'), icon: Icons.close_rounded, color: C.red, onTap: s.cancelFile),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.t, this.hot, this.busy);
  final double t;
  final bool hot, busy;

  @override
  void paint(Canvas canvas, Size s) {
    final rr = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(26));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = hot ? C.violet.withValues(alpha: 0.18) : C.glass(0.04),
    );
    final path = Path()..addRRect(rr.deflate(1));
    final metric = path.computeMetrics().first;
    const dash = 10.0, gap = 8.0;
    final offset = t * (dash + gap) * 6;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hot ? 2.4 : 1.6
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [C.violet, C.cyan, C.pink]).createShader(Offset.zero & s)
      ..color = Colors.white.withValues(alpha: hot ? 1 : 0.55);
    var d = -offset % (dash + gap);
    while (d < metric.length) {
      final a = math.max(0.0, d), b = math.min(metric.length, d + dash);
      if (b > a) canvas.drawPath(metric.extractPath(a, b), paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => true;
}

// ===========================================================================
// Geçmiş
// ===========================================================================

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final l = s.l;
    if (s.history.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history_rounded, size: 54, color: C.faint),
          const SizedBox(height: 14),
          Text(l.t('history_empty'), style: ts(15, c: C.faint)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: s.history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final t = s.history[i];
        final live = t.source == 'live';
        final preview = t.segments.take(3).map((e) => e.text).join(' ');
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 350 + math.min(i, 8) * 60),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) =>
              Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child)),
          child: _HistoryCard(
            icon: live ? Icons.mic_rounded : Icons.movie_rounded,
            accent: live ? C.pink : C.cyan,
            title: t.title,
            meta:
                '${s.pretty(t.created)} · ${clock(t.duration)} · ${wordCount(t.segments)} ${l.t('words')} · ${t.lang.toUpperCase()}',
            preview: preview,
            openLabel: l.t('open'),
            deleteLabel: l.t('delete'),
            onOpen: () {
              s.open(t);
              s.setTab(live ? 0 : 1);
            },
            onDelete: () => s.deleteTranscript(t),
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.meta,
    required this.preview,
    required this.onOpen,
    required this.onDelete,
    required this.openLabel,
    required this.deleteLabel,
  });
  final IconData icon;
  final Color accent;
  final String title, meta, preview, openLabel, deleteLabel;
  final VoidCallback onOpen, onDelete;
  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _h ? -2 : 0, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: C.glass(_h ? 0.10 : 0.05),
            border: Border.all(color: _h ? widget.accent.withValues(alpha: 0.5) : C.edge()),
            boxShadow: _h ? [BoxShadow(color: widget.accent.withValues(alpha: 0.18), blurRadius: 28)] : null,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.accent.withValues(alpha: 0.16),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 23),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, overflow: TextOverflow.ellipsis, style: ts(15, w: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(widget.meta, style: ts(12, c: C.dim)),
                    const SizedBox(height: 8),
                    Text(widget.preview,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(13.5, c: C.dim, h: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: widget.deleteLabel,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.delete_outline_rounded, size: 21, color: C.faint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Ayarlar
// ===========================================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.s});
  final AppState s;

  String _mb(int b) => '${(b / 1048576).round()} MB';

  Future<void> _reveal(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = s.l;
    final busy = s.phase == Phase.downloading || s.phase == Phase.loading;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(l.t('models'), style: ts(13, c: C.dim, w: FontWeight.w600, ls: 1)),
        const SizedBox(height: 12),
        for (final m in WhisperModel.all) ...[
          _ModelRow(
            title: l.t('model_${m.id}'),
            sub: l.t('model_${m.id}_d'),
            size: _mb(m.totalBytes),
            installed: s.installed.contains(m.id),
            active: s.modelId == m.id && s.installed.contains(m.id),
            busy: busy,
            progress: s.phase == Phase.downloading && s.dlLabel == m.id ? s.dlProgress : null,
            l: l,
            onUse: () => s.useModel(m),
            onGet: () => s.downloadModel(m),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        Text(l.t('ffmpeg_title').toUpperCase(), style: ts(13, c: C.dim, w: FontWeight.w600, ls: 1)),
        const SizedBox(height: 12),
        Glass(
          padding: const EdgeInsets.all(18),
          radius: 18,
          child: Row(children: [
            Icon(s.ffmpegPath != null ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: s.ffmpegPath != null ? C.green : C.amber),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.t('ffmpeg_d'), style: ts(14)),
                const SizedBox(height: 3),
                Text(s.ffmpegPath ?? l.t('not_installed'),
                    overflow: TextOverflow.ellipsis, style: ts(12, c: C.dim)),
                if (s.ffmpegBusy) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: s.ffmpegProgress, minHeight: 6, color: C.cyan, backgroundColor: C.edge(0.08)),
                  ),
                ],
              ]),
            ),
            if (s.ffmpegPath == null) ...[
              const SizedBox(width: 14),
              GradButton(
                label: l.t('ffmpeg_get'),
                icon: Icons.download_rounded,
                onTap: s.ffmpegBusy ? null : s.downloadFfmpeg,
              ),
            ],
          ]),
        ),
        const SizedBox(height: 18),
        Text(l.t('storage').toUpperCase(), style: ts(13, c: C.dim, w: FontWeight.w600, ls: 1)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          GhostButton(
              label: l.t('recordings_folder'),
              icon: Icons.folder_open_rounded,
              onTap: () => _reveal(s.store.recordingsDir.path)),
          GhostButton(
              label: l.t('transcripts_folder'),
              icon: Icons.folder_open_rounded,
              onTap: () => _reveal(s.store.transcriptsDir.path)),
        ]),
        if (s.error != null) ...[
          const SizedBox(height: 16),
          Text(s.error!, style: ts(13, c: C.red)),
        ],
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.title,
    required this.sub,
    required this.size,
    required this.installed,
    required this.active,
    required this.busy,
    required this.progress,
    required this.l,
    required this.onUse,
    required this.onGet,
  });
  final String title, sub, size;
  final bool installed, active, busy;
  final double? progress;
  final dynamic l;
  final VoidCallback onUse, onGet;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: C.glass(active ? 0.10 : 0.045),
        border: Border.all(color: active ? C.violet.withValues(alpha: 0.7) : C.edge()),
        boxShadow: active ? [BoxShadow(color: C.violet.withValues(alpha: 0.2), blurRadius: 24)] : null,
      ),
      child: Row(children: [
        Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: active ? C.violet : C.faint),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: ts(15, w: FontWeight.w600)),
              const SizedBox(width: 10),
              Text(size, style: ts(12, c: C.faint)),
            ]),
            const SizedBox(height: 3),
            Text(sub, style: ts(12.5, c: C.dim)),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress, minHeight: 6, color: C.violet, backgroundColor: C.edge(0.08)),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        if (active)
          Text(l.t('active'), style: ts(13, c: C.violet, w: FontWeight.w600))
        else if (installed)
          GhostButton(label: l.t('use'), onTap: busy ? null : onUse)
        else
          GhostButton(label: l.t('ffmpeg_get'), icon: Icons.download_rounded, onTap: busy ? null : onGet),
      ]),
    );
  }
}

// ===========================================================================
// İlk kurulum
// ===========================================================================

class SetupView extends StatefulWidget {
  const SetupView({super.key, required this.s});
  final AppState s;
  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  String _pick = 'small';

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final l = s.l;
    final dl = s.phase == Phase.downloading;
    final loading = s.phase == Phase.loading || s.phase == Phase.booting;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Glass(
            padding: const EdgeInsets.all(34),
            radius: 30,
            glow: C.violet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MicOrb(size: 52, level: 0, active: false, speaking: false, busy: true, onTap: _noop),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(children: [
                    Text(l.t('setup_title'), style: ts(26, w: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(l.t('setup_sub'), textAlign: TextAlign.center, style: ts(14, c: C.dim, h: 1.5)),
                  ]),
                ),
                if (loading) ...[
                  const SizedBox(height: 4),
                  Text(l.t('loading_model'), style: ts(14, c: C.cyan)),
                ] else ...[
                  for (final m in WhisperModel.all) ...[
                    _Pick(
                      selected: _pick == m.id,
                      enabled: !dl,
                      title: l.t('model_${m.id}'),
                      sub: l.t('model_${m.id}_d'),
                      size: '${(m.totalBytes / 1048576).round()} MB',
                      onTap: () => setState(() => _pick = m.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                  if (dl) ...[
                    Row(children: [
                      Text(l.t('downloading'), style: ts(13.5, c: C.dim)),
                      const Spacer(),
                      Text('${(s.dlProgress * 100).round()}%', style: ts(14, w: FontWeight.w700, c: C.cyan)),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: s.dlProgress, minHeight: 9, color: C.violet, backgroundColor: C.edge(0.08)),
                    ),
                  ] else
                    GradButton(
                      label: s.error != null ? l.t('retry') : l.t('download_start'),
                      icon: Icons.rocket_launch_rounded,
                      onTap: () => s.downloadModel(WhisperModel.byId(_pick)),
                    ),
                  if (s.error != null) ...[
                    const SizedBox(height: 14),
                    Text(s.error!, textAlign: TextAlign.center, style: ts(12.5, c: C.red)),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _noop() {}

class _Pick extends StatelessWidget {
  const _Pick({
    required this.selected,
    required this.enabled,
    required this.title,
    required this.sub,
    required this.size,
    required this.onTap,
  });
  final bool selected, enabled;
  final String title, sub, size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? C.violet.withValues(alpha: 0.16) : C.glass(0.04),
            border: Border.all(color: selected ? C.violet : C.edge(), width: selected ? 1.5 : 1),
          ),
          child: Row(children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22, color: selected ? C.violet : C.faint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: ts(15, w: FontWeight.w600)),
                Text(sub, style: ts(12.5, c: C.dim)),
              ]),
            ),
            Text(size, style: ts(12.5, c: C.faint)),
          ]),
        ),
      ),
    );
  }
}
