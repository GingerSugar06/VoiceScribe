import 'dart:math' as math;

import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF07070F);
  static const violet = Color(0xFF7C5CFF);
  static const cyan = Color(0xFF22D3EE);
  static const pink = Color(0xFFF472B6);
  static const amber = Color(0xFFFBBF24);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFFB7185);
  static const text = Color(0xFFF1F1F8);
  static const dim = Color(0xFF9A9AB5);
  static const faint = Color(0xFF5D5D78);
  static Color glass([double a = 0.055]) => Colors.white.withValues(alpha: a);
  static Color edge([double a = 0.09]) => Colors.white.withValues(alpha: a);
}

const kFont = 'Segoe UI Variable Text';
const kFontFallback = ['Segoe UI', 'SF Pro Text', 'Helvetica Neue', 'Roboto', 'Arial'];

TextStyle ts(double size, {FontWeight w = FontWeight.w400, Color c = C.text, double? h, double? ls}) =>
    TextStyle(
      fontFamily: kFont,
      fontFamilyFallback: kFontFallback,
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
      letterSpacing: ls,
    );

// ---------------------------------------------------------------------------
// Aurora arka plan
// ---------------------------------------------------------------------------

class Aurora extends StatefulWidget {
  const Aurora({super.key, required this.energy});

  /// 0..1 — canlı ses seviyesi, parıltıyı büyütür.
  final double energy;

  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _AuroraPainter(_c.value, widget.energy),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.e);
  final double t;
  final double e;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = C.bg);
    final w = s.width, h = s.height;
    final a = t * 2 * math.pi;
    void blob(double fx, double fy, double ph, Color col, double rad, double alpha) {
      final c = Offset(
        w * (0.5 + 0.42 * math.sin(a * fx + ph)),
        h * (0.5 + 0.40 * math.cos(a * fy + ph * 1.3)),
      );
      final r = rad * (1 + e * 0.35);
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          col.withValues(alpha: alpha + e * 0.10),
          col.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }

    final base = math.max(w, h);
    blob(1, 1, 0.0, C.violet, base * 0.55, 0.30);
    blob(2, 1, 2.1, C.cyan, base * 0.42, 0.20);
    blob(1, 3, 4.0, C.pink, base * 0.40, 0.17);
    blob(3, 2, 5.3, C.violet, base * 0.32, 0.14);

    // hafif vinyet
    final vg = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [Colors.transparent, C.bg.withValues(alpha: 0.65)],
      ).createShader(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, vg);
  }

  @override
  bool shouldRepaint(_AuroraPainter o) => o.t != t || o.e != e;
}

// ---------------------------------------------------------------------------
// Cam kart
// ---------------------------------------------------------------------------

class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 24, this.glow});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.085), Colors.white.withValues(alpha: 0.03)],
        ),
        border: Border.all(color: C.edge()),
        boxShadow: [
          BoxShadow(color: (glow ?? Colors.black).withValues(alpha: glow == null ? 0.35 : 0.22), blurRadius: 40, offset: const Offset(0, 18)),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Mikrofon küresi
// ---------------------------------------------------------------------------

class MicOrb extends StatefulWidget {
  const MicOrb({
    super.key,
    required this.level,
    required this.active,
    required this.speaking,
    required this.busy,
    required this.onTap,
    this.size = 210,
  });
  final double level;
  final bool active;
  final bool speaking;
  final bool busy;
  final VoidCallback onTap;
  final double size;

  @override
  State<MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<MicOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  bool _hover = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.size;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: SizedBox(
          width: sz * 1.9,
          height: sz * 1.9,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.level),
            duration: const Duration(milliseconds: 120),
            builder: (_, lv, __) => AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(
                painter: _OrbPainter(
                  t: _c.value,
                  level: lv,
                  active: widget.active,
                  speaking: widget.speaking,
                  hover: _hover,
                  busy: widget.busy,
                  r: sz / 2,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                    child: widget.busy
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : Icon(
                            widget.active ? Icons.stop_rounded : Icons.mic_rounded,
                            key: ValueKey(widget.active),
                            size: sz * 0.30,
                            color: Colors.white,
                            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 16)],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.t,
    required this.level,
    required this.active,
    required this.speaking,
    required this.hover,
    required this.busy,
    required this.r,
  });
  final double t, level, r;
  final bool active, speaking, hover, busy;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final breathe = 1 + 0.025 * math.sin(t * 2 * math.pi * 1.0);
    final boost = active ? level * 0.22 : 0.0;
    final hov = hover && !active ? 1.04 : 1.0;
    final R = r * breathe * (1 + boost) * hov;

    // dış parıltı
    final glowA = active ? 0.30 + level * 0.45 : 0.20;
    canvas.drawCircle(
      c,
      R * 2.35,
      Paint()
        ..shader = RadialGradient(colors: [
          (active ? C.pink : C.violet).withValues(alpha: glowA),
          C.violet.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: R * 2.35)),
    );

    // dalga halkaları
    for (var i = 0; i < 3; i++) {
      final ph = (t * (active ? 3 : 1) + i / 3) % 1.0;
      final rad = R * (1.05 + ph * (active ? 0.75 + level * 0.5 : 0.5));
      final a = (1 - ph) * (active ? 0.42 : 0.12);
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = (active ? C.cyan : C.violet).withValues(alpha: a),
      );
    }

    // dönen renkli halka
    final ring = Rect.fromCircle(center: c, radius: R * 1.08);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 2 * math.pi * (active ? 1.0 : 0.3));
    canvas.translate(-c.dx, -c.dy);
    canvas.drawCircle(
      c,
      R * 1.08,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3.5 : 2
        ..shader = SweepGradient(colors: [
          C.violet.withValues(alpha: 0),
          C.violet,
          C.cyan,
          C.pink,
          C.violet.withValues(alpha: 0),
        ], stops: const [0, 0.25, 0.5, 0.75, 1]).createShader(ring),
    );
    canvas.restore();

    // çekirdek küre
    final core = Rect.fromCircle(center: c, radius: R);
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: active
              ? [const Color(0xFFFFA5D2), C.pink, const Color(0xFF6D3BFF)]
              : [const Color(0xFFB9A6FF), C.violet, const Color(0xFF3B1FB8)],
          stops: const [0, 0.45, 1],
        ).createShader(core),
    );
    // iç sıvı hareketi
    canvas.save();
    canvas.clipPath(Path()..addOval(core));
    final liquid = Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(-t * 2 * math.pi),
        colors: [
          C.cyan.withValues(alpha: 0.0),
          C.cyan.withValues(alpha: speaking ? 0.55 : 0.28),
          C.cyan.withValues(alpha: 0.0),
        ],
      ).createShader(core);
    canvas.drawCircle(c, R, liquid);
    canvas.restore();
    // parlak vurgu
    canvas.drawCircle(
      c.translate(-R * 0.35, -R * 0.45),
      R * 0.42,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c.translate(-R * 0.35, -R * 0.45), radius: R * 0.42)),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter o) => true;
}

// ---------------------------------------------------------------------------
// Dalga çubukları
// ---------------------------------------------------------------------------

class Waveform extends StatefulWidget {
  const Waveform({super.key, required this.levels, required this.active, this.height = 64});
  final List<double> levels;
  final bool active;
  final double height;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _WavePainter(widget.levels, widget.active, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.levels, this.active, this.t);
  final List<double> levels;
  final bool active;
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final n = levels.length;
    final gap = 4.0;
    final bw = (s.width - gap * (n - 1)) / n;
    final shader = const LinearGradient(colors: [C.violet, C.cyan, C.pink]).createShader(Offset.zero & s);
    final paint = Paint()..shader = shader;
    for (var i = 0; i < n; i++) {
      final idle = 0.06 + 0.05 * (math.sin(t * 2 * math.pi + i * 0.45) + 1) / 2;
      final v = active ? math.max(levels[i], 0.04) : idle;
      // kenarlara doğru söndür
      final edge = math.sin(math.pi * (i + 0.5) / n);
      final hh = math.max(4.0, s.height * v * (0.35 + 0.65 * edge));
      final x = i * (bw + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x + bw / 2, s.height / 2), width: bw, height: hh), Radius.circular(bw / 2)),
        paint..color = Colors.white.withValues(alpha: active ? 1 : 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) => true;
}

// ---------------------------------------------------------------------------
// Küçük yardımcı bileşenler
// ---------------------------------------------------------------------------

/// Yazıyor… noktaları
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color = C.cyan});
  final Color color;
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final v = math.max(0.0, math.sin((_c.value * 2 - i * 0.28) * math.pi));
          return Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.35 + 0.65 * v),
            ),
            transform: Matrix4.translationValues(0, -4 * v, 0),
          );
        }),
      ),
    );
  }
}

/// Gradyanlı birincil buton
class GradButton extends StatefulWidget {
  const GradButton({super.key, required this.label, required this.onTap, this.icon, this.colors});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final List<Color>? colors;

  @override
  State<GradButton> createState() => _GradButtonState();
}

class _GradButtonState extends State<GradButton> {
  bool _h = false, _d = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final cols = widget.colors ?? const [C.violet, C.pink];
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _d = true),
        onTapCancel: () => setState(() => _d = false),
        onTapUp: (_) => setState(() => _d = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _d ? 0.96 : (_h && enabled ? 1.03 : 1),
          duration: const Duration(milliseconds: 140),
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: cols),
                boxShadow: [BoxShadow(color: cols.first.withValues(alpha: _h ? 0.55 : 0.35), blurRadius: _h ? 28 : 18, offset: const Offset(0, 8))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (widget.icon != null) ...[Icon(widget.icon, size: 19, color: Colors.white), const SizedBox(width: 9)],
                Text(widget.label, style: ts(14.5, w: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cam görünümlü ikincil buton
class GhostButton extends StatefulWidget {
  const GhostButton({super.key, required this.label, required this.onTap, this.icon, this.color});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: C.glass(_h && enabled ? 0.14 : 0.06),
            border: Border.all(color: C.edge(_h && enabled ? 0.22 : 0.1)),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 16, color: widget.color ?? C.text), const SizedBox(width: 7)],
              Text(widget.label, style: ts(13, w: FontWeight.w500, c: widget.color ?? C.text)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Seçilebilir hap (dil seçici vb.)
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: C.glass(0.05),
        border: Border.all(color: C.edge()),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (v, label) in items)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: v == value ? const LinearGradient(colors: [C.violet, Color(0xFF9B6BFF)]) : null,
                  boxShadow: v == value ? [BoxShadow(color: C.violet.withValues(alpha: 0.4), blurRadius: 14)] : null,
                ),
                child: Text(label, style: ts(13, w: v == value ? FontWeight.w600 : FontWeight.w500, c: v == value ? Colors.white : C.dim)),
              ),
            ),
          ),
      ]),
    );
  }
}
