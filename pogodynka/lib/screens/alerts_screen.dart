import 'package:flutter/material.dart';
import '../models.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() {
    return _AlertsScreenState();
  }
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<AlertUiModel> _alerts = [
    AlertUiModel(
      title: 'Silny wiatr',
      description: 'Powiadom, gdy prędkość wiatru przekroczy 15 m/s.',
      isEnabled: true,
    ),
    AlertUiModel(
      title: 'Spadek ciśnienia',
      description: 'Alert przy gwałtownym spadku ciśnienia > 5 hPa / 3h.',
      isEnabled: false,
    ),
    AlertUiModel(
      title: 'Temperatura poniżej 0°C',
      description: 'Ostrzeżenie o możliwym oblodzeniu pokładu / drogi.',
      isEnabled: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('Alerty i progi'),
          automaticallyImplyLeading: false,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              for (final alert in _alerts)
                _AlertCard(
                  title: alert.title,
                  description: alert.description,
                  value: alert.isEnabled,
                  onChanged: (val) {
                    setState(() {
                      alert.isEnabled = val;
                    });
                  },
                ),
              const SizedBox(height: 24),
              const _InfoBox(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AlertCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFEAB308),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: Colors.white70),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Alerty są wysyłane, gdy zmierzone wartości przekroczą ustawione progi. '
                  'W rzeczywistym systemie tutaj można skonfigurować kanały powiadomień (push, e-mail itp.).',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }


}
