import 'dart:math';

class PatientData {
  // ── Internal helper: guards against NaN/Infinity in results ─────────────
  // Any calculation producing NaN or Infinity is treated as "no result" (0).
  // This prevents extreme inputs (e.g. pow overflow) from crashing the UI.
  static double _safe(double v) {
    if (v.isNaN || v.isInfinite) return 0;
    return v;
  }

  // BSA/CO inputs
  double? height;
  double? weight;
  double? primingVolume;
  double? currentHb;
  double? currentHct;

  // BSA screen Cardiac Index (persisted, default 2.4)
  // This is loaded/saved via SharedPreferences in BSAScreen
  double bsaCardiacIndex = 2.4;

  // O2 delivery inputs
  double? paO2;
  double? pvO2;
  double? saO2;
  double? svO2;
  double? artHb;
  double? venHb;
  double? hzv;
  double? kof;
  double? cardiacIndex; // O2 tab CI manual override

  // Resistances inputs
  double? map;
  double? cvp;
  double? hzvRes;
  double? pap;
  double? lap;
  double? hzvPvr;

  // Electrolytes inputs
  double? bodyWeightElec;
  double? natriumIst;
  double? natriumSoll = 130;
  double? kaliumIst;
  double? kaliumSoll = 4.8;
  double? calziumIst;
  double? calziumSoll = 1.2;
  double? baseExcess;

  // Tube volume
  double? tubeLength;

  // Zoll/Charriere
  double? chInput;
  double? mmInput;

  // Pediatric
  double? pediatricWeight;
  double? desiredHbIncrease;

  // ── BSA/CO calculations ──────────────────────────────────────────────────
  double get bsa {
    if (height == null || weight == null) return 0;
    // Reject non-physiological or extreme inputs that would cause overflow
    if (height! <= 0 || weight! <= 0 || height! > 300 || weight! > 1000) return 0;
    final result = 0.007184 * pow(height!, 0.725) * pow(weight!, 0.425);
    return _safe(result.toDouble());
  }

  /// Cardiac output uses user-defined CI (default 2.4) instead of fixed value
  double get cardiacOutput => _safe(bsa * bsaCardiacIndex);

  double get bloodVolumeMale {
    if (weight == null || weight! <= 0) return 0;
    return 0.041 * weight! + 1.53;
  }

  double get bloodVolumeFemale {
    if (weight == null || weight! <= 0) return 0;
    return 0.047 * weight! + 0.86;
  }

  double get expectedHb {
    if (weight == null || weight! <= 0 || currentHb == null || primingVolume == null) return 0;
    final bvMl = weight! * 1000;
    if (bvMl <= 0) return 0;
    return currentHb! - (currentHb! * primingVolume!) / (bvMl / 10);
  }

  double get expectedHctMale {
    if (weight == null || currentHct == null || primingVolume == null) return 0;
    final bvMale = bloodVolumeMale * 1000;
    if (bvMale <= 0) return 0;
    return currentHct! * bvMale / (bvMale + primingVolume!);
  }

  double get expectedHctFemale {
    if (weight == null || currentHct == null || primingVolume == null) return 0;
    final bvFemale = bloodVolumeFemale * 1000;
    if (bvFemale <= 0) return 0;
    return currentHct! * bvFemale / (bvFemale + primingVolume!);
  }

  // ── O2 delivery ──────────────────────────────────────────────────────────
  double get cardiacIndexEffective {
    if (cardiacIndex != null && cardiacIndex! > 0) return cardiacIndex!;
    if (hzv != null && hzv! > 0 && kof != null && kof! > 0) return hzv! / kof!;
    return 0;
  }

  double get _coEffective {
    if (hzv != null && hzv! > 0) return hzv!;
    if (cardiacIndex != null && cardiacIndex! > 0 && kof != null && kof! > 0) return cardiacIndex! * kof!;
    return 0;
  }

  double get _bsaEffective => kof ?? 0;

  double get caO2 {
    if (artHb == null || saO2 == null || paO2 == null) return 0;
    return (artHb! * 1.34 * (saO2! / 100)) + (paO2! * 0.0031);
  }

  double get cvO2 {
    if (venHb == null || svO2 == null || pvO2 == null) return 0;
    return (venHb! * 1.34 * (svO2! / 100)) + (pvO2! * 0.0031);
  }

  double get cavDO2 => caO2 - cvO2;

  double get do2 {
    final co = _coEffective;
    if (co <= 0) return 0;
    return caO2 * co * 10;
  }

  double get do2i {
    final ci = cardiacIndexEffective;
    if (ci <= 0) return 0;
    return caO2 * ci * 10;
  }

  double get vo2 {
    final co = _coEffective;
    if (co <= 0) return 0;
    return cavDO2 * co * 10;
  }

  double get vo2i {
    final ci = cardiacIndexEffective;
    if (ci <= 0) return 0;
    return cavDO2 * ci * 10;
  }

  double get o2er {
    final d = do2;
    if (d <= 0) return 0;
    return (vo2 / d) * 100;
  }

  double get minCardiacOutput {
    final bsaVal = _bsaEffective;
    if (caO2 <= 0 || bsaVal <= 0) return 0;
    return (272 * bsaVal) / (caO2 * 10);
  }

  double get minHb {
    final co = _coEffective;
    final bsaVal = _bsaEffective;
    if (co <= 0 || bsaVal <= 0 || saO2 == null || paO2 == null) return 0;
    final num = (272 * bsaVal) - (10 * co * 0.0031 * paO2!);
    final den = 10 * co * 1.34 * (saO2! / 100);
    if (den <= 0) return 0;
    return num / den;
  }

  // ── Resistances ──────────────────────────────────────────────────────────
  double get svr {
    if (map == null || cvp == null || hzvRes == null || hzvRes! <= 0) return 0;
    return (map! - cvp!) / hzvRes! * 80;
  }

  double get pvr {
    if (pap == null || lap == null || hzvPvr == null || hzvPvr! <= 0) return 0;
    return (pap! - lap!) / hzvPvr! * 80;
  }

  // ── Electrolytes ─────────────────────────────────────────────────────────
  double get natriumBedarf {
    if (natriumIst == null || natriumSoll == null || bodyWeightElec == null) return 0;
    return ((natriumSoll! - natriumIst!) * bodyWeightElec! * 0.2) / 1.71;
  }

  double get kaliumBedarf {
    if (kaliumIst == null || kaliumSoll == null || bodyWeightElec == null) return 0;
    return ((kaliumSoll! - kaliumIst!) * bodyWeightElec! * 0.2) / 1.0;
  }

  double get calziumBedarf {
    if (calziumIst == null || calziumSoll == null || bodyWeightElec == null) return 0;
    return ((calziumSoll! - calziumIst!) * bodyWeightElec! * 0.2) / 0.225;
  }

  double get nabic {
    if (baseExcess == null || bodyWeightElec == null) return 0;
    return (baseExcess! * bodyWeightElec! * 3) / (-10);
  }

  double get tris {
    if (baseExcess == null || bodyWeightElec == null) return 0;
    return (baseExcess! * bodyWeightElec!) / (-10);
  }

  // ── Tube volume ───────────────────────────────────────────────────────────
  double get tubeVol12  => (tubeLength ?? 0) * 1.2668;
  double get tubeVol38  => (tubeLength ?? 0) * 0.7126;
  double get tubeVol14  => (tubeLength ?? 0) * 0.3167;
  double get tubeVol316 => (tubeLength ?? 0) * 0.1781;

  // ── Charriere ─────────────────────────────────────────────────────────────
  double get chToMm => (chInput ?? 0) / 3;
  double get mmToCh => (mmInput ?? 0) * 3;

  // ── Pediatric transfusion ─────────────────────────────────────────────────
  double get transfusionVolume {
    if (pediatricWeight == null || desiredHbIncrease == null) return 0;
    return pediatricWeight! * desiredHbIncrease! * 3 / (55 * 0.01);
  }
}
