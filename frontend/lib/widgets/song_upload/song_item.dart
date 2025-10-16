import 'package:flutter/material.dart';
import 'song_model.dart';

class SongItem extends StatelessWidget {
  final Song song;
  final VoidCallback onPlay;

  const SongItem({super.key, required this.song, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: IconButton(
            icon: Icon(
              Icons.play_circle_outline,
              color: Colors.grey[800],
              size: 24,
            ),
            onPressed: onPlay,
          ),
          title: Text(
            song.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "${song.url}",
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }
}
