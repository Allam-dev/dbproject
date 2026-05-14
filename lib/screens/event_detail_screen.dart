import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../widgets/status_badge.dart';
import '../widgets/skill_chip.dart';
import 'add_event_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _volunteers = [];
  List<String> _skills = [];
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
      final er = await c.mappedResultsQuery('SELECT id,description,lat,long,status,start_date,end_date FROM DISASTEREVENT WHERE id=@id', substitutionValues: {'id': widget.eventId});
      if (er.isNotEmpty) {
        final e = er.first.values.first;
        _event = {'id': e['id'], 'description': e['description'], 'lat': e['lat'], 'long': e['long'], 'status': e['status'], 'start_date': e['start_date'], 'end_date': e['end_date']};
      }
      final vr = await c.mappedResultsQuery('SELECT v.name,v.status FROM VOLUNTEER v WHERE v.id=@id', substitutionValues: {'id': widget.eventId});
      _volunteers = vr.map((r) { final v = r.values.first; return {'name': v['name'], 'status': v['status']}; }).toList();
      final sr = await c.mappedResultsQuery('SELECT s.name FROM SKILL s JOIN DISASTEREVENT_SKILLS ds ON s.id=ds.skill_id WHERE ds.event_id=@id', substitutionValues: {'id': widget.eventId});
      _skills = sr.map((r) => r.values.first['name']?.toString() ?? '').toList();
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
      title: const Text('Delete Event?'),
      content: const Text('This will unassign all volunteers. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try {
      final c = await DBHelper().connection;
      await c.transaction((t) async {
        await t.query('UPDATE VOLUNTEER SET id=NULL WHERE id=@id', substitutionValues: {'id': widget.eventId});
        await t.query('DELETE FROM DISASTEREVENT_SKILLS WHERE event_id=@id', substitutionValues: {'id': widget.eventId});
        await t.query('DELETE FROM DISASTEREVENT WHERE id=@id', substitutionValues: {'id': widget.eventId});
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'))); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  String _fmt(dynamic d) {
    if (d == null) return '—';
    if (d is DateTime) return DateFormat('MMM d, yyyy').format(d);
    return d.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_event?['description'] ?? 'Event Details'), backgroundColor: cs.inversePrimary, actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: _event == null ? null : () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEventScreen(editId: widget.eventId))); _load(); }),
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _event == null ? const Center(child: Text('Not found')) : ListView(padding: const EdgeInsets.all(16), children: [
        // Info
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: (_event!['status'] == 'active' ? Colors.red : Colors.green).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
              child: Icon(_event!['status'] == 'active' ? Icons.warning_amber : Icons.check_circle, size: 32, color: _event!['status'] == 'active' ? Colors.red : Colors.green)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_event!['description'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              StatusBadge(status: _event!['status']?.toString() ?? ''),
            ])),
          ]),
          const Divider(height: 32),
          _infoRow(Icons.calendar_today, 'Start', _fmt(_event!['start_date'])),
          _infoRow(Icons.event, 'End', _fmt(_event!['end_date'])),
          _infoRow(Icons.location_on, 'Location', '${_event!['lat'] ?? '—'}, ${_event!['long'] ?? '—'}'),
        ]))),
        const SizedBox(height: 16),
        // Required Skills
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.build, color: cs.primary), const SizedBox(width: 8), const Text('Required Skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const Divider(height: 24),
          if (_skills.isEmpty) Text('None specified', style: TextStyle(color: cs.outline, fontStyle: FontStyle.italic))
          else Wrap(spacing: 8, runSpacing: 4, children: _skills.map((s) => SkillChip(name: s)).toList()),
        ]))),
        const SizedBox(height: 16),
        // Assigned Volunteers
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.people, color: cs.primary), const SizedBox(width: 8), Text('Assigned Volunteers (${_volunteers.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const Divider(height: 24),
          if (_volunteers.isEmpty) Text('No volunteers assigned', style: TextStyle(color: cs.outline, fontStyle: FontStyle.italic))
          else ..._volunteers.map((v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: cs.primaryContainer, child: Text((v['name'] ?? 'V')[0].toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer))),
            const SizedBox(width: 12),
            Expanded(child: Text(v['name'] ?? '', style: const TextStyle(fontSize: 15))),
            StatusBadge(status: v['status']?.toString() ?? ''),
          ]))),
        ]))),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Icon(icon, size: 18, color: cs.outline), const SizedBox(width: 12),
      SizedBox(width: 60, child: Text(label, style: TextStyle(color: cs.outline, fontWeight: FontWeight.w500))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
    ]));
  }
}
