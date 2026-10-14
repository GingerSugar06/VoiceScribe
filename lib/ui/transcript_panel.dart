import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import '../engine/export.dart';
import '../l10n.dart';
import 'fx.dart';

class TranscriptPanel extends StatefulWidget {
  const TranscriptPanel({
    super.key,
    required this.l,
    required this.segments,
    required this.emptyText,
    this.listening = false,
    this.speaking = false,
    this.onClear,
    this.baseName = 'transkript',
    this.title,
  });
  final L l;
  final List<Segment> segments;
  final String emptyText;
  final bool listening; // canlı akış açık
  final bool speaking;
  final VoidCallback? onClear;
  final String baseName;
  final String? title;

  @override
  State<TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends State<TranscriptPanel> {
  final _scroll = ScrollController();
  bool _stamps = true;
  int _lastCount = 0;
  String? _toast;

  @override
  void didUpdateWidget(covariant TranscriptPanel old) {
    super.didUpdateWidget(old);
    if (widget.segments.length != _lastCount) {
      _lastCount = widget.segments.length;
      if (widget.listening) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(_scroll.position.maxScrollExtent + 80,
                duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _flash(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _toast == msg) setState(() => _toast = null);
    });
  }

  Future<void> _save(String ext, String content) async {
    final r = await FilePicker.saveFile(
      fileName: '${widget.baseName}.$ext',
      bytes: Uint8List.fromList(utf8.encode(content)),
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (r != null && mounted) _flash(widget.l.t('saved'));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final segs = widget.segments;
    final has = segs.isNotEmpty;
    return Glass(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Column(
            children: [
              // başlık çubuğu
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.listening ? C.red : C.cyan,
                        boxShadow: [BoxShadow(color: (widget.listening ? C.red : C.cyan).withValues(alpha: 0.7), blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(widget.title ?? l.t('transcript'),
                          overflow: TextOverflow.ellipsis, style: ts(15, w: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    if (has)
                      Text('${wordCount(segs)} ${l.t('words')}', style: ts(12.5, c: C.dim)),
                    const Spacer(),
                    Tooltip(
                      message: l.t('timestamps'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _stamps = !_stamps),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.schedule_rounded, size: 19, color: _stamps ? C.cyan : C.faint),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GhostButton(
                      label: l.t('copy'),
                      icon: Icons.copy_rounded,
                      onTap: has
                          ? () {
                              Clipboard.setData(ClipboardData(text: toPlain(segs, stamps: _stamps)));
                              _flash(l.t('copied'));
                            }
                          : null,
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      label: 'TXT',
                      icon: Icons.download_rounded,
                      onTap: has ? () => _save('txt', toPlain(segs, stamps: _stamps)) : null,
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      label: 'SRT',
                      icon: Icons.subtitles_rounded,
                      onTap: has ? () => _save('srt', toSrt(segs)) : null,
                    ),
                    if (widget.onClear != null) ...[
                      const SizedBox(width: 8),
                      GhostButton(label: l.t('clear'), icon: Icons.close_rounded, onTap: has ? widget.onClear : null),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: C.edge(0.07)),
              Expanded(
                child: !has && !widget.listening
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(widget.emptyText,
                              textAlign: TextAlign.center, style: ts(14.5, c: C.faint)),
                        ),
                      )
                    : SelectionArea(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                          itemCount: segs.length + (widget.listening ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == segs.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6, left: 2),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const TypingDots(),
                                    const SizedBox(width: 10),
                                    Text(widget.speaking ? l.t('speaking') : l.t('listening'),
                                        style: ts(12.5, c: widget.speaking ? C.cyan : C.faint)),
                                  ]),
                                ),
                              );
                            }
                            return _SegRow(key: ValueKey(i), seg: segs[i], stamp: _stamps);
                          },
                        ),
                      ),
              ),
            ],
          ),
          // toast
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedSlide(
                offset: _toast == null ? const Offset(0, 1.5) : Offset.zero,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _toast == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.green.withValues(alpha: 0.5)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_rounded, size: 17, color: C.green),
                        const SizedBox(width: 8),
                        Text(_toast ?? '', style: ts(13)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegRow extends StatelessWidget {
  const _SegRow({super.key, required this.seg, required this.stamp});
  final Segment seg;
  final bool stamp;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stamp)
              Container(
                margin: const EdgeInsets.only(right: 14, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: C.violet.withValues(alpha: 0.18),
                ),
                child: Text(clock(seg.start),
                    style: ts(11.5, c: const Color(0xFFB9A6FF), w: FontWeight.w600)
                        .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            Expanded(child: Text(seg.text, style: ts(15.5, h: 1.5))),
          ],
        ),
      ),
    );
  }
}
