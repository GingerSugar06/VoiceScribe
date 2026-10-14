import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'state/app_state.dart';
import 'ui/fx.dart';
import 'ui/pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const opts = WindowOptions(
    size: Size(1180, 780),
    minimumSize: Size(900, 640),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
    title: 'Voice Scribe',
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const VoiceScribeApp());
}

class VoiceScribeApp extends StatelessWidget {
  const VoiceScribeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Scribe',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        fontFamily: kFont,
        fontFamilyFallback: kFontFallback,
        colorScheme: const ColorScheme.dark(primary: C.violet, secondary: C.cyan),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(color: const Color(0xFF1B1B2E), borderRadius: BorderRadius.circular(8)),
          textStyle: ts(12),
        ),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final s = AppState();

  @override
  void initState() {
    super.initState();
    s.boot();
  }

  @override
  void dispose() {
    s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final l = s.l;
        final ready = s.phase == Phase.ready;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: Aurora(energy: s.recording ? s.level : 0)),
              Column(
                children: [
                  _TitleBar(s: s),
                  Expanded(
                    child: ready
                        ? Row(
                            children: [
                              _Rail(s: s),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 4, 28, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _Header(s: s),
                                      const SizedBox(height: 14),
                                      Expanded(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 320),
                                          switchInCurve: Curves.easeOutCubic,
                                          transitionBuilder: (c, a) => FadeTransition(
                                            opacity: a,
                                            child: SlideTransition(
                                              position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
                                              child: c,
                                            ),
                                          ),
                                          child: KeyedSubtree(key: ValueKey(s.tab), child: _page()),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Padding(padding: const EdgeInsets.all(28), child: SetupView(s: s)),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: IgnorePointer(
                  child: Center(child: Text(l.t('privacy'), style: ts(11, c: C.faint))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _page() => switch (s.tab) {
        0 => RecordPage(s: s),
        1 => FilePage(s: s),
        2 => HistoryPage(s: s),
        _ => SettingsPage(s: s),
      };
}

// ---------------------------------------------------------------------------

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final win = Platform.isWindows;
    return SizedBox(
      height: 44,
      child: Row(children: [
        Expanded(
          child: DragToMoveArea(
            child: Padding(
              padding: EdgeInsets.only(left: win ? 18 : 84),
              child: Row(children: [
                const _Logo(size: 22),
                const SizedBox(width: 10),
                Text(s.l.t('app'), style: ts(14, w: FontWeight.w700, ls: 0.3)),
              ]),
            ),
          ),
        ),
        if (win) ...[
          _WinBtn(Icons.remove_rounded, () => windowManager.minimize()),
          _WinBtn(Icons.crop_square_rounded, () async {
            (await windowManager.isMaximized()) ? windowManager.unmaximize() : windowManager.maximize();
          }),
          _WinBtn(Icons.close_rounded, () => windowManager.close(), danger: true),
        ],
      ]),
    );
  }
}

class _WinBtn extends StatefulWidget {
  const _WinBtn(this.icon, this.onTap, {this.danger = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => h = true),
        onExit: (_) => setState(() => h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 48,
            height: 44,
            color: h ? (widget.danger ? const Color(0xFFE5484D) : C.glass(0.1)) : Colors.transparent,
            child: Icon(widget.icon, size: 17, color: C.text),
          ),
        ),
      );
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.32),
          gradient: const LinearGradient(colors: [C.violet, C.pink], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: C.violet.withValues(alpha: 0.5), blurRadius: 12)],
        ),
        child: Icon(Icons.graphic_eq_rounded, size: size * 0.66, color: Colors.white),
      );
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final l = s.l;
    final locked = s.recording || s.fileBusy;
    final titles = [l.t('nav_record'), l.t('nav_file'), l.t('nav_history'), l.t('nav_settings')];
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titles[s.tab], style: ts(28, w: FontWeight.w700, ls: -0.5)),
          const SizedBox(height: 2),
          Text(l.t('tagline'), style: ts(13.5, c: C.dim)),
        ]),
      ),
      Opacity(
        opacity: locked ? 0.5 : 1,
        child: IgnorePointer(
          ignoring: locked,
          child: Row(children: [
            Text('${l.t('speech_lang')}  ', style: ts(12.5, c: C.dim)),
            SegmentedPills<String>(
              items: [('tr', l.t('lang_tr')), ('en', l.t('lang_en')), ('auto', l.t('lang_auto'))],
              value: s.speechLang,
              onChanged: s.setSpeechLang,
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------

class _Rail extends StatelessWidget {
  const _Rail({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final l = s.l;
    final items = [
      (Icons.mic_rounded, l.t('nav_record')),
      (Icons.audio_file_rounded, l.t('nav_file')),
      (Icons.history_rounded, l.t('nav_history')),
      (Icons.tune_rounded, l.t('nav_settings')),
    ];
    return Container(
      width: 92,
      margin: const EdgeInsets.fromLTRB(20, 4, 12, 28),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: C.glass(0.045),
        border: Border.all(color: C.edge()),
      ),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) _RailItem(icon: items[i].$1, label: items[i].$2, selected: s.tab == i, onTap: () => s.setTab(i)),
        const Spacer(),
        // arayüz dili
        GestureDetector(
          onTap: () => s.setUiLang(s.uiLang == 'tr' ? 'en' : 'tr'),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: s.l.t('ui_lang'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.edge(0.18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.language_rounded, size: 15, color: C.cyan),
                  const SizedBox(width: 5),
                  Text(s.uiLang.toUpperCase(), style: ts(12, w: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool h = false;
  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => h = true),
      onExit: (_) => setState(() => h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 72,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: sel ? const LinearGradient(colors: [C.violet, Color(0xFF9B6BFF)]) : null,
            color: !sel && h ? C.glass(0.08) : null,
            boxShadow: sel ? [BoxShadow(color: C.violet.withValues(alpha: 0.45), blurRadius: 18)] : null,
          ),
          child: Column(children: [
            AnimatedScale(
              scale: sel ? 1.12 : 1,
              duration: const Duration(milliseconds: 260),
              child: Icon(widget.icon, size: 24, color: sel ? Colors.white : (h ? C.text : C.dim)),
            ),
            const SizedBox(height: 4),
            Text(widget.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(10.5, w: sel ? FontWeight.w600 : FontWeight.w500, c: sel ? Colors.white : C.dim)),
          ]),
        ),
      ),
    );
  }
}
