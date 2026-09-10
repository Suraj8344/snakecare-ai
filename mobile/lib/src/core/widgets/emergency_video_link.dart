import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Do not auto-load an unreliable third-party player in the emergency flow.
class EmergencyVideoLink extends StatelessWidget {
  const EmergencyVideoLink({required this.videoId, super.key});
  final String videoId;

  @override
  Widget build(BuildContext context) {
    final url = 'https://www.youtube.com/watch?v=$videoId';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.ondemand_video, size: 38),
          const SizedBox(height: 12),
          const Text(
            'Optional educational video',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open in YouTube or your browser. Internet is required. '
            'If playback is unavailable, use the written steps in this app. '
            'Do not delay emergency care to watch a video.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              var opened = false;
              try {
                opened = await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                // A missing URL handler should not interrupt emergency tools.
              }
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open YouTube. Copy the link or use the written guide.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Watch on YouTube'),
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video link copied')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: SelectableText(url)),
                  );
                }
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy video link'),
          ),
        ],
      ),
    );
  }
}
