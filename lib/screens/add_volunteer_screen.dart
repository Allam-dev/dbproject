import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class AddVolunteerScreen extends StatefulWidget {
  final String? editSsn;
  const AddVolunteerScreen({super.key, this.editSsn});

  @override
  State<AddVolunteerScreen> createState() => _AddVolunteerScreenState();
}

class _AddVolunteerScreenState extends State<AddVolunteerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssnCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _status = 'available';
  List<Map<String, dynamic>> _allSkills = [];
  Set<int> _selectedSkillIds = {};
  List<TextEditingController> _phoneControllers = [TextEditingController()];
  List<Map<String, dynamic>> _allEvents = [];
  int? _selectedEventId;
  bool _loading = true;
  bool _saving = false;
  bool get _isEdit => widget.editSsn != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _ssnCtrl.dispose();
    _nameCtrl.dispose();
    for (final c in _phoneControllers) c.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final conn = await DBHelper().connection;
      // Load skills
      final sr = await conn.mappedResultsQuery('SELECT id,name,category FROM SKILL ORDER BY category,name');
      _allSkills = sr.map((r) { final s = r.values.first; return {'id': s['id'], 'name': s['name'], 'category': s['category']}; }).toList();
      // Load events
      final er = await conn.mappedResultsQuery("SELECT id,description FROM DISASTEREVENT WHERE status='active' ORDER BY description");
      _allEvents = er.map((r) { final e = r.values.first; return {'id': e['id'], 'description': e['description']}; }).toList();

      if (_isEdit) {
        final vr = await conn.mappedResultsQuery('SELECT ssn,name,status,id as event_id FROM VOLUNTEER WHERE ssn=@s', substitutionValues: {'s': widget.editSsn});
        if (vr.isNotEmpty) {
          final v = vr.first.values.first;
          _ssnCtrl.text = v['ssn']?.toString() ?? '';
          _nameCtrl.text = v['name']?.toString() ?? '';
          _status = v['status']?.toString() ?? 'available';
          _selectedEventId = v['event_id'] as int?;
        }
        // Load existing skills
        final skr = await conn.mappedResultsQuery('SELECT skill_id FROM VOLUNTEER_SKILLS WHERE ssn=@s', substitutionValues: {'s': widget.editSsn});
        _selectedSkillIds = skr.map((r) => r.values.first['skill_id'] as int).toSet();
        // Load existing phones
        final pr = await conn.mappedResultsQuery('SELECT phone FROM VOLUNTEER_PHONE WHERE ssn=@s', substitutionValues: {'s': widget.editSsn});
        if (pr.isNotEmpty) {
          _phoneControllers = pr.map((r) => TextEditingController(text: r.values.first['phone']?.toString())).toList();
        }
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final conn = await DBHelper().connection;
      final ssn = _ssnCtrl.text.trim();
      final name = _nameCtrl.text.trim();

      await conn.transaction((t) async {
        if (_isEdit) {
          await t.query('UPDATE VOLUNTEER SET name=@n,status=@st,id=@eid WHERE ssn=@s', substitutionValues: {'n': name, 'st': _status, 'eid': _selectedEventId, 's': ssn});
          await t.query('DELETE FROM VOLUNTEER_PHONE WHERE ssn=@s', substitutionValues: {'s': ssn});
          await t.query('DELETE FROM VOLUNTEER_SKILLS WHERE ssn=@s', substitutionValues: {'s': ssn});
        } else {
          await t.query('INSERT INTO VOLUNTEER(ssn,name,status,id) VALUES(@s,@n,@st,@eid)', substitutionValues: {'s': ssn, 'n': name, 'st': _status, 'eid': _selectedEventId});
        }
        // Insert phones
        for (final pc in _phoneControllers) {
          final phone = pc.text.trim();
          if (phone.isNotEmpty) {
            await t.query('INSERT INTO VOLUNTEER_PHONE(phone,ssn) VALUES(@p,@s)', substitutionValues: {'p': phone, 's': ssn});
          }
        }
        // Insert skills
        for (final sid in _selectedSkillIds) {
          await t.query('INSERT INTO VOLUNTEER_SKILLS(ssn,skill_id) VALUES(@s,@sid)', substitutionValues: {'s': ssn, 'sid': sid});
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Updated!' : 'Added!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Volunteer' : 'Add Volunteer'), backgroundColor: cs.inversePrimary),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // SSN
          TextFormField(
            controller: _ssnCtrl,
            decoration: const InputDecoration(labelText: 'SSN', prefixIcon: Icon(Icons.badge)),
            enabled: !_isEdit,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          // Name
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          // Status
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline)),
            items: const [
              DropdownMenuItem(value: 'available', child: Text('Available')),
              DropdownMenuItem(value: 'deployed', child: Text('Deployed')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (v) => setState(() { _status = v!; if (_status == 'inactive') _selectedEventId = null; }),
          ),
          const SizedBox(height: 16),
          // Event assignment
          DropdownButtonFormField<int?>(
            value: _selectedEventId,
            decoration: InputDecoration(
              labelText: _status == 'inactive' ? 'Assign to Event (Inactive volunteers cannot be assigned)' : 'Assign to Event',
              prefixIcon: const Icon(Icons.warning_amber),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
              ..._allEvents.map((e) => DropdownMenuItem<int?>(value: e['id'] as int, child: Text(e['description'] ?? ''))),
            ],
            onChanged: _status == 'inactive' ? null : (v) => setState(() => _selectedEventId = v),
          ),
          const SizedBox(height: 24),
          // Phone Numbers
          Row(children: [
            Icon(Icons.phone, color: cs.primary), const SizedBox(width: 8),
            const Text('Phone Numbers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _phoneControllers.add(TextEditingController()))),
          ]),
          const SizedBox(height: 8),
          ..._phoneControllers.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: TextFormField(controller: entry.value, decoration: InputDecoration(labelText: 'Phone ${entry.key + 1}', prefixIcon: const Icon(Icons.phone_android)))),
              if (_phoneControllers.length > 1) IconButton(icon: Icon(Icons.remove_circle, color: cs.error), onPressed: () => setState(() { _phoneControllers[entry.key].dispose(); _phoneControllers.removeAt(entry.key); })),
            ]),
          )),
          const SizedBox(height: 24),
          // Skills
          Row(children: [
            Icon(Icons.build, color: cs.primary), const SizedBox(width: 8),
            const Text('Skills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          if (_allSkills.isEmpty) Text('No skills in database', style: TextStyle(color: cs.outline))
          else Wrap(spacing: 8, runSpacing: 4, children: _allSkills.map((s) {
            final id = s['id'] as int;
            final sel = _selectedSkillIds.contains(id);
            return FilterChip(
              label: Text('${s['name']} (${s['category']})'),
              selected: sel,
              onSelected: (v) => setState(() { if (v) _selectedSkillIds.add(id); else _selectedSkillIds.remove(id); }),
              selectedColor: cs.primaryContainer,
              checkmarkColor: cs.primary,
            );
          }).toList()),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(_isEdit ? 'Update Volunteer' : 'Add Volunteer'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
