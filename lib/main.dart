import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/bsa_screen.dart';
import 'screens/o2_delivery_screen.dart';
import 'screens/resistances_screen.dart';
import 'screens/electrolytes_screen.dart';
import 'screens/tube_volume_screen.dart';
import 'screens/flow_drainage_screen.dart';
import 'screens/zoll_chairre_screen.dart';
import 'screens/hypothermia_screen.dart';
import 'screens/pediatric_screen.dart';
import 'screens/reference_pressure_screen.dart';
import 'screens/heart_anatomy_screen.dart';
import 'models/patient_data.dart';

const kAppVersion = '0.1.7';
const _kDark = Color(0xFF1C1C1C);
const _kGold = Color(0xFFFFA500);

void main() { runApp(const PerfusionCalcApp()); }

class PerfusionCalcApp extends StatelessWidget {
  const PerfusionCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PerfusionCalc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(primary: _kGold, surface: _kDark),
        scaffoldBackgroundColor: const Color(0xFF2C2C2C),
        appBarTheme: const AppBarTheme(backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PatientData _patientData = PatientData();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'BSA/CO/Hb/Hct',             'icon': Icons.monitor_heart_outlined},
    {'label': 'O\u2082 delivery',           'icon': Icons.air},
    {'label': 'Resistances',                'icon': Icons.compress},
    {'label': 'Electrolytes/Buffer',        'icon': Icons.science_outlined},
    {'label': 'Tube volume',                'icon': Icons.linear_scale},
    {'label': 'Flow/Drainage rate',         'icon': Icons.water_drop_outlined},
    {'label': 'Zoll/Chairre',               'icon': Icons.straighten},
    {'label': 'Hypothermia',                'icon': Icons.ac_unit},
    {'label': 'Pediatric',                  'icon': Icons.child_care_outlined},
    {'label': 'Reference values pressure',  'icon': Icons.table_chart_outlined},
    {'label': 'Heart Anatomy',              'icon': Icons.favorite_border},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimerDialog());
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  void _goToTab(int index) {
    Navigator.pop(context); // close drawer
    _tabController.animateTo(index);
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Disclaimer',
            style: TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dLine(Icons.warning_amber_rounded, _kGold,      'Not for clinical use!', bold: true),
            _dLine(Icons.school_outlined,       Colors.white70, 'Only for education!'),
            _dLine(Icons.person_outline,        Colors.white70, 'Only for personal use!'),
            _dLine(Icons.info_outline,          Colors.white70, 'No guarantee of the results!'),
            const Divider(color: Colors.white24, height: 24),
            const Text('Legal Notice',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text(
              'All content and tools are for educational use only, are not meant to be a '
              'substitute for professional advice and should not be used for medical diagnosis '
              'and/or medical treatment.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            const Text(
              'Reliance on or use of any information obtained through this Application is '
              'solely at your own risk. We are not responsible or liable for any outcome based '
              'on your decision to utilise the information provided through this application.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            const Text(
              'You are encouraged and instructed to confirm any information with other sources.',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic)),
          ]),
        ),
        actions: [TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('I understand',
              style: TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 15)),
        )],
      ),
    );
  }

  Widget _dLine(IconData icon, Color color, String text, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: TextStyle(color: color, fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
    ]),
  );

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Info',
            style: TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _iRow(Icons.tag,                 'Version', 'v$kAppVersion'),
          const SizedBox(height: 10),
          _iRow(Icons.gavel_outlined,      'License', 'GNU General Public License v3.0'),
          const SizedBox(height: 10),
          _iRow(Icons.smart_toy_outlined,  'Created', 'with \u{1F916} by ThePerfusionist'),
          const SizedBox(height: 10),
          _iRow(Icons.code,                'GitHub',  'github.com/ThePerfusionist/perfusioncalc'),
        ]),
        actions: [TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: _kGold)),
        )],
      ),
    );
  }

  Widget _iRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: _kGold, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ])),
    ],
  );

  // ── Drawer ─────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _kDark,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('PerfusionCalc',
                style: TextStyle(color: _kGold, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('Navigation',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _tabs.length,
              itemBuilder: (ctx, i) {
                final isActive = _tabController.index == i;
                return InkWell(
                  onTap: () => _goToTab(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive ? _kGold.withValues(alpha: 0.12) : Colors.transparent,
                      border: isActive
                          ? const Border(left: BorderSide(color: _kGold, width: 3))
                          : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(children: [
                      Icon(_tabs[i]['icon'] as IconData,
                          color: isActive ? _kGold : Colors.white54, size: 20),
                      const SizedBox(width: 14),
                      Expanded(child: Text(_tabs[i]['label'] as String,
                          style: TextStyle(
                            color: isActive ? _kGold : Colors.white70,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ))),
                      if (isActive)
                        const Icon(Icons.chevron_right, color: _kGold, size: 18),
                    ]),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('v$kAppVersion',
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ),
        ]),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          // Burger menu — left
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Text('PerfusionCalc', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          // Info button
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoDialog,
          ),
          // Close button — rightmost
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => SystemNavigator.pop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: _kDark,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: _kGold,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: _tabs.map((t) => Tab(text: t['label'] as String)).toList(),
            ),
          ),
        ),
      ),
      body: _webResponsiveBody(
        TabBarView(
          controller: _tabController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            BSAScreen(patientData: _patientData, onChanged: () => setState(() {})),
            O2DeliveryScreen(patientData: _patientData, onChanged: () => setState(() {})),
            ResistancesScreen(patientData: _patientData, onChanged: () => setState(() {})),
            ElectrolytesScreen(patientData: _patientData, onChanged: () => setState(() {})),
            TubeVolumeScreen(patientData: _patientData, onChanged: () => setState(() {})),
            const FlowDrainageScreen(),
            ZollChairreScreen(patientData: _patientData, onChanged: () => setState(() {})),
            const HypothermiaScreen(),
            PediatricScreen(patientData: _patientData, onChanged: () => setState(() {})),
            const ReferencePressureScreen(),
            const HeartAnatomyScreen(),
          ],
        ),
      ),
    );
  }

  // ── Responsive wrapper: constrains width on wide screens (web/tablet) ─────
  Widget _webResponsiveBody(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On wide screens center the content in a max-width column
        if (constraints.maxWidth > 640) {
          return Row(children: [
            Expanded(
              child: Container(color: const Color(0xFF1A1A1A)),
            ),
            SizedBox(
              width: 600,
              child: child,
            ),
            Expanded(
              child: Container(color: const Color(0xFF1A1A1A)),
            ),
          ]);
        }
        // On narrow screens (phone/tablet portrait) use full width
        return child;
      },
    );
  }
