import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import 'channel_list_screen.dart';

class LiveTab extends ConsumerWidget {
  const LiveTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveCategoriesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cats) {
        if (cats.isEmpty) {
          return const Center(
              child: Text('Añade una lista en Ajustes para empezar'));
        }
        return ListView.builder(
          itemCount: cats.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(cats[i].name),
            trailing: Text('${cats[i].itemCount}'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChannelListScreen(category: cats[i]),
            )),
          ),
        );
      },
    );
  }
}
