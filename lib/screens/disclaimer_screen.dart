import 'package:flutter/material.dart';
import '../widgets/common.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            width: double.infinity,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _disclaimerRow('Disclaimer:', bold: true),
                const Divider(color: Colors.white12, height: 1),
                _disclaimerRow('Not for clinical use!'),
                const Divider(color: Colors.white12, height: 1),
                _disclaimerRow('Only for education!'),
                const Divider(color: Colors.white12, height: 1),
                _disclaimerRow('Only for personal use!'),
                const Divider(color: Colors.white12, height: 1),
                _disclaimerRow('No guarantee of the results!'),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showContactDialog(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: kCardColor, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Contact',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.info_outline, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _disclaimerRow(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(text,
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Contact',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: const Text(
          'PerfusionCalc\nFor educational purposes only.',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
