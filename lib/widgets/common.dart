import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../utils/decimal_input_formatter.dart';
import '../utils/step_clamp.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_export.dart';

// ── Theme-dependent color tokens ────────────────────────────────────────────
// Getters instead of const: read ThemeNotifier.instance.isDark live, so all
// existing call sites (color: kCardColor, color: kBg, ...) become theme-aware
// without any syntax change - a rebuild is already triggered via the
// AnimatedBuilder in main.dart, which listens to ThemeNotifier.
//
// kGold deliberately stays a REAL constant: the accent color should stay
// identical in both themes (brand recognition).
const kGold = Color(0xFFFFA500);

Color get kCardColor => ThemeNotifier.instance.isDark ? const Color(0xFF1C1C1C) : const Color(0xFFFFFFFF);
Color get kBg        => ThemeNotifier.instance.isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F1F1);
Color get kBtnGrey   => ThemeNotifier.instance.isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE2E2E2); // +/- button background
Color get kLetterbox => ThemeNotifier.instance.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE4E4E4); // side panels on wide screens

// Text/divider tokens: replace the previously directly-used Colors.white*
// values, which were only readable in the dark theme. The gradation (fully
// opaque -> highly transparent) is preserved, only the base color switches
// between white (dark) and black-anthracite (light).
Color get kText          => ThemeNotifier.instance.isDark ? Colors.white   : const Color(0xFF1A1A1A);
Color get kTextSecondary => ThemeNotifier.instance.isDark ? Colors.white70 : const Color(0xFF454545);
Color get kTextTertiary  => ThemeNotifier.instance.isDark ? Colors.white60 : const Color(0xFF5C5C5C);
Color get kTextMuted     => ThemeNotifier.instance.isDark ? Colors.white54 : const Color(0xFF6E6E6E);
Color get kTextFaint     => ThemeNotifier.instance.isDark ? Colors.white38 : const Color(0xFF8A8A8A);
Color get kTextGhost2    => ThemeNotifier.instance.isDark ? Colors.white30 : const Color(0xFF9E9E9E);
Color get kTextGhost     => ThemeNotifier.instance.isDark ? Colors.white24 : const Color(0xFFB0B0B0);
Color get kDivider       => ThemeNotifier.instance.isDark ? Colors.white12 : const Color(0xFFDDDDDD);
Color get kSurfaceWash   => ThemeNotifier.instance.isDark ? Colors.white10 : const Color(0xFFE7E7E7);
Color get kLink          => ThemeNotifier.instance.isDark ? const Color(0xFF60A0E0) : const Color(0xFF1D5C99); // DOI-Links

// Table chrome (header/row-stripe background), previously duplicated as
// magic hex values in almost every tab screen.
Color get kTableHeaderBg => ThemeNotifier.instance.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEDEDED);
Color get kRowStripeA    => ThemeNotifier.instance.isDark ? const Color(0xFF222222) : const Color(0xFFFAFAFA);
Color get kRowStripeB    => ThemeNotifier.instance.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0);

/// Formats a number for a text field: at most two decimals, trailing zeros
/// stripped ("70", not "70.00"). Existed three times in nearly identical
/// form (here, bsa_screen, o2_delivery_screen) - one behaviour, one place.
/// null yields an empty string so it can back an empty field directly.
String formatFieldNumber(double? v) {
  if (v == null) return '';
  final s = v.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// Tooltip text shown next to an out-of-range value.
///
/// Shared by [InputCard] and by custom inputs that do their own range
/// checking (e.g. the CO/CI card on the O2 tab), so the wording stays
/// identical everywhere. Previously this lived inside InputCard with
/// hard-coded German strings, which meant the tooltip stayed German even
/// with the app set to English - it now goes through t().
String warnTooltipFor(Range r) {
  final base = '${t('plausibility_warning')}\n${t('plausibility_plausible')}: ${r.display}';
  final key = r.noteKey;
  return key == null ? base : '$base\n${t(key)}';
}

class InputCard extends StatefulWidget {
  final String label;
  final String unit;
  final double? value;
  final ValueChanged<double?> onChanged;
  final double step;

  /// Optional plausible value range. If set and the value is outside this
  /// range, the field gets an orange border and a warning icon next to the
  /// label (gentle warning - the calculation still proceeds normally
  /// regardless).
  final Range? range;

  /// Optional inline unit switcher. When both are supplied, the static unit
  /// label in the card's top-right corner is replaced by a small tappable
  /// chip row (one chip per entry in [unitOptions]); [unit] then selects
  /// which chip is highlighted. Used e.g. for mmol/ml vs % concentration
  /// entry, where the switch belongs visually inside the field it governs
  /// rather than floating beside it.
  final List<String>? unitOptions;
  final ValueChanged<String>? onUnitChanged;

  const InputCard({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
    this.step = 0.1,
    this.range,
    this.unitOptions,
    this.onUnitChanged,
  });

  @override
  State<InputCard> createState() => _InputCardState();
}

class _InputCardState extends State<InputCard> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: formatFieldNumber(widget.value));
  }

  @override
  void didUpdateWidget(InputCard old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      final newText = formatFieldNumber(widget.value);
      if (_ctrl.text != newText) {
        _ctrl.text = newText;
        _ctrl.selection = TextSelection.collapsed(offset: newText.length);
      }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  /// Safely parse a numeric string input. Returns null for invalid/extreme values.
  /// Rejects NaN, Infinity, and values outside a sensible clinical range (±1e6).
  /// This protects all downstream calculations from overflow and malformed input.
  double? _safeParse(String s) {
    if (s.isEmpty) return null;
    final v = double.tryParse(s.replaceAll(',', '.'));
    if (v == null) return null;
    if (v.isNaN || v.isInfinite) return null;
    // Clinical values are always within ±1e6; anything beyond is certainly bogus.
    if (v.abs() > 1e6) return null;
    return v;
  }

  /// Thin wrapper - the logic lives in utils/step_clamp.dart so it can be
  /// unit tested (audit R-3); the reasoning is documented there.
  double _clampStep(double v) =>
      clampStep(v, widget.range, fromEmpty: widget.value == null);

  void _increment() {
    final v = double.parse(((widget.value ?? 0) + widget.step).toStringAsFixed(4));
    widget.onChanged(_clampStep(v));
  }

  void _decrement() {
    final v = double.parse(((widget.value ?? 0) - widget.step).toStringAsFixed(4));
    widget.onChanged(_clampStep(v));
  }

  @override
  Widget build(BuildContext context) {
    // Check whether the current value is within the plausible range.
    // null (no value entered) counts as "OK" - no warning shown.
    final bool outOfRange =
        widget.range != null && !widget.range!.contains(widget.value);

    // Orange accent color for the warning state, otherwise the standard dark card.
    const warnColor = Color(0xFFFFA726); // material orange 400

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(8),
        // Warning border: only when outOfRange. Otherwise a transparent
        // border, so the layout doesn't shift between "ok" and "warn".
        border: Border.all(
          color: outOfRange ? warnColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Label + optional warning icon on the left, unit (or unit
          // switcher) on the right. The label side is Expanded and its Text
          // is Flexible so a long label wraps onto a second line instead of
          // pushing the unit/switcher out of the visible area - that used
          // to cut off both the "%"/"mmol/ml" switch and long field titles.
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Flexible(
                  child: Text(widget.label, style: TextStyle(color: kText, fontSize: 14)),
                ),
                if (outOfRange) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: warnTooltipFor(widget.range!),
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 4),
                    child: Semantics(
                      label: '${t('a11y_warning')}: ${warnTooltipFor(widget.range!)}',
                      excludeSemantics: true,
                      child: const Icon(Icons.warning_amber_rounded,
                          color: warnColor, size: 16),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            if (widget.unitOptions != null && widget.onUnitChanged != null)
              _unitSwitcher()
            else
              Text(widget.unit,  style:  TextStyle(color: kTextSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _btn(Icons.remove, _decrement, '${t('a11y_decrease')}: ${widget.label}'),
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: outOfRange ? warnColor : kTextSecondary,
                  fontSize: 22,
                ),
                // Input validation: max 10 chars, only digits/decimals/minus
                maxLength: 10,
                inputFormatters: const [
                  // NICHT FilteringTextInputFormatter.allow mit einer auf ^…$
                  // verankerten Regex - das leert bei einem Fehltipp das
                  // ganze Feld. Begruendung und Testfaelle in
                  // utils/decimal_input_formatter.dart.
                  DecimalTextInputFormatter(),
                ],
                decoration: InputDecoration(
                  counterText: '', // hide the "x/10" counter
                  border: InputBorder.none,
                  hintText: t('enter_value'),
                  hintStyle:  TextStyle(color: kTextGhost2, fontSize: 18),
                ),
                onTap: () => setState(() => _editing = true),
                onChanged: (s) => widget.onChanged(_safeParse(s)),
                onEditingComplete: () { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
                onTapOutside: (_) { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
              ),
            ),
            _btn(Icons.add, _increment, '${t('a11y_increase')}: ${widget.label}'),
          ]),
        ]),
      ),
    );
  }

  /// Small inline chip row that replaces the static unit label when
  /// [InputCard.unitOptions] is supplied - lets the user switch the entry
  /// unit right inside the field it belongs to.
  Widget _unitSwitcher() {
    final opts = widget.unitOptions!;
    final chips = <Widget>[];
    for (final opt in opts) {
      final active = opt == widget.unit;
      chips.add(Semantics(
        button: true,
        selected: active,
        label: opt,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => widget.onUnitChanged!(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: active ? kGold : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(opt, style: TextStyle(
              color: active ? Colors.black : kTextMuted,
              fontSize: 11.5,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            )),
          ),
        ),
      ));
    }
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: chips),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, String semanticLabel) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration:  BoxDecoration(color: kBtnGrey, shape: BoxShape.circle),
        child: Icon(icon, color: kText, size: 20),
      ),
    ),
  );
}

class ResultCard extends StatelessWidget {
  final String label;
  final String unit;
  final double value;
  final String? rangeHint;
  final int decimals;

  /// List of missing inputs (already translated). If non-empty: instead of
  /// a numeric value, "—" is shown, with a note below listing which inputs
  /// are still outstanding. Prevents formulas left blank from being
  /// misread as "0.00".
  final List<String> missingInputs;

  /// Clinical warning threshold (not a plausibility check like
  /// InputCard/Range — this is about the clinical relevance of an
  /// otherwise plausible result, e.g. DO₂i < 272 ml/min/m² as the
  /// Goal-Directed-Perfusion threshold for increased AKI risk). If set and
  /// value < warnBelow: orange border + warning icon, same look as the
  /// plausibility warning border on input fields.
  final double? warnBelow;

  /// Tooltip text shown when below [warnBelow]. Required as soon as
  /// [warnBelow] is set, so the warning is clinically justified.
  final String? warnMessage;

  const ResultCard({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    this.rangeHint,
    this.decimals = 2,
    this.missingInputs = const [],
    this.warnBelow,
    this.warnMessage,
  });

  @override
  Widget build(BuildContext context) {
    final hasMissing = missingInputs.isNotEmpty;
    // Orange accent color for the warning state - same tone as InputCard's
    // plausibility warning border, so "attention" looks consistent across
    // the whole screen, even though the meaning here is different.
    const warnColor = Color(0xFFFFA726);
    final belowThreshold = warnBelow != null && !hasMissing && value < warnBelow!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(8),
        // Warning border: only when below the threshold. Otherwise a
        // transparent border, so the layout doesn't shift.
        border: Border.all(
          color: belowThreshold ? warnColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(label, style:  TextStyle(color: kText, fontSize: 14))),
                if (belowThreshold) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: warnMessage ?? t('result_below_threshold'),
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 4),
                    child: Semantics(
                      label: '${t('a11y_warning')}: ${warnMessage ?? t('result_below_threshold')}',
                      excludeSemantics: true,
                      child: const Icon(Icons.warning_amber_rounded,
                          color: warnColor, size: 16),
                    ),
                  ),
                ],
              ]),
              if (rangeHint != null && !hasMissing)
                Text(rangeHint!, style:  TextStyle(color: kTextMuted, fontSize: 11)),
              if (hasMissing) ...[
                const SizedBox(height: 2),
                Text(
                  '${t('missing_inputs_hint')}${missingInputs.join(', ')}',
                  style:  TextStyle(color: kTextFaint, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(unit,  style: TextStyle(color: hasMissing ? kTextGhost : kTextSecondary, fontSize: 12)),
              Text(
                hasMissing ? '—' : value.toStringAsFixed(decimals),
                style: TextStyle(
                  color: hasMissing ? kTextFaint : (belowThreshold ? warnColor : kGold),
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
    child: Text(title,
        style:  TextStyle(color: kTextMuted, fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class DataTable2 extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final String? title;
  final bool titleIsGold;

  const DataTable2({super.key, required this.headers, required this.rows, this.title, this.titleIsGold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(title!,
                style: TextStyle(color: titleIsGold ? kGold : kText,
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        Table(
          border: TableBorder(horizontalInside: BorderSide(color: kDivider)),
          columnWidths: {for (int i = 0; i < headers.length; i++) i: const FlexColumnWidth()},
          children: [
            TableRow(
              decoration: BoxDecoration(color: kSurfaceWash),
              children: headers.map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(h, style:  TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 13)),
              )).toList(),
            ),
            ...rows.map((row) => TableRow(children: row.map((cell) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(cell, style:  TextStyle(color: kText, fontSize: 13)),
            )).toList())),
          ],
        ),
      ]),
    );
  }
}

class GoldListCard extends StatelessWidget {
  final List<String> items;
  const GoldListCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
        child: Text(item, style: const TextStyle(color: kGold, fontSize: 15)),
      )).toList(),
    );
  }
}

// ── Browser-safe image loading ───────────────────────────────────────────────
//
// Problem: Flutter Web renders ALL images via CanvasKit (WebGL) by default.
// This also applies to Image.network - the bytes are loaded via fetch() and
// drawn in CanvasKit, NOT as a native <img> element. In browsers with strict
// defaults (privacy browsers, Firefox with fingerprinting protection, some
// Chromium forks), either the WASM image decoding or the CanvasKit pixel
// reading fails. Effect: the image doesn't appear, or shows as an empty
// white area (especially for SVGs).
//
// Solution: Flutter 3.27+ offers the `webHtmlElementStrategy` parameter on
// Image.network. When set to 'prefer', Flutter renders the image as a
// native <img> tag in the DOM via HtmlElementView. The browser then loads
// and renders it itself - independent of CanvasKit, independent of the
// renderer. Also works with SVGs, because browsers natively support SVGs
// inside <img>.
//
// Trade-offs (acceptable for our use case per the Flutter docs):
//   - Suboptimal performance (irrelevant for a handful of static images)
//   - No Image.toByteData / OffsetLayer.toImage (we don't use these)
//   - Some color/blend effects don't work (we don't use these)
//
// Prerequisite: the asset lives under assets/<filename> in pubspec.yaml.
// Flutter packages it in the web build under assets/assets/<filename>,
// which - thanks to <base href="/<app>/"> - is addressable as a relative
// path 'assets/assets/<filename>'.

class BrowserSafeImage extends StatelessWidget {
  final String assetPath;        // wie in pubspec deklariert, z.B. 'assets/finck_va.jpg'
  final BoxFit fit;
  final double? width;
  final double? height;

  const BrowserSafeImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Everything below this line only makes sense on web. On Android/iOS
    // 'assets/<path>' is a relative URL with no scheme, and the release
    // build has no INTERNET permission at all - so Image.network was
    // guaranteed to fail and fall through errorBuilder to Image.asset.
    // Every anatomy image was loaded twice, with an exception logged in
    // between.
    if (!kIsWeb) {
      return Image.asset(assetPath, fit: fit, width: width, height: height);
    }
    // Flutter packages assets in the web build under assets/assets/<file>.
    // A relative path respects the page's <base href>.
    final url = 'assets/$assetPath';
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      // CRITICAL: forces Flutter to use a native <img> tag in the DOM
      // instead of drawing the image via CanvasKit. Bytes are loaded by the
      // browser, not by Flutter. Fixes:
      //   - images invisible in privacy browsers
      //   - SVG appearing as a white area
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      // Loading indicator while the image loads
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          padding: const EdgeInsets.all(40),
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
            color: kGold,
            strokeWidth: 2,
          ),
        );
      },
      // Fallback on error: try Image.asset (e.g. for the mobile build,
      // where there is no HTTP asset hosting).
      errorBuilder: (context, error, stack) {
        return Image.asset(
          assetPath,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (c, e, s) => Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
               Icon(Icons.broken_image, color: kTextGhost, size: 48),
              const SizedBox(height: 8),
              Text('Image unavailable: $assetPath',
                  textAlign: TextAlign.center,
                  style:  TextStyle(color: kTextFaint, fontSize: 11)),
            ]),
          ),
        );
      },
    );
  }
}

class ImageSectionCard extends StatelessWidget {
  final String title;
  final String assetPath;

  const ImageSectionCard({super.key, required this.title, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Text(title,
              style: const TextStyle(color: kGold, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        Semantics(
          button: true,
          label: t('a11y_view_fullscreen'),
          child: GestureDetector(
            onTap: () => _showFullImage(context),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
              child: BrowserSafeImage(assetPath: assetPath, fit: BoxFit.fitWidth),
            ),
          ),
        ),
      ]),
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        // Stack layout: image fills the dialog and uses InteractiveViewer
        // for pinch-zoom; the close button floats on top. This keeps the
        // close button always reachable, even when the image is very tall
        // (e.g. the portrait-format Finck tables).
        child: Stack(children: [
          // Title at top
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(48, 12, 48, 12),
              color: Colors.black54,
              child: Text(title, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          // Zoomable image fills the entire dialog
          Padding(
            padding: const EdgeInsets.only(top: 48, bottom: 8),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(child: BrowserSafeImage(assetPath: assetPath, fit: BoxFit.contain)),
            ),
          ),
          // Close button — top right, always reachable
          Positioned(
            top: 8, right: 8,
            child: Semantics(
              button: true,
              label: t('a11y_close_fullscreen'),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── PDF Export button ─────────────────────────────────────────────────────────
//
// Reusable button at the end of a tab for exporting the current
// inputs/results as a PDF. On web, it triggers the browser download; on
// mobile you would use path_provider + share_plus (not implemented).
//
// The tab passes in a function that assembles the sections on demand -
// this way the most current values are always exported, not a snapshot
// from when the tab was built.
//
// Example:
//   PdfExportButton(
//     filename: 'bsa',
//     tabTitleKey: 'tab_bsa',
//     buildSections: () => [
//       PdfSection(title: t('pdf_inputs'), rows: [...]),
//       PdfSection(title: t('pdf_results'), rows: [...]),
//     ],
//   )

class PdfExportButton extends StatelessWidget {
  /// Filename stem, e.g. 'bsa' -> "perfusioncalc_bsa_20260425_1630.pdf"
  final String filename;

  /// i18n key for the tab title in the PDF header (e.g. 'tab_bsa').
  final String tabTitleKey;

  /// Callback for the current sections - only called on click, so the
  /// most recent values are always captured.
  final List<PdfSection> Function() buildSections;

  // ignore: prefer_const_constructors_in_immutables
  PdfExportButton({
    super.key,
    required this.filename,
    required this.tabTitleKey,
    required this.buildSections,
  });

  Future<void> _onPressed(BuildContext context) async {
    try {
      await exportTabAsPdf(
        tabTitle: t(tabTitleKey),
        filename: filename,
        sections: buildSections(),
      );
    } catch (e, stack) {
      // Log the error to the browser console so we can see the exact
      // reason if there are problems (instead of failing silently).
      debugPrint('[PdfExportButton] export failed: $e');
      debugPrint('$stack');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t('pdf_export_failed')}: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onPressed(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        width: double.infinity,
        decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(t('pdf_export_button'),
              style:  TextStyle(color: kText, fontSize: 15)),
          const SizedBox(width: 8),
          const Icon(Icons.picture_as_pdf, color: kGold, size: 20),
        ]),
      ),
    );
  }
}

// ── Source button + dialog ────────────────────────────────────────────────────
class SourceButton extends StatelessWidget {
  final List<SourceRef> refs;

  // Not const, because build() calls the global t() helper, which changes
  // on a language switch. With const, Flutter would cache the widget and
  // miss the language switch.
  // ignore: prefer_const_constructors_in_immutables
  SourceButton({super.key, required this.refs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        width: double.infinity,
        decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(t('source'), style:  TextStyle(color: kText, fontSize: 15)),
          const SizedBox(width: 8),
          const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
        ]),
      ),
    );
  }

  void _show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(t('sources'),
            style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: refs.map((r) => _refTile(r)).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('close'), style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _refTile(SourceRef r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2, right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: kGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('[${r.num}]',
              style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.authors,
                style:  TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(r.title,
                style:  TextStyle(color: kTextSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 2),
            Text(r.journal,
                style:  TextStyle(color: kTextMuted, fontSize: 11)),
            if (r.doi.isNotEmpty)
              Text(r.doi, style: TextStyle(color: kLink, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

class SourceRef {
  final int num;
  final String authors;
  final String title;
  final String journal;
  final String doi;

  const SourceRef({
    required this.num,
    required this.authors,
    required this.title,
    required this.journal,
    this.doi = '',
  });
}

// ── Pre-defined reference sets ────────────────────────────────────────────────
class AppSources {
  static const dubois = SourceRef(
    num: 1,
    authors: 'Du Bois D, Du Bois EF.',
    title: 'A formula to estimate the approximate surface area if height and weight be known.',
    journal: 'Archives of Internal Medicine. 1916;17(6):863–871.',
    doi: 'PMID: 2520314',
  );

  static const eactsKunst2024 = SourceRef(
    num: 2,
    authors: 'Kunst G, Gerber V, Milojevic M, et al; ESAIC Guidelines Task Force; EACTS, EACTAIC, EBCP Guidelines Committees.',
    title: '2024 EACTS/EACTAIC/EBCP Guidelines on cardiopulmonary bypass in adult cardiac surgery.',
    journal: 'British Journal of Anaesthesia. 2025;134(4):917–1008.',
    doi: 'doi: 10.1016/j.bja.2024.10.018  ·  Standardwert Cardiac Index 2,4 l/min/m² (adulte CPB).',
  );

  static const silbernagl = SourceRef(
    num: 3,
    authors: 'Silbernagl S, Despopoulos A.',
    title: 'Taschenatlas Physiologie. 9. Auflage.',
    journal: 'Stuttgart: Thieme; 2019. ISBN: 978-3-13-576909-8',
    doi: 'Vereinfachte Blutvolumen-Näherungsformel aus der klinischen Perfusionspraxis.',
  );

  static const nadler = SourceRef(
    num: 4,
    authors: 'Nadler SB, Hidalgo JH, Bloch T.',
    title: 'Prediction of blood volume in normal human adults.',
    journal: 'Surgery. 1962;51(2):224–232.',
    doi: 'PMID: 21272930',
  );

  static const ranucci2005 = SourceRef(
    num: 5,
    authors: 'Ranucci M, Romitti F, Isgro G, et al.',
    title: 'Oxygen delivery during cardiopulmonary bypass and acute renal failure after coronary operations.',
    journal: 'Annals of Thoracic Surgery. 2005;80(6):2213–2220.',
    doi: 'doi: 10.1016/j.athoracsur.2005.05.069 · PMID: 16305875',
  );

  static const deSomer = SourceRef(
    num: 6,
    authors: 'de Somer F, Mulholland JW, Bryan MR, Aloisio T, Van Nooten GJ, Ranucci M.',
    title: 'O2 delivery and CO2 production during cardiopulmonary bypass as determinants of acute kidney injury: time for a goal-directed perfusion management?',
    journal: 'Critical Care. 2011;15(4):R192.',
    doi: 'doi: 10.1186/cc10349 · PMID: 21831302',
  );

  static const newland2017 = SourceRef(
    num: 7,
    authors: 'Newland RF, Baker RA.',
    title: 'Low oxygen delivery as a predictor of acute kidney injury during cardiopulmonary bypass.',
    journal: 'Journal of ExtraCorporeal Technology. 2017;49(4):224–230.',
    doi: 'PMID: 29302115',
  );

  static const newland2019 = SourceRef(
    num: 8,
    authors: 'Newland RF, Baker RA, Woodman RJ, Barnes MB, Willcox TW; Australian and New Zealand Collaborative Perfusion Registry.',
    title: 'Predictive Capacity of Oxygen Delivery During Cardiopulmonary Bypass on Acute Kidney Injury.',
    journal: 'Annals of Thoracic Surgery. 2019;108(6):1807–1814.',
    doi: 'doi: 10.1016/j.athoracsur.2019.04.115  ·  Multizentrische ANZCPR-Studie, n = 19 410',
  );

  static const ranucci2018 = SourceRef(
    num: 9,
    authors: 'Ranucci M, Johnson I, Willcox T, et al.',
    title: 'Goal-directed perfusion to reduce acute kidney injury: a randomized trial.',
    journal: 'Journal of Thoracic and Cardiovascular Surgery. 2018;156(5):1918–1927.',
    doi: 'doi: 10.1016/j.jtcvs.2018.04.045  ·  RCT zur GDP-Strategie.',
  );

  static const gao2023 = SourceRef(
    num: 10,
    authors: 'Gao P, Liu J, Zhang P, Bai L, Jin Y, Li Y.',
    title: 'Goal-directed perfusion for reducing acute kidney injury in cardiac surgery: a systematic review and meta-analysis.',
    journal: 'Perfusion. 2023;38(3):591–599.',
    doi: 'doi: 10.1177/02676591211073783  ·  Metaanalyse, n = 777 aus 3 RCTs.',
  );

  static const huefner = SourceRef(
    num: 11,
    authors: 'Hüfner G.',
    title: 'Neue Versuche zur Bestimmung der Sauerstoffcapacität des Blutfarbstoffs (Hüfner-Konstante 1.34 ml O₂/g Hb).',
    journal: 'Arch Anat Physiol (Physiol Abt). 1894:130–176.',
    doi: 'Historische Originalquelle der Hämoglobin-O₂-Bindungskapazität.',
  );

  static const dijkhuizen1977 = SourceRef(
    num: 12,
    authors: 'Dijkhuizen P, Buursma A, Fongers TM, Gerding AM, Oeseburg B, Zijlstra WG.',
    title: 'The oxygen binding capacity of human haemoglobin.',
    journal: 'Pflügers Archiv. 1977;369(3):223–231.',
    doi: 'doi: 10.1007/BF00582188  ·  Moderne Validierung der Hüfner-Konstante (β = 1,368 ml/g, n = 36).',
  );

  static const barrettBoyes = SourceRef(
    num: 13,
    authors: 'Barratt-Boyes BG, Wood EH.',
    title: 'Cardiac output and related measurements and pressure values in the right heart and associated vessels, together with an analysis of the hemodynamic response to the inhalation of high oxygen mixtures in healthy subjects.',
    journal: 'Journal of Laboratory and Clinical Medicine. 1958;51(1):72–90.',
    doi: 'PMID: 13502983  ·  Faktor 80 für SVR/PVR-Umrechnung in dyn·s·cm⁻⁵',
  );

  static const skimming = SourceRef(
    num: 14,
    authors: 'Skimming JW, Cassin S, Nichols WW.',
    title: 'Calculating vascular resistances.',
    journal: 'Clinical Cardiology. 1997;20(9):805–808.',
    doi: 'doi: 10.1002/clc.4960200913 · PMID: 9294672',
  );

  static const mellemgaardAstrup1960 = SourceRef(
    num: 15,
    authors: 'Mellemgaard K, Astrup P.',
    title: 'The quantitative determination of surplus amounts of acid or base in the human body.',
    journal: 'Scandinavian Journal of Clinical and Laboratory Investigation. 1960;12(2):187–199.',
    doi: 'doi: 10.3109/00365516009062420  ·  Base Excess (BE) Konzept und NaBic-Berechnungsformel.',
  );

  static const nahas1959 = SourceRef(
    num: 16,
    authors: 'Nahas GG.',
    title: 'Use of an organic carbon dioxide buffer in vivo.',
    journal: 'Science. 1959;129(3346):782–783.',
    doi: 'doi: 10.1126/science.129.3346.782  ·  TRIS-Puffer (Tris-Hydroxymethyl-Aminomethan).',
  );

  static const adrogueMadias2000 = SourceRef(
    num: 17,
    authors: 'Adrogué HJ, Madias NE.',
    title: 'Hyponatremia.',
    journal: 'New England Journal of Medicine. 2000;342(21):1581–1589.',
    doi: 'doi: 10.1056/NEJM200005253422107  ·  Natrium-Defizit-Berechnungsformel.',
  );

  // ── Severinghaus – BGA temperature correction ─────────────────────────────
  static const severinghaus1979 = SourceRef(
    num: 18,
    authors: 'Severinghaus JW.',
    title: 'Simple, accurate equations for human blood O₂ dissociation computations.',
    journal: 'Journal of Applied Physiology. 1979;46(3):599–602.',
    doi: 'Eq. 1: O₂-Dissoziationskurve  ·  Eq. 2: PO₂ aus SaO₂  ·  Eq. 3: Temperaturkoeffizient f_T = ΔlnPO₂/ΔT',
  );

  static const bradleySeveringhaus1956 = SourceRef(
    num: 19,
    authors: 'Bradley AF, Severinghaus JW, Stupfel M.',
    title: 'Effect of temperature on PCO₂ and PO₂ of blood in vitro.',
    journal: 'Journal of Applied Physiology. 1956;9(2):201–204.',
    doi: 'doi: 10.1152/jappl.1956.9.2.201  ·  PMID: 13376428  ·  PCO₂- und PO₂-Korrekturfaktoren (f_CO₂ = 0.0185, f_O₂ = 0.0247)',
  );

  static const severinghaus1966 = SourceRef(
    num: 20,
    authors: 'Severinghaus JW.',
    title: 'Blood gas calculator.',
    journal: 'Journal of Applied Physiology. 1966;21(3):1108–1116.',
    doi: 'Henderson-Hasselbalch-Gleichung für Blut  ·  HCO₃⁻ = 0.0307 × PCO₂ × 10^(pH − 6.105)',
  );

  static const ashwood1983 = SourceRef(
    num: 21,
    authors: 'Ashwood ER, Kost G, Kenny M.',
    title: 'Temperature correction of blood-gas and pH measurements.',
    journal: 'Clinical Chemistry. 1983;29(11):1877–1885.',
    doi: 'PMID: 6354511  ·  Kritische Überprüfung aller Temperaturkorrektformeln für pH, PCO₂ und PO₂',
  );

  static const gocol2021 = SourceRef(
    num: 22,
    authors: 'Gocoł R, Hudziak D, Bis J, Mendrala K, Morkisz Ł, Podsiadło P, Kosiński S, Piątek J, Darocha T.',
    title: 'The Role of Deep Hypothermia in Cardiac Surgery.',
    journal: 'International Journal of Environmental Research and Public Health. 2021;18(13):7061.',
    doi: 'doi: 10.3390/ijerph18137061  ·  Vierstufige CPB-Hypothermie-Klassifikation (mild/mittel/tief/sehr tief).',
  );

  static const linderkamp1977 = SourceRef(
    num: 23,
    authors: 'Linderkamp O, Versmold HT, Riegel KP, Betke K.',
    title: 'Estimation and prediction of blood volume in infants and children.',
    journal: 'European Journal of Pediatrics. 1977;125(4):227–234.',
    doi: 'doi: 10.1007/BF00493567  ·  PMID: 891567  ·  Pädiatrische Blutvolumen-Regressionsgleichungen.',
  );

  static const howie = SourceRef(
    num: 24,
    authors: 'Howie SR.',
    title: 'Blood sample volumes in child health research: review of safe limits.',
    journal: 'Bulletin of the World Health Organization. 2011;89(1):46–53.',
    doi: 'doi: 10.2471/BLT.10.080010 · PMID: 21346931',
  );

  static const davies = SourceRef(
    num: 25,
    authors: 'Davies P, Robertson S, Hegde S, Greenwood R, Massey E, Davis P.',
    title: 'Calculating the required transfusion volume in children.',
    journal: 'Transfusion. 2007;47(2):212–216.',
    doi: 'doi: 10.1111/j.1537-2995.2007.01091.x · PMID: 17302766',
  );

  static const ramakrishnan2023 = SourceRef(
    num: 26,
    authors: 'Ramakrishnan KV, Zurakowski D, Pearson GD, Pourmoghadam KK, Jonas RA, Sinha P.',
    title: 'Cardiopulmonary bypass in neonates and infants: advantages of high flow high hematocrit bypass strategy — clinical practice review.',
    journal: 'Translational Pediatrics. 2023;12(7):1483–1495.',
    doi: 'doi: 10.21037/tp-23-141  ·  Pädiatrische Perfusionsraten (high-flow/high-hematocrit).',
  );

  static const oldeen2020 = SourceRef(
    num: 27,
    authors: 'Oldeen ME, Angona RE, Hodge A, Klein T.',
    title: 'American Society of ExtraCorporeal Technology: Development of Standards and Guidelines for Pediatric and Congenital Perfusion Practice (2019).',
    journal: 'Journal of ExtraCorporeal Technology. 2020;52(4):319–326.',
    doi: 'doi: 10.1051/ject/202052319  ·  AmSECT-Leitlinie für pädiatrische und kongenitale Perfusion.',
  );

  static const finck = SourceRef(
    num: 28,
    authors: 'Finck C, et al.',
    title: 'Extracorporeal Life Support.',
    journal: 'Pediatric Surgery NaT, American Pediatric Surgical Association, 2025. Pediatric Surgery Library.',
    doi: 'www.pedsurglibrary.com/apsa/view/Pediatric-Surgery-NaT/829025/all/Extracorporeal_Life_Support  ·  VA/VV-Kanülengrößen für pädiatrische ECMO.',
  );

  static const blausenMedical = SourceRef(
    num: 29,
    authors: 'Blausen.com staff.',
    title: 'Medical gallery of Blausen Medical 2014.',
    journal: 'WikiJournal of Medicine. 2014;1(2):10. Licensed under CC BY 3.0.',
    doi: 'doi: 10.15347/wjm/2014.010  ·  Coronary Vessels (Anterior & Posterior) und Herzanatomie-Abbildungen.',
  );

  static const klineberg1984 = SourceRef(
    num: 30,
    authors: 'Klineberg PL, Kam CA, Johnson DC, Cartmill TB, Brown JJ.',
    title: 'Hematocrit and blood volume control during cardiopulmonary bypass with the use of hemofiltration.',
    journal: 'Anesthesiology. 1984;60(5):478\u2013480.',
    doi: 'doi: 10.1097/00000542-198405000-00015  \u00b7  Massenerhaltungsprinzip (Hct \u00d7 Volumen = konstant) für Ultrafiltration/Hämokonzentration.',
  );

  static const hensley2024 = SourceRef(
    num: 31,
    authors: 'Hensley NB, Colao JA, Zorrilla-Vaca A, et al.',
    title: 'Ultrafiltration in cardiac surgery: Results of a systematic review and meta-analysis.',
    journal: 'Perfusion. 2024;39(4):743\u2013751.',
    doi: 'doi: 10.1177/02676591231157970  \u00b7  Modifizierte Ultrafiltration (MUF) senkt intraoperative Erythrozytentransfusionen.',
  );

  static const buckberg1987 = SourceRef(
    num: 32,
    authors: 'Buckberg GD.',
    title: 'Strategies and logic of cardioplegic delivery to prevent, avoid, and reverse ischemic and reperfusion damage.',
    journal: 'J Thorac Cardiovasc Surg. 1987;93(1):127\u2013139.',
    doi: 'PMID: 3540457  \u00b7  4:1 Blut:Kristalloid-Kardioplegie, Erhaltungsdosis alle 15\u201320 min.',
  );

  static const matteDelNido2012 = SourceRef(
    num: 33,
    authors: 'Matte GS, del Nido PJ.',
    title: 'History and use of del Nido cardioplegia solution at Boston Children\u2019s Hospital.',
    journal: 'J Extra Corpor Technol. 2012;44(3):98\u2013103.',
    doi: 'doi: 10.1051/ject/201244098  \u00b7  4:1 Kristalloid:Blut-Kardioplegie als Einzeldosis.',
  );

  static const calafiore1995 = SourceRef(
    num: 34,
    authors: 'Calafiore AM, Teodori G, Mezzetti A, Bosco G, Verna AM, Di Giammarco G, Lapenna D.',
    title: 'Intermittent antegrade warm blood cardioplegia.',
    journal: 'Ann Thorac Surg. 1995;59(2):398\u2013402.',
    doi: 'doi: 10.1016/0003-4975(94)00843-V  \u00b7  Ursprungsarbeit der warmen intermittierenden Blutkardioplegie.',
  );

  static const calafiore2020 = SourceRef(
    num: 35,
    authors: 'Calafiore AM, Pelini P, Foschi M, Di Mauro M.',
    title: 'Intermittent Antegrade Warm Blood Cardioplegia: What Is Next?',
    journal: 'Thorac Cardiovasc Surg. 2020 Apr;68(3):232\u2013234. Epub 2019 Mar 5.',
    doi: 'doi: 10.1055/s-0039-1679925  \u00b7  PMID: 30836397  \u00b7  Modifiziertes Calafiore-Protokoll (absteigende K\u207a-Dosierung).',
  );

  static const bretschneider1980 = SourceRef(
    num: 36,
    authors: 'Bretschneider HJ.',
    title: 'Myocardial protection.',
    journal: 'Thorac Cardiovasc Surg. 1980;28(5):295\u2013302.',
    doi: 'doi: 10.1055/s-2007-1022099  \u00b7  Grundlagen der intrazellulären HTK-Kardioplegie.',
  );

  static const bretschneider1975 = SourceRef(
    num: 37,
    authors: 'Bretschneider HJ, Hübner G, Knoll D, Lohr B, Nordbeck H, Spieckermann PG.',
    title: 'Myocardial resistance and tolerance to ischemia: physiological and biochemical basis.',
    journal: 'J Cardiovasc Surg (Torino). 1975;16(3):241\u2013260.',
    doi: 'PMID: 239002  \u00b7  Physiologische/biochemische Basis der Ischämietoleranz.',
  );

  static const gebhard1984 = SourceRef(
    num: 38,
    authors: 'Gebhard MM, Preusse CJ, Schnabel PA, Bretschneider HJ.',
    title: 'Different effects of cardioplegic solution HTK during single or intermittent administration.',
    journal: 'Thorac Cardiovasc Surg. 1984;32(5):271\u2013276.',
    doi: 'doi: 10.1055/s-2007-1023400  \u00b7  Einmalige vs. intermittierende HTK-Gabe.',
  );
}
