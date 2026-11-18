import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'common.dart';

// ── Frozen-column reference table ─────────────────────────────────────────────
//
// For reference tables too wide for a phone (the Finck cannula tables have
// six and eight columns). The first column stays put; the rest scrolls
// horizontally underneath it, so the row label never leaves the screen.
//
// Same look as the other tables in the app (gold header on kTableHeaderBg,
// striped rows, gold first column). What is different:
//
// * Two separate layouts — the frozen column and the scrolling Table — have
//   to agree on row heights. Rather than measuring, every row is a fixed
//   two-line height derived from the text scaler, and every line is pinned
//   to that height with a forced strut. A cell may therefore hold at most
//   two lines, separated by '\n': the first is drawn emphasised, the second
//   secondary (e.g. "15 Art" / "BioMedicus").
// * Columns are as wide as their content (IntrinsicColumnWidth), so a word
//   is never broken in the middle — the reason the flow table on the tube
//   tab was rebuilt in v0.4.40. If everything fits, the leftover width is
//   shared out and nothing scrolls.
// * The frozen column never takes more than 45 % of the width. At the
//   largest system text sizes its header would otherwise push the scrolling
//   part off the screen; capped, a header without caption wraps instead.
// * The scrollbar is always visible and also takes a mouse drag: on the web
//   and the Windows bundle a mouse cannot swipe, and without the bar the
//   hidden columns would not be discoverable. A fade on the right edge
//   shows that more columns follow.

/// Header of one column: an optional small caption above the label (the
/// cannulation site, shared by neighbouring columns) and the label itself.
class FrozenTableHeader {
  final String label;
  final String caption;
  const FrozenTableHeader(this.label, {this.caption = ''});
}

class FrozenColumnTable extends StatefulWidget {
  /// headers[0] belongs to the frozen column.
  final List<FrozenTableHeader> headers;

  /// Each row has exactly headers.length cells; cell 0 is the frozen one.
  /// At most two lines per cell, separated by '\n'.
  final List<List<String>> rows;

  const FrozenColumnTable({super.key, required this.headers, required this.rows});

  @override
  State<FrozenColumnTable> createState() => _FrozenColumnTableState();
}

class _FrozenColumnTableState extends State<FrozenColumnTable> {
  static const double _fontSize = 13.5;
  static const double _lineHeight = 1.3;
  static const double _hPad = 10;
  static const double _vPad = 8;
  static const double _scrollbarGap = 12;
  static const double _maxFrozenShare = 0.45;
  static const StrutStyle _strut =
      StrutStyle(fontSize: _fontSize, height: _lineHeight, forceStrutHeight: true);

  final ScrollController _scroll = ScrollController();
  bool _moreToTheRight = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateFade);
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateFade);
    _scroll.dispose();
    super.dispose();
  }

  void _updateFade() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    final more = p.hasContentDimensions && p.pixels < p.maxScrollExtent - 1;
    if (more != _moreToTheRight) setState(() => _moreToTheRight = more);
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // Two strut lines plus padding. Both halves of the table use this one
    // value, so they line up whatever the font actually measures.
    final rowHeight = 2 * scaler.scale(_fontSize) * _lineHeight + 2 * _vPad;
    final headers = widget.headers;
    final rows = widget.rows;

    Color stripe(int i) => i.isOdd ? kRowStripeA : kRowStripeB;

    final frozen = IntrinsicWidth(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(color: kTableHeaderBg, child: _header(headers[0], rowHeight)),
        for (var i = 0; i < rows.length; i++)
          Container(
            color: stripe(i),
            child: _cell(rows[i][0], rowHeight, frozen: true),
          ),
        const SizedBox(height: _scrollbarGap),
      ]),
    );

    final scrolling = LayoutBuilder(builder: (context, constraints) {
      final table = Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          TableRow(
            decoration: BoxDecoration(color: kTableHeaderBg),
            children: [for (final h in headers.skip(1)) _header(h, rowHeight)],
          ),
          for (var i = 0; i < rows.length; i++)
            TableRow(
              decoration: BoxDecoration(color: stripe(i)),
              children: [for (final c in rows[i].skip(1)) _cell(c, rowHeight)],
            ),
        ],
      );

      // Re-evaluate the fade after every layout: a rotation or a text-size
      // change alters the overflow without any scrolling.
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());

      return Stack(children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context)
              .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: _scrollbarGap),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: table,
              ),
            ),
          ),
        ),
        if (_moreToTheRight)
          Positioned(
            top: 0, bottom: _scrollbarGap, right: 0, width: 28,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    kCardColor.withValues(alpha: 0),
                    kCardColor.withValues(alpha: 0.85),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });

    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDivider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: LayoutBuilder(builder: (context, outer) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: outer.maxWidth * _maxFrozenShare),
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border(right: BorderSide(color: kDivider))),
                child: frozen,
              ),
            ),
            Expanded(child: scrolling),
          ]);
        }),
      ),
    );
  }

  /// Caption on the first line, label on the second. Without a caption the
  /// label sits on the second line too, so all labels share one baseline —
  /// and may wrap onto the first line if the column is capped.
  Widget _header(FrozenTableHeader h, double height) => SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: _vPad),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text.rich(
              TextSpan(children: [
                if (h.caption.isNotEmpty)
                  TextSpan(
                    text: '${h.caption}\n',
                    style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                TextSpan(
                  text: h.label,
                  style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ]),
              strutStyle: _strut,
              maxLines: 2,
              softWrap: h.caption.isEmpty,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

  Widget _cell(String text, double height, {bool frozen = false}) {
    final nl = text.indexOf('\n');
    final first = nl < 0 ? text : text.substring(0, nl);
    final second = nl < 0 ? null : text.substring(nl + 1);
    final isEmpty = text == '–';
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: first,
                style: TextStyle(
                  color: frozen ? kGold : (isEmpty ? kTextFaint : kText),
                  fontSize: _fontSize,
                  fontWeight: frozen || !isEmpty ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (second != null)
                TextSpan(
                  text: '\n$second',
                  style: TextStyle(color: kTextSecondary, fontSize: 12.5),
                ),
            ]),
            strutStyle: _strut,
            maxLines: 2,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
