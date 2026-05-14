import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../widgets/status_badge.dart';
import 'event_detail_screen.dart';
import 'add_event_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await DBHelper().connection;
      final r = await c.mappedResultsQuery('SELECT id,description,status,start_date,end_date,lat,long FROM DISASTEREVENT ORDER BY start_date DESC');
      _events = r.map((row) {
        final e = row.values.first;
        return {'id': e['id'], 'description': e['description'], 'status': e['status'], 'start_date': e['start_date'], 'end_date': e['end_date'], 'lat': e['lat'], 'long': e['long']};
      }).toList();
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '—';
    if (d is DateTime) return DateFormat('MMM d, yyyy').format(d);
    return d.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Events', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.inversePrimary,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber, size: 80, color: cs.outline),
                  const SizedBox(height: 16),
                  Text('No events found', style: TextStyle(fontSize: 18, color: cs.outline)),
                  const SizedBox(height: 8),
                  Text('Tap + to add one', style: TextStyle(color: cs.outline)),
                ]))
              : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: _events.length,
                  itemBuilder: (context, i) {
                    final e = _events[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e['id'] as int)));
                          _load();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: (e['status'] == 'active' ? Colors.red : Colors.green).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              e['status'] == 'active' ? Icons.warning_amber : Icons.check_circle,
                              color: e['status'] == 'active' ? Colors.red : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e['description'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.calendar_today, size: 14, color: cs.outline),
                              const SizedBox(width: 4),
                              Text(_formatDate(e['start_date']), style: TextStyle(fontSize: 13, color: cs.outline)),
                            ]),
                          ])),
                          StatusBadge(status: e['status']?.toString() ?? 'unknown'),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: cs.outline),
                        ])),
                      ),
                    );
                  },
                )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEventScreen())); _load(); },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Event'),
      ),
    );
  }
}
