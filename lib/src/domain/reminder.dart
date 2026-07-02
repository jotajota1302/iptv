/// Recordatorio de un programa de TV: avisa cuando va a empezar.
class Reminder {
  final String channelName;
  final String channelUrl;
  final String title;
  final DateTime start;
  const Reminder({
    required this.channelName,
    required this.channelUrl,
    required this.title,
    required this.start,
  });

  String get id => '$channelUrl@${start.millisecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
        'channel': channelName,
        'url': channelUrl,
        'title': title,
        'start': start.millisecondsSinceEpoch,
      };

  static Reminder fromJson(Map<String, dynamic> json) => Reminder(
        channelName: '${json['channel'] ?? ''}',
        channelUrl: '${json['url'] ?? ''}',
        title: '${json['title'] ?? ''}',
        start: DateTime.fromMillisecondsSinceEpoch(
            json['start'] is int ? json['start'] as int : 0),
      );
}
