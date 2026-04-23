import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/common.dart';
import '../models/patient_data.dart';

const _kCiKey = 'bsa_cardiac_index';

class BSAScreen extends StatefulWidget {
  final PatientData patientData;
  final VoidCallback onChanged;
  const BSAScreen({super.key, required this.patientData, required this.onChanged});
  @override
  State<BSAScreen> createState() => _BSAScreenState();
}

class _BSAScreenState extends State<BSAScreen> {
  bool _loaded = false;

  @override
  void initState() { super.initState(); _loadCI(); }

  Future<void> _loadCI() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(_kCiKey) ?? 2.4;
    // Validate against corrupted / tampered preference values
    final safe = (raw.isNaN || raw.isInfinite || raw <= 0 || raw > 10) ? 2.4 : raw;
    setState(() {
      widget.patientData.bsaCardiacIndex = safe;
      _loaded = true;
    });
    // If the stored value was invalid, overwrite with the safe default
    if (safe != raw) await prefs.setDouble(_kCiKey, safe);
    widget.onChanged();
  }

  Future<void> _saveCI(double v) async {
    // Only persist sensible values; reject NaN/Infinity/out-of-range
    if (v.isNaN || v.isInfinite || v <= 0 || v > 10) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kCiKey, v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final pd = widget.patientData;
    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 8),
        InputCard(label: 'Body height', unit: 'cm', value: pd.height,
            onChanged: (v) { pd.height = v; widget.onChanged(); }),
        InputCard(label: 'Body weight', unit: 'kg', value: pd.weight,
            onChanged: (v) { pd.weight = v; widget.onChanged(); }),
        InputCard(label: 'Current Hb', unit: 'g/dl', value: pd.currentHb,
            onChanged: (v) { pd.currentHb = v; widget.onChanged(); }),
        InputCard(label: 'Current Hct', unit: '%', value: pd.currentHct,
            onChanged: (v) { pd.currentHct = v; widget.onChanged(); }),
        InputCard(label: 'Priming volume', unit: 'ml', value: pd.primingVolume,
            step: 1, onChanged: (v) { pd.primingVolume = v; widget.onChanged(); }),
        _CIInputCard(
          value: pd.bsaCardiacIndex,
          onChanged: (v) {
            if (v != null && v > 0) {
              pd.bsaCardiacIndex = v;
              _saveCI(v);
              widget.onChanged();
            }
          },
        ),
        ResultCard(label: 'BSA (DuBois)', unit: 'm\u00b2', value: pd.bsa),
        ResultCard(
          label: 'Cardiac output (CI ${pd.bsaCardiacIndex.toStringAsFixed(1)})',
          unit: 'l/min', value: pd.cardiacOutput,
        ),
        ResultCard(label: 'Blood volume man',   unit: 'l', value: pd.bloodVolumeMale),
        ResultCard(label: 'Blood volume woman', unit: 'l', value: pd.bloodVolumeFemale),
        const SectionHeader('Expected Hb/Hct after priming'),
        ResultCard(label: 'Expected Hb',          unit: 'g/dl', value: pd.expectedHb),
        ResultCard(label: 'Expected Hct (man)',   unit: '%',    value: pd.expectedHctMale),
        ResultCard(label: 'Expected Hct (woman)', unit: '%',    value: pd.expectedHctFemale),
        const SizedBox(height: 8),
        const SourceButton(refs: [
          AppSources.dubois,
          AppSources.silbernagl,
          AppSources.nadler,
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _CIInputCard extends StatefulWidget {
  final double value;
  final ValueChanged<double?> onChanged;
  const _CIInputCard({required this.value, required this.onChanged});
  @override
  State<_CIInputCard> createState() => _CIInputCardState();
}

class _CIInputCardState extends State<_CIInputCard> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: _fmt(widget.value)); }

  @override
  void didUpdateWidget(_CIInputCard old) {
    super.didUpdateWidget(old);
    if (!_editing) {
      final t = _fmt(widget.value);
      if (_ctrl.text != t) { _ctrl.text = t; _ctrl.selection = TextSelection.collapsed(offset: t.length); }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _fmt(double v) {
    String s = v.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _inc() => widget.onChanged(double.parse((widget.value + 0.1).toStringAsFixed(4)));
  void _dec() => widget.onChanged(double.parse((widget.value - 0.1).toStringAsFixed(4)));

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withValues(alpha: 0.25), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Text('Cardiac index', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: const Text('saved', style: TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
            const Text('l/min/m\u00b2', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _btn(Icons.remove, _dec),
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 22),
                decoration: const InputDecoration(border: InputBorder.none),
                onTap: () => setState(() => _editing = true),
                onChanged: (s) => widget.onChanged(double.tryParse(s.replaceAll(',', '.'))),
                onEditingComplete: () { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
                onTapOutside: (_) { setState(() => _editing = false); FocusScope.of(context).unfocus(); },
              ),
            ),
            _btn(Icons.add, _inc),
          ]),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Default 2.4  ·  Value is saved between sessions',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ]),
      ),
    );
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
