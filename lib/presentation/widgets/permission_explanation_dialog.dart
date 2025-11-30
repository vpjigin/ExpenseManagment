import 'package:flutter/material.dart';

/// Dialog explaining why SMS permission is needed
class PermissionExplanationDialog extends StatelessWidget {
  final VoidCallback onGrantPermission;
  final VoidCallback onSkip;

  const PermissionExplanationDialog({
    super.key,
    required this.onGrantPermission,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.message, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text('SMS Permission Required'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why we need SMS access:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              icon: Icons.auto_awesome,
              title: 'Automatic Expense Detection',
              description:
                  'We read incoming SMS messages to automatically detect and record your expenses from bank notifications, UPI transactions, and payment confirmations.',
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.sync,
              title: 'Works in Background',
              description:
                  'The app can detect expenses even when it\'s closed, so you never miss tracking a transaction.',
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.security,
              title: 'Your Privacy Matters',
              description:
                  'We only read SMS messages to extract expense information. All data stays on your device and is never shared.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can change this permission anytime in Settings.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onSkip,
          child: const Text('Skip for Now'),
        ),
        ElevatedButton(
          onPressed: onGrantPermission,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Grant Permission'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
