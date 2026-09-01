import 'package:flutter/material.dart';

import '../../models/time_clock_entry.dart';
import '../../services/time_clock_repository.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';

class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({super.key});

  @override
  State<TimeClockScreen> createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen> {
  final TimeClockRepository _repository = TimeClockRepository();
  TimeClockEntry? _openEntry;
  List<TimeClockEntry> _history = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.getMyOpenEntry(),
        _repository.getMyHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _openEntry = results[0] as TimeClockEntry?;
        _history = results[1] as List<TimeClockEntry>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el reloj de entrada/salida';
        _loading = false;
      });
    }
  }

  Future<void> _toggleClock() async {
    setState(() => _submitting = true);
    try {
      if (_openEntry != null) {
        await _repository.clockOut(_openEntry!.id);
      } else {
        await _repository.clockIn();
      }
      await _load();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return '${hours}h ${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final isClockedIn = _openEntry != null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: isClockedIn ? Colors.green.withOpacity(0.1) : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    isClockedIn ? Icons.timer : Icons.timer_off_outlined,
                    size: 48,
                    color: isClockedIn ? Colors.green : Colors.grey.shade700,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isClockedIn
                        ? 'Trabajando desde las ${formatTimeEs(_openEntry!.clockIn)}'
                        : 'No has marcado entrada',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _toggleClock,
                    style: FilledButton.styleFrom(
                      backgroundColor: isClockedIn ? Colors.red : Colors.green,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: Icon(isClockedIn ? Icons.logout : Icons.login),
                    label: Text(isClockedIn ? 'Marcar salida' : 'Marcar entrada'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Historial', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Todavía no tienes marcaciones'),
            )
          else
            ..._history.map((entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(formatDayHeaderEs(entry.clockIn)),
                  subtitle: Text(
                    entry.isOpen
                        ? 'Entrada ${formatTimeEs(entry.clockIn)} · en curso'
                        : 'Entrada ${formatTimeEs(entry.clockIn)} · Salida ${formatTimeEs(entry.clockOut!)}',
                  ),
                  trailing: Text(_formatDuration(entry.duration)),
                )),
        ],
      ),
    );
  }
}
