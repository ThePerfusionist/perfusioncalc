import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ranges.dart';
import '../i18n/app_strings.dart';
import '../utils/pdf_export.dart';

const kCardColor  = Color(0xFF1C1C1C);
const kGold       = Color(0xFFFFA500);
const kBg         = Color(0xFF2C2C2C);
const kBtnGrey    = Color(0xFF4A4A4A); // +/- button background

class InputCard extends StatefulWidget {
  final String label;
  final String unit;
  final double? value;
  final ValueChanged<double?> onChanged;
  final double step;

  /// Optionaler plausibler Wertebereich. Wenn gesetzt und der Wert liegt
  /// außerhalb dieses Bereichs, wird das Feld orange umrandet und ein
  /// Warn-Icon neben dem Label angezeigt (sanfte Warnung - die Berechnung
  /// läuft trotzdem normal weiter).
  final Range? range;

  const InputCard({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
    this.step = 0.1,
    this.range,
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
    _ctrl = TextEditingController(text: widget.value != null ? _fmt(widget.value!) : '');
  }

  @override
  void didUpdateWidget(InputCard old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      final newText = widget.value != null ? _fmt(widget.value!) : '';
      if (_ctrl.text != newText) {
        _ctrl.text = newText;
        _ctrl.selection = TextSelection.collapsed(offset: newText.length);
      }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _fmt(double v) {
    String s = v.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

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

  void _increment() {
    final v = double.parse(((widget.value ?? 0) + widget.step).toStringAsFixed(4));
    widget.onChanged(v);
  }

  void _decrement() {
    final v = double.parse(((widget.value ?? 0) - widget.step).toStringAsFixed(4));
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    // Prüfen, ob der aktuelle Wert im plausiblen Bereich liegt.
    // null (kein Wert eingegeben) gilt als "OK" - keine Warnung anzeigen.
    final bool outOfRange =
        widget.range != null && !widget.range!.contains(widget.value);

    // Orange Akzentfarbe für Warnzustand, sonst Standard-Darkcard.
    const warnColor = Color(0xFFFFA726); // material orange 400

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(8),
        // Warnrand: nur wenn outOfRange. Sonst transparenter Border,
        // damit sich das Layout zwischen "ok" und "warn" nicht verschiebt.
        border: Border.all(
          color: outOfRange ? warnColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            // Label + optionales Warn-Icon mit Tooltip.
            Row(children: [
              Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 14)),
              if (outOfRange) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: _warnTooltipFor(widget.range!),
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 4),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: warnColor, size: 16),
                ),
              ],
            ]),
            Text(widget.unit,  style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _btn(Icons.remove, _decrement),
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: outOfRange ? warnColor : Colors.white70,
                  fontSize: 22,
                ),
                // Input validation: max 10 chars, only digits/decimals/minus
                maxLength: 10,
                inputFormatters: [
                  // Allow only digits, single decimal separator (. or ,), optional leading minus
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
                decoration: InputDecoration(
                  counterText: '', // hide the "x/10" counter
                  border: InputBorder.none,
                  hintText: t('enter_value'),
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 18),
                ),
                onTap: () => setState(() => _editing = true),
                onChanged: (s) => widget.onChanged(_safeParse(s)),
                onEditingComplete: () { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
                onTapOutside: (_) { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
              ),
            ),
            _btn(Icons.add, _increment),
          ]),
        ]),
      ),
    );
  }

  /// Erzeugt den Tooltip-Text für das Warn-Icon.
  /// Format: "Ungewöhnlich - plausibel: 5–20 g/dl\nSchwere Anämie bis Polyglobulie"
  String _warnTooltipFor(Range r) {
    final base = 'Ungewöhnlicher Wert\nPlausibel: ${r.display}';
    return r.note != null ? '$base\n${r.note}' : base;
  }

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(color: kBtnGrey, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class ResultCard extends StatelessWidget {
  final String label;
  final String unit;
  final double value;
  final String? rangeHint;
  final int decimals;

  /// Liste fehlender Eingaben (bereits uebersetzt). Wenn nicht-leer:
  /// statt eines numerischen Wertes wird "—" angezeigt und darunter ein
  /// Hinweis, welche Eingaben noch ausstehen. Verhindert, dass leer
  /// gelassene Formeln als "0,00" missverstanden werden.
  final List<String> missingInputs;

  const ResultCard({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    this.rangeHint,
    this.decimals = 2,
    this.missingInputs = const [],
  });

  @override
  Widget build(BuildContext context) {
    final hasMissing = missingInputs.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
              if (rangeHint != null && !hasMissing)
                Text(rangeHint!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              if (hasMissing) ...[
                const SizedBox(height: 2),
                Text(
                  '${t('missing_inputs_hint')}${missingInputs.join(', ')}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ])),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(unit,  style: TextStyle(color: hasMissing ? Colors.white24 : Colors.white70, fontSize: 12)),
              Text(
                hasMissing ? '—' : value.toStringAsFixed(decimals),
                style: TextStyle(
                  color: hasMissing ? Colors.white38 : kGold,
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
        style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
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
                style: TextStyle(color: titleIsGold ? kGold : Colors.white,
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        Table(
          border: TableBorder(horizontalInside: BorderSide(color: Colors.white12)),
          columnWidths: {for (int i = 0; i < headers.length; i++) i: const FlexColumnWidth()},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.white10),
              children: headers.map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(h, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              )).toList(),
            ),
            ...rows.map((row) => TableRow(children: row.map((cell) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(cell, style: const TextStyle(color: Colors.white, fontSize: 13)),
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
// Problem: Flutter Web rendert standardmaessig ALLE Bilder ueber CanvasKit
// (WebGL). Das gilt auch fuer Image.network - der Bytes werden per fetch()
// geladen und in CanvasKit gezeichnet, NICHT als natives <img>-Element.
// In Browsern mit strikten Defaults (Privacy-Browser, Firefox mit
// fingerprinting-protection, einige Chromium-Forks) bricht entweder das
// WASM-Image-Decoding oder das CanvasKit-Pixelreading ab. Effekt: Bild
// erscheint nicht oder als leere weisse Flaeche (besonders bei SVGs).
//
// Loesung: Flutter 3.27+ bietet den Parameter `webHtmlElementStrategy` von
// Image.network. Wenn auf 'prefer' gesetzt, rendert Flutter das Bild als
// nativen <img>-Tag im DOM via HtmlElementView. Der Browser laedt und
// rendert dann selbst - unabhaengig von CanvasKit, unabhaengig vom
// Renderer. Funktioniert auch mit SVGs, weil Browser SVGs in <img>
// nativ unterstuetzen.
//
// Trade-offs (laut Flutter-Doku akzeptabel fuer unseren Use Case):
//   - Suboptimale Performance (irrelevant bei wenigen statischen Bildern)
//   - Kein Image.toByteData / OffsetLayer.toImage (nutzen wir nicht)
//   - Einige Color/Blend-Effekte funktionieren nicht (nutzen wir nicht)
//
// Voraussetzung: Asset liegt unter assets/<filename> in pubspec.yaml.
// Flutter packt es im web-Build unter assets/assets/<filename>, was dank
// <base href="/<app>/"> als 'assets/assets/<filename>' relativ adressierbar
// ist.

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
    // Flutter packt Assets in den web-Build unter assets/assets/<file>.
    // Ein relativer Pfad respektiert das <base href> der Seite.
    final url = 'assets/$assetPath';
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      // KRITISCH: zwingt Flutter, einen nativen <img>-Tag im DOM zu nutzen
      // statt das Bild ueber CanvasKit zu zeichnen. Bytes werden vom Browser
      // geladen, nicht von Flutter. Loest:
      //   - Bilder unsichtbar in Privacy-Browsern
      //   - SVG erscheint als weisse Flaeche
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      // Loading-Indikator waehrend des Bildladens
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
      // Fallback bei Fehler: Image.asset versuchen (z.B. fuer Mobile-Build,
      // wo es kein HTTP-Asset-Hosting gibt).
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
              const Icon(Icons.broken_image, color: Colors.white24, size: 48),
              const SizedBox(height: 8),
              Text('Image unavailable: $assetPath',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
        GestureDetector(
          onTap: () => _showFullImage(context),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
            child: BrowserSafeImage(assetPath: assetPath, fit: BoxFit.fitWidth),
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
        // Stack-Layout: Bild fuellt den Dialog und nutzt InteractiveViewer
        // fuer Pinch-Zoom; der Close-Button schwebt darueber. So bleibt der
        // Close-Button immer erreichbar, auch wenn das Bild sehr hoch ist
        // (z.B. die portrait-format Finck-Tabellen).
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
        ]),
      ),
    );
  }
}

// ── PDF Export button ─────────────────────────────────────────────────────────
//
// Wiederverwendbarer Button am Ende eines Tabs zum Export der aktuellen
// Eingaben/Ergebnisse als PDF. Auf Web wird der Browser-Download getriggert,
// auf Mobile wuerde man path_provider + share_plus nutzen (nicht implementiert).
//
// Der Tab uebergibt eine Funktion, die die Sections aktuell zusammenstellt -
// damit werden immer die aktuellsten Werte exportiert, nicht ein Snapshot
// vom Zeitpunkt des Tab-Aufbaus.
//
// Beispiel:
//   PdfExportButton(
//     filename: 'bsa',
//     tabTitleKey: 'tab_bsa',
//     buildSections: () => [
//       PdfSection(title: t('pdf_inputs'), rows: [...]),
//       PdfSection(title: t('pdf_results'), rows: [...]),
//     ],
//   )

class PdfExportButton extends StatelessWidget {
  /// Dateinamenstamm, z.B. 'bsa' -> "perfusioncalc_bsa_20260425_1630.pdf"
  final String filename;

  /// i18n-Key fuer den Tab-Titel im PDF-Header (z.B. 'tab_bsa').
  final String tabTitleKey;

  /// Callback der aktuellen Sections - wird erst beim Klick aufgerufen,
  /// damit immer die neuesten Werte erfasst werden.
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
      // Fehler in Browser-Console loggen, damit wir bei Problemen
      // den genauen Grund sehen koennen (statt stillem Versagen).
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
              style: const TextStyle(color: Colors.white, fontSize: 15)),
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

  // Nicht const, weil build() den globalen t()-Helfer aufruft, der sich bei
  // Sprachwechsel aendert. Mit const wuerde Flutter das Widget cachen und
  // den Sprachwechsel nicht mitbekommen.
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
          Text(t('source'), style: const TextStyle(color: Colors.white, fontSize: 15)),
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
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(r.title,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 2),
            Text(r.journal,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            if (r.doi.isNotEmpty)
              Text(r.doi, style: const TextStyle(color: Color(0xFF60A0E0), fontSize: 11)),
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
}
