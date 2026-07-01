import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/media_item.dart';

/// Guía de programación completa de un canal: lista de programas con su franja,
/// agrupados por día, resaltando el que está en emisión ahora.
class ChannelGuideScreen extends ConsumerWidget {
  final MediaItem channel;
  const ChannelGuideScreen({super.key, required this.channel});

  static const _dias = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
  ];

  String _dayLabel(DateTime d) =>
      '${_dias[d.weekday - 1]} ${d.day}/${d.month}';
  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(channelGuideProvider(channel.streamUrl));
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text('Guía · ${channel.name}')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _Empty(),
        data: (entries) {
          if (entries.isEmpty) return const _Empty();
          // Construye la lista intercalando cabeceras de día.
          final rows = <Widget>[];
          DateTime? lastDay;
          for (final e in entries) {
            final day = DateTime(e.start.year, e.start.month, e.start.day);
            if (lastDay == null || day != lastDay) {
              lastDay = day;
              rows.add(Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(_dayLabel(day),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ));
            }
            final onNow = now.isAfter(e.start) && now.isBefore(e.end);
            rows.add(ListTile(
              dense: true,
              leading: Text('${_hhmm(e.start)}\n${_hhmm(e.end)}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          onNow ? FontWeight.bold : FontWeight.normal)),
              title: Text(e.title,
                  style: TextStyle(
                      fontWeight:
                          onNow ? FontWeight.bold : FontWeight.normal)),
              subtitle: onNow ? const Text('En emisión ahora') : null,
              tileColor: onNow
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ));
          }
          return ListView(children: rows);
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin guía de programación disponible',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
}
