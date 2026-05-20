import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  final List<Map<String, dynamic>> _playlists = const [
    {'name': 'Mes favoris', 'count': 42, 'icon': Icons.favorite},
    {'name': 'Récemment écouté', 'count': 15, 'icon': Icons.history},
    {'name': 'Téléchargés', 'count': 28, 'icon': Icons.download_done},
    {'name': 'Playlist du soir', 'count': 12, 'icon': Icons.nights_stay},
    {'name': 'Workout Mix', 'count': 20, 'icon': Icons.fitness_center},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _playlists.length,
        separatorBuilder: (_, _) => const Divider(color: Colors.white10),
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                playlist['icon'] as IconData,
                color: AppTheme.primary,
              ),
            ),
            title: Text(
              playlist['name'] as String,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${playlist['count']} titres',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {},
          );
        },
      ),
    );
  }
}
