import 'package:flutter/material.dart';
import '../widgets/common.dart';

class ReferenceValuesScreen extends StatelessWidget {
  const ReferenceValuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          GoldListCard(items: const [
            'CaO₂: 18–20 ml O₂/dl',
            'CvO₂: 14–15 ml O₂/dl',
            'Ca–vDO₂: 4–6 ml/dl',
            'DO₂i: >272 ml/min/m²',
            'VO₂i: 120–160 ml/min/m²',
            'O₂–ER: 22–35%',
            'SVR: 900–1200 dyns/cm⁵',
            'PVR: 150–300 dyns/cm⁵',
            'Sodium: 135–145 mmol',
            'Potassium: 3,5–5,0 mmol',
            'Calcium: 1,15–1,29 mmol',
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
