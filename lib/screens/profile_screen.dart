import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _Avatar(),
            const SizedBox(height: 16),
            const Text(
              'Charles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '@chouflheure',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _StatsRow(),
            const SizedBox(height: 32),
            _MenuSection(),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFF9B59B6)],
            ),
          ),
          child: const Icon(Icons.person, size: 50, color: Colors.white),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.edit, size: 14, color: Colors.white),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(value: '128', label: 'Titres'),
        _Divider(),
        _Stat(value: '14', label: 'Playlists'),
        _Divider(),
        _Stat(value: '320h', label: 'Écouté'),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Colors.white12);
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}

class _MenuSection extends StatelessWidget {
  final List<Map<String, dynamic>> _items = const [
    {'icon': Icons.favorite_outline, 'label': 'Mes favoris'},
    {'icon': Icons.history, 'label': 'Historique'},
    {'icon': Icons.notifications_outlined, 'label': 'Notifications'},
    {'icon': Icons.help_outline, 'label': 'Aide'},
    {'icon': Icons.logout, 'label': 'Déconnexion'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final item = _items[index];
          final isLast = index == _items.length - 1;
          return ListTile(
            leading: Icon(
              item['icon'] as IconData,
              color: isLast ? Colors.redAccent : Colors.white70,
            ),
            title: Text(
              item['label'] as String,
              style: TextStyle(color: isLast ? Colors.redAccent : Colors.white),
            ),
            trailing: isLast
                ? null
                : const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            onTap: () {},
          );
        },
      ),
    );
  }
}
