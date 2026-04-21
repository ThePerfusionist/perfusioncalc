import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';

class O2DeliveryScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const O2DeliveryScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<O2DeliveryScreen> createState() => _O2DeliveryScreenState();
}

enum _CoMode { co, ci }

class _O2DeliveryScreenState extends State<O2DeliveryScreen> {
  _CoMode _mode = _CoMode.co;
  PatientData get pd => widget.patientData;

  void _switchMode(_CoMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _CoMode.co) { pd.cardiacIndex = null; }
      else { pd.hzv = null; }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        _CoCiCard(
          mode: _mode, coValue: pd.hzv, ciValue: pd.cardiacIndex, bsaValue: pd.kof,
          onModeChanged: _switchMode,
          onCoChanged: (v) { pd.hzv = v; pd.cardiacIndex = null; widget.onChanged(); },
          onCiChanged: (v) { pd.cardiacIndex = v; pd.hzv = null; widget.onChanged(); },
        ),
        InputCard(label: 'BSA', unit: 'm\u00b2', value: pd.kof, step: 0.01,
            onChanged: (v) { pd.kof = v; widget.onChanged(); }),
        InputCard(label: 'PaO\u2082', unit: 'mmHg', value: pd.paO2,
            onChanged: (v) { pd.paO2 = v; widget.onChanged(); }),
        InputCard(label: 'SaO\u2082', unit: '%', value: pd.saO2,
            onChanged: (v) { pd.saO2 = v; widget.onChanged(); }),
        InputCard(label: 'art. Hb', unit: 'g/dl', value: pd.artHb,
            onChanged: (v) { pd.artHb = v; widget.onChanged(); }),
        InputCard(label: 'PvO\u2082', unit: 'mmHg', value: pd.pvO2,
            onChanged: (v) { pd.pvO2 = v; widget.onChanged(); }),
        InputCard(label: 'SvO\u2082', unit: '%', value: pd.svO2,
            onChanged: (v) { pd.svO2 = v; widget.onChanged(); }),
        InputCard(label: 'ven. Hb', unit: 'g/dl', value: pd.venHb,
            onChanged: (v) { pd.venHb = v; widget.onChanged(); }),
        ResultCard(label: 'CaO\u2082',    unit: 'ml/dl',          value: pd.caO2,  rangeHint: '(18-20 ml O\u2082/dl)'),
        ResultCard(label: 'CvO\u2082',    unit: 'ml/dl',          value: pd.cvO2,  rangeHint: '(14-15 ml O\u2082/dl)'),
        ResultCard(label: 'Ca-vDO\u2082', unit: 'ml/dl',          value: pd.cavDO2, rangeHint: '(4-6 ml/dl)'),
        ResultCard(label: 'DO\u2082',     unit: 'ml/min',          value: pd.do2),
        ResultCard(label: 'DO\u2082i',    unit: 'ml/min/m\u00b2',  value: pd.do2i,  rangeHint: '(>272 ml/min/m\u00b2)'),
        ResultCard(label: 'VO\u2082',     unit: 'ml/min',          value: pd.vo2),
        ResultCard(label: 'VO\u2082i',    unit: 'ml/min/m\u00b2',  value: pd.vo2i,  rangeHint: '(120-160 ml/min/m\u00b2)'),
        ResultCard(label: 'O\u2082-ER',   unit: '%',               value: pd.o2er,  rangeHint: '(22-35%)'),
        ResultCard(label: 'Min. cardiac output', unit: 'L/min', value: pd.minCardiacOutput, rangeHint: 'at 272 ml/min/m\u00b2 DO\u2082i'),
        ResultCard(label: 'Min. Hb', unit: 'g/dl', value: pd.minHb, rangeHint: 'at 272 ml/min/m\u00b2 DO\u2082i'),
        const SizedBox(height: 8),
        // Chart button
        GestureDetector(
          onTap: () => _showChartDialog(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            width: double.infinity,
            decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Text('Chart', style: TextStyle(color: Colors.white, fontSize: 15)),
              SizedBox(width: 8),
              Icon(Icons.bar_chart, color: Colors.white70, size: 20),
            ]),
          ),
        ),
        const SourceButton(refs: [
          AppSources.deSomer,
          AppSources.newland2019,
          AppSources.newland2017,
          AppSources.ranucci2018,
          AppSources.ranucci2005,
          AppSources.huefner,
          AppSources.gorlin,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _showChartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Oxygen Delivery Calculation Chart',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image.asset('assets/o2_chart.png')),
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.redAccent))),
        ]),
      ),
    );
  }
}

// ── Merged CO/CI card ─────────────────────────────────────────────────────────
class _CoCiCard extends StatefulWidget {
  final _CoMode mode;
  final double? coValue, ciValue, bsaValue;
  final ValueChanged<_CoMode> onModeChanged;
  final ValueChanged<double?> onCoChanged, onCiChanged;

  const _CoCiCard({required this.mode, required this.coValue, required this.ciValue,
    required this.bsaValue, required this.onModeChanged, required this.onCoChanged, required this.onCiChanged});

  @override
  State<_CoCiCard> createState() => _CoCiCardState();
}

class _CoCiCardState extends State<_CoCiCard> {
  late TextEditingController _ctrl;
  bool _editing = false;

  double? get _val => widget.mode == _CoMode.co ? widget.coValue : widget.ciValue;
  ValueChanged<double?> get _cb => widget.mode == _CoMode.co ? widget.onCoChanged : widget.onCiChanged;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: _fmt(_val)); }

  @override
  void didUpdateWidget(_CoCiCard old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      final t = _fmt(_val);
      if (_ctrl.text != t) { _ctrl.text = t; _ctrl.selection = TextSelection.collapsed(offset: t.length); }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _fmt(double? v) {
    if (v == null) return '';
    String s = v.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _inc() => _cb(double.parse(((_val ?? 0) + 0.1).toStringAsFixed(4)));
  void _dec() => _cb(double.parse(((_val ?? 0) - 0.1).toStringAsFixed(4)));

  @override
  Widget build(BuildContext context) {
    final isCo = widget.mode == _CoMode.co;
    String? hint;
    if (isCo && widget.coValue != null && widget.bsaValue != null && widget.bsaValue! > 0) {
      hint = 'CI = ${(widget.coValue! / widget.bsaValue!).toStringAsFixed(2)} l/min/m\u00b2';
    } else if (!isCo && widget.ciValue != null && widget.bsaValue != null && widget.bsaValue! > 0) {
      hint = 'CO = ${(widget.ciValue! * widget.bsaValue!).toStringAsFixed(2)} l/min';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCardColor, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isCo ? 'Cardiac output' : 'Cardiac index',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            Container(
              decoration: const BoxDecoration(color: Color(0xFF2A2A2A), borderRadius: BorderRadius.all(Radius.circular(20))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _toggleBtn('CO', _CoMode.co), _toggleBtn('CI', _CoMode.ci),
              ]),
            ),
          ]),
          Text(isCo ? 'l/min' : 'l/min/m\u00b2', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Row(children: [
            _btn(Icons.remove, _dec),
            Expanded(child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 22),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter value',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 18)),
              onTap: () => setState(() => _editing = true),
              onChanged: (s) => _cb(double.tryParse(s.replaceAll(',', '.'))),
              onEditingComplete: () { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
              onTapOutside: (_) { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
            )),
            _btn(Icons.add, _inc),
          ]),
          if (hint != null) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(hint, style: TextStyle(color: kGold.withValues(alpha: 0.7), fontSize: 11)),
          ),
        ]),
      ),
    );
  }

  Widget _toggleBtn(String label, _CoMode mode) {
    final active = widget.mode == mode;
    return GestureDetector(
      onTap: () { if (!active) { setState(() => _ctrl.text = ''); widget.onModeChanged(mode); } },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: active ? kGold : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: active ? Colors.black : Colors.white54,
            fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 36, height: 36,
        decoration: const BoxDecoration(color: kBtnGrey, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20)),
  );
}
