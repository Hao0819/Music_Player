/// `2026-10-06 15:30`, in local time.
///
/// Spelled out rather than localised: the only dates the app shows are backup
/// timestamps, where being able to tell two of them apart at a glance matters
/// more than reading naturally, and `intl` is not a dependency here.
String formatTimestamp(DateTime time) {
  final local = time.toLocal();
  final date = [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('-');
  final clock = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  return '$date $clock';
}
