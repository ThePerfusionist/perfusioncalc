// ── Finck 2025: paediatric ECMO cannula tables ───────────────────────────────
//
// Transcribed in v0.4.40 from the two spreadsheet screenshots that the
// pediatric tab used to show as images (assets/finck_va.jpg and
// assets/finck_vv.jpg). The images stay in the repository: the standalone
// fallback page web/cannulas.html still shows them, and the service worker
// precaches them for it. Compare against them when editing. Source:
// AppSources.finck.
//
// Transcription rules — keep them when editing:
//
// * Values as in the original. Only the presentation changed: "Fr" is dropped
//   from the cells and stated once in the footnote, "cc" became "ml", and
//   "Biomedicus" was normalised to "BioMedicus".
// * One deliberate oddity kept verbatim: 15–16 kg in the V-V Avalon column
//   reads "VAD 12210", every other row "VAK". It looks like a typo for VAK,
//   but changing it is the maintainer's call, not the transcriber's.
// * The V-V Avalon column (17 kg and up) uses merged cells in the original,
//   with the text sitting in every second row. Read as blocks: 23 Fr for
//   17–30 kg, 27 Fr for 31–50 kg, 31 Fr from 51 kg. Each row here repeats
//   the value of its block.
// * Not transcribed: the colour coding and the "additional available
//   arterial cannula: 16/18 Edwards" box. Both describe where the source
//   institution stores its stock (ECPR cart, ECMO Omnicell, cardiac core),
//   not which cannula to use.
//
// Cell format: at most two lines, '\n' between size and product. The token
// {or} is replaced with the translated word at render time (finckOr). An en
// dash marks a cannulation route the original leaves empty for that weight.

/// Weight bands shared by both tables (kg; the unit sits in the header).
const List<String> kFinckWeightBands = [
  '≤ 2', '2 – 2.9', '3 – 3.9', '4 – 4.9', '5 – 5.9',
  '6 – 6.9', '7 – 7.9', '8 – 8.9', '9 – 9.9', '10 – 12',
  '13 – 14', '15 – 16', '17 – 18', '19 – 20', '21 – 25',
  '26 – 30', '31 – 35', '36 – 40', '41 – 45', '46 – 50',
  '51 – 60', '61 – 65', '66 – 70', '≥ 70',
];

const String _bm = 'BioMedicus';
const String _ed = 'Edwards';
const String _dlp = 'DLP';
const String _og = 'OriGen DL';
const String _none = '–';

/// V-A: weight | neck venous | neck arterial | groin venous |
/// groin arterial | chest venous | chest arterial | connector
const List<List<String>> kFinckVaRows = [
  ['≤ 2',          '10\n$_bm',     '8\n$_ed',      _none,          _none,          '14\n$_dlp',    '8\n$_dlp',  '1/4"'],
  ['2 – 2.9',      '10\n$_bm',     '8\n$_ed',      _none,          _none,          '16\n$_dlp',    '8\n$_dlp',  '1/4"'],
  ['3 – 3.9',      '12\n$_bm',     '8\n$_ed',      _none,          _none,          '16\n$_dlp',    '10\n$_dlp', '1/4"'],
  ['4 – 4.9',      '12\n$_bm',     '10\n$_ed',     _none,          _none,          '16\n$_dlp',    '10\n$_dlp', '1/4"'],
  ['5 – 5.9',      '14\n$_bm',     '10\n$_ed',     _none,          _none,          '18\n$_dlp',    '12\n$_dlp', '1/4"'],
  ['6 – 6.9',      '14\n$_bm',     '10\n$_ed',     _none,          _none,          '18\n$_dlp',    '12\n$_dlp', '1/4"'],
  ['7 – 7.9',      '14\n$_bm',     '12\n$_ed',     _none,          _none,          '18\n$_dlp',    '12\n$_dlp', '1/4"'],
  ['8 – 8.9',      '14\n$_bm',     '12\n$_ed',     _none,          _none,          '18\n$_dlp',    '12\n$_dlp', '1/4"'],
  ['9 – 9.9',      '14\n$_bm',     '12\n$_ed',     _none,          _none,          '18\n$_dlp',    '12\n$_dlp', '1/4"'],
  ['10 – 12',      '14\n$_bm',     '12\n$_ed',     '15 Ven\n$_bm', '12\n$_ed',     '18\n$_dlp',    '12\n$_dlp', '1/4"'],
  ['13 – 14',      '15 Art\n$_bm', '14\n$_ed',     '15 Ven\n$_bm', '14\n$_ed',     '20\n$_dlp',    '14\n$_dlp', '1/4"'],
  ['15 – 16',      '17 Art\n$_bm', '14\n$_ed',     '17 Ven\n$_bm', '14\n$_ed',     '22\n$_dlp',    '14\n$_dlp', '3/8"'],
  ['17 – 18',      '19 Art\n$_bm', '15 Art\n$_bm', '19 Ven\n$_bm', '15 Art\n$_bm', '22\n$_dlp',    '14\n$_dlp', '1/4" {or} 3/8"'],
  ['19 – 20',      '19 Art\n$_bm', '15 Art\n$_bm', '19 Ven\n$_bm', '15 Art\n$_bm', '24\n$_dlp',    '16\n$_dlp', '3/8"'],
  ['21 – 25',      '19 Art\n$_bm', '15 Art\n$_bm', '19 Ven\n$_bm', '15 Art\n$_bm', '24\n$_dlp',    '16\n$_dlp', '3/8"'],
  ['26 – 30',      '21 Art\n$_bm', '15 Art\n$_bm', '21 Ven\n$_bm', '15 Art\n$_bm', '24\n$_dlp',    '16\n$_dlp', '3/8"'],
  ['31 – 35',      '21 Art\n$_bm', '15 Art\n$_bm', '21 Ven\n$_bm', '15 Art\n$_bm', '24\n$_dlp',    '16\n$_dlp', '3/8"'],
  ['36 – 40',      '21 Art\n$_bm', '17 Art\n$_bm', '23 Ven\n$_bm', '17 Art\n$_bm', '28\n$_dlp',    '16\n$_dlp', '3/8"'],
  ['41 – 45',      '23 Art\n$_bm', '19 Art\n$_bm', '25 Ven\n$_bm', '19 Art\n$_bm', '28\n$_dlp',    '16\n$_dlp', '3/8" {or} 1/2"'],
  ['46 – 50',      '23 Art\n$_bm', '19 Art\n$_bm', '25 Ven\n$_bm', '19 Art\n$_bm', '28\n$_dlp',    '18\n$_dlp', '3/8" {or} 1/2"'],
  ['51 – 60',      '23 Art\n$_bm', '19 Art\n$_bm', '27 Ven\n$_bm', '19 Art\n$_bm', '29/37\n$_ed', '20\n$_dlp', '1/2"'],
  ['61 – 65',      '23 Art\n$_bm', '21 Art\n$_bm', '27 Ven\n$_bm', '21 Art\n$_bm', '29/37\n$_ed', '20\n$_dlp', '1/2"'],
  ['66 – 70',      '23 Art\n$_bm', '21 Art\n$_bm', '27 Ven\n$_bm', '21 Art\n$_bm', '29/37\n$_ed', '20\n$_dlp', '1/2"'],
  ['≥ 70',         '23 Art\n$_bm', '21 Art\n$_bm', '27 Ven\n$_bm', '23 Art\n$_bm', '29/37\n$_ed', '20\n$_dlp', '1/2"'],
];

/// V-V: weight | neck dual-lumen or reinfusion | groin drainage |
/// groin reinfusion | neck Avalon dual-lumen | connector
const List<List<String>> kFinckVvRows = [
  ['≤ 2',          '13\n$_og',          _none,          _none,           _none,                      '1/4"'],
  ['2 – 2.9',      '13\n$_og',          _none,          _none,           '13 Avalon DL\nVAK 12100',  '1/4"'],
  ['3 – 3.9',      '13\n$_og',          _none,          _none,           '13 Avalon DL\nVAK 12100',  '1/4"'],
  ['4 – 4.9',      '13 {or} 15\n$_og',  _none,          _none,           '13 Avalon DL\nVAK 12100',  '1/4"'],
  ['5 – 5.9',      '15\n$_og',          _none,          _none,           '16 Avalon DL\nVAK 12100',  '1/4"'],
  ['6 – 6.9',      '15\n$_og',          _none,          _none,           '16 Avalon DL\nVAK 12100',  '1/4"'],
  ['7 – 7.9',      '15 {or} 18\n$_og',  _none,          _none,           '16 Avalon DL\nVAK 12100',  '1/4"'],
  ['8 – 8.9',      '18\n$_og',          _none,          _none,           '19 Avalon DL\nVAK 12100',  '1/4"'],
  ['9 – 9.9',      '18\n$_og',          _none,          _none,           '19 Avalon DL\nVAK 12100',  '1/4"'],
  ['10 – 12',      '18\n$_og',          '15 Ven\n$_bm', '12 Art\n$_ed',  '19 Avalon DL\nVAK 12100',  '1/4"'],
  ['13 – 14',      '18\n$_og',          '15 Ven\n$_bm', '14 Art\n$_ed',  '19 Avalon DL\nVAK 12100',  '1/4"'],
  // "VAD" verbatim from the original, see the header comment.
  ['15 – 16',      '14 Art\n$_ed',      '17 Ven\n$_bm', '14 Art\n$_ed',  '20 Avalon DL\nVAD 12210',  '3/8"'],
  ['17 – 18',      '15 Art\n$_bm',      '19 Ven\n$_bm', '15 Art\n$_bm',  '23 Avalon DL\nVAK 12210',  '3/8"'],
  ['19 – 20',      '15 Art\n$_bm',      '19 Ven\n$_bm', '15 Art\n$_bm',  '23 Avalon DL\nVAK 12210',  '3/8"'],
  ['21 – 25',      '15 Art\n$_bm',      '19 Ven\n$_bm', '15 Art\n$_bm',  '23 Avalon DL\nVAK 12210',  '3/8"'],
  ['26 – 30',      '15 Art\n$_bm',      '21 Ven\n$_bm', '15 Art\n$_bm',  '23 Avalon DL\nVAK 12210',  '3/8"'],
  ['31 – 35',      '15 Art\n$_bm',      '21 Ven\n$_bm', '15 Art\n$_bm',  '27 Avalon DL\nVAK 12210',  '3/8"'],
  ['36 – 40',      '17 Art\n$_bm',      '23 Ven\n$_bm', '17 Art\n$_bm',  '27 Avalon DL\nVAK 12210',  '3/8"'],
  ['41 – 45',      '19 Art\n$_bm',      '25 Ven\n$_bm', '19 Art\n$_bm',  '27 Avalon DL\nVAK 12210',  '3/8"'],
  ['46 – 50',      '19 Art\n$_bm',      '25 Ven\n$_bm', '19 Art\n$_bm',  '27 Avalon DL\nVAK 12210',  '3/8"'],
  ['51 – 60',      '19 Art\n$_bm',      '27 Ven\n$_bm', '19 Art\n$_bm',  '31 Avalon DL\nVAK 12210',  '3/8" {or} 1/2"'],
  ['61 – 65',      '21 Art\n$_bm',      '27 Ven\n$_bm', '21 Art\n$_bm',  '31 Avalon DL\nVAK 12210',  '3/8" {or} 1/2"'],
  ['66 – 70',      '21 Art\n$_bm',      '27 Ven\n$_bm', '21 Art\n$_bm',  '31 Avalon DL\nVAK 12210',  '3/8" {or} 1/2"'],
  ['≥ 70',         '21 Art\n$_bm',      '27 Ven\n$_bm', '23 Art\n$_bm',  '31 Avalon DL\nVAK 12210',  '3/8" {or} 1/2"'],
];

/// Recommended "full" flow, identical on both original sheets:
/// weight (kg) | flow (ml/kg/min).
const List<List<String>> kFinckFullFlowRows = [
  ['≤ 7',          '120 – 200'],
  ['7 – 10',       '100 – 150'],
  ['10 – 20',      '80 – 120'],
  ['20 – 25',      '100'],
  ['≥ 25',         '80'],
];

/// Replaces the {or} token with [or] (the translated word).
String finckOr(String cell, String or) => cell.replaceAll('{or}', or);
