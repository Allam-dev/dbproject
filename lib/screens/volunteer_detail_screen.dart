import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../widgets/status_badge.dart';
import '../widgets/skill_chip.dart';
import 'add_volunteer_screen.dart';

class VolunteerDetailScreen extends StatefulWidget {
  final String ssn;
  const VolunteerDetailScreen({super.key, required this.ssn});

  @override
  State<VolunteerDetailScreen> createState() => _VolunteerDetailScreenState();
}

class _VolunteerDetailScreenState extends State<VolunteerDetailScreen> {
  Map<String, dynamic>? _vol;
  List<String> _phones = [];
  List<Map<String, dynamic>> _skills = [];
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
      final vr = await c.mappedResultsQuery(
        'SELECT v.ssn,v.name,v.status,v.id as event_id,d.description as event FROM VOLUNTEER v LEFT JOIN DISASTEREVENT d ON v.id=d.id WHERE v.ssn=@s',
        substitutionValues: {'s': widget.ssn},
      );
      if (vr.isNotEmpty) {
        final v = vr.first.values.first;
        final d = vr.first.values.last;
        _vol = {'ssn': v['ssn'], 'name': v['name'], 'status': v['status'], 'event_id': v['event_id'], 'event': d['event'] ?? d['description']};
      }
      final pr = await c.mappedResultsQuery('SELECT phone FROM VOLUNTEER_PHONE WHERE ssn=@s', substitutionValues: {'s': widget.ssn});
      _phones = pr.map((r) => r.values.first['phone']?.toString() ?? '').toList();
      final sr = await c.mappedResultsQuery('SELECT s.name,s.category FROM SKILL s JOIN VOLUNTEER_SKILLS vs ON s.id=vs.skill_id WHERE vs.ssn=@s', substitutionValues: {'s': widget.ssn});
      _skills = sr.map((r) { final s = r.values.first; return {'name': s['name'], 'category': s['category']}; }).toList();
      final er = await c.mappedResultsQuery("SELECT id,description FROM DISASTEREVENT WHERE status='active'");
      _events = er.map((r) { final e = r.values.first; return {'id': e['id'], 'description': e['description']}; }).toList();
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
      title: const Text('Delete Volunteer?'),
      content: Text('Delete ${_vol?['name']}? This cannot be undone.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))],
    ));
    if (ok != true) return;
    try {
      final c = await DBHelper().connection;
      await c.transaction((t) async {
        await t.query('DELETE FROM VOLUNTEER_PHONE WHERE ssn=@s', substitutionValues: {'s': widget.ssn});
        await t.query('DELETE FROM VOLUNTEER_SKILLS WHERE ssn=@s', substitutionValues: {'s': widget.ssn});
        await t.query('DELETE FROM VOLUNTEER WHERE ssn=@s', substitutionValues: {'s': widget.ssn});
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'))); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _assign() async {
    if (_vol?['status'] == 'inactive') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inactive volunteers cannot be assigned to events'))); return; }
    if (_events.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active events'))); return; }
    int? sel = _vol?['event_id'];
    final res = await showDialog<int?>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: const Text('Assign to Event'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ..._events.map((e) => RadioListTile<int>(title: Text(e['description'] ?? ''), value: e['id'] as int, groupValue: sel, onChanged: (v) => ss(() => sel = v))),
        RadioListTile<int>(title: const Text('Unassign', style: TextStyle(fontStyle: FontStyle.italic)), value: -1, groupValue: sel ?? -1, onChanged: (v) => ss(() => sel = null)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, sel ?? -1), child: const Text('Assign'))],
    )));
    if (res == null) return;
    try {
      final c = await DBHelper().connection;
      await c.query('UPDATE VOLUNTEER SET id=@e WHERE ssn=@s', substitutionValues: {'e': res == -1 ? null : res, 's': widget.ssn});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated'))); _load(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_vol?['name'] ?? 'Details'), backgroundColor: cs.inversePrimary, actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: _vol == null ? null : () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => AddVolunteerScreen(editSsn: widget.ssn))); _load(); }),
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
      ]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _vol == null ? const Center(child: Text('Not found')) : ListView(padding: const EdgeInsets.all(16), children: [
        // Info card
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          CircleAvatar(radius: 40, backgroundColor: cs.primaryContainer, child: Text((_vol!['name'] ?? 'V')[0].toUpperCase(), style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer))),
          const SizedBox(height: 12),
          Text(_vol!['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('SSN: ${_vol!['ssn']}', style: TextStyle(fontSize: 14, color: cs.outline)),
          const SizedBox(height: 12),
          StatusBadge(status: _vol!['status']?.toString() ?? 'unknown'),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.assignment, size: 16, color: cs.primary), const SizedBox(width: 6),
            Text(_vol!['event']?.toString() ?? 'Unassigned', style: TextStyle(fontWeight: FontWeight.w500, color: _vol!['event'] != null ? cs.primary : cs.outline)),
          ]),
        ]))),
        const SizedBox(height: 16),
        // Phones
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.phone, color: cs.primary), const SizedBox(width: 8), const Text('Phone Numbers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const Divider(height: 24),
          if (_phones.isEmpty) Text('No phone numbers', style: TextStyle(color: cs.outline, fontStyle: FontStyle.italic))
          else ..._phones.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(Icons.phone_android, size: 18, color: cs.outline), const SizedBox(width: 8), Text(p)]))),
        ]))),
        const SizedBox(height: 16),
        // Skills
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.build, color: cs.primary), const SizedBox(width: 8), const Text('Skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const Divider(height: 24),
          if (_skills.isEmpty) Text('No skills', style: TextStyle(color: cs.outline, fontStyle: FontStyle.italic))
          else Wrap(spacing: 8, runSpacing: 4, children: _skills.map((s) => SkillChip(name: s['name'], category: s['category'])).toList()),
        ]))),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _vol?['status'] == 'inactive' ? null : _assign,
          icon: const Icon(Icons.assignment_turned_in),
          label: Text(_vol?['status'] == 'inactive' ? 'Inactive — Cannot Assign' : 'Assign to Event'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }
}
