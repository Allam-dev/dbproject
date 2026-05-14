import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';

class AddEventScreen extends StatefulWidget {
  final int? editId;
  const AddEventScreen({super.key, this.editId});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _longCtrl = TextEditingController();
  String _status = 'active';
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _allSkills = [];
  Set<int> _selectedSkillIds = {};
  bool _loading = true;
  bool _saving = false;
  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _latCtrl.dispose();
    _longCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final c = await DBHelper().connection;
      final sr = await c.mappedResultsQuery('SELECT id,name,category FROM SKILL ORDER BY category,name');
      _allSkills = sr.map((r) { final s = r.values.first; return {'id': s['id'], 'name': s['name'], 'category': s['category']}; }).toList();

      if (_isEdit) {
        final er = await c.mappedResultsQuery('SELECT description,lat,long,status,start_date,end_date FROM DISASTEREVENT WHERE id=@id', substitutionValues: {'id': widget.editId});
        if (er.isNotEmpty) {
          final e = er.first.values.first;
          _descCtrl.text = e['description']?.toString() ?? '';
          _latCtrl.text = e['lat']?.toString() ?? '';
          _longCtrl.text = e['long']?.toString() ?? '';
          _status = e['status']?.toString() ?? 'active';
          _startDate = e['start_date'] is DateTime ? e['start_date'] : null;
          _endDate = e['end_date'] is DateTime ? e['end_date'] : null;
        }
        final skr = await c.mappedResultsQuery('SELECT skill_id FROM DISASTEREVENT_SKILLS WHERE event_id=@id', substitutionValues: {'id': widget.editId});
        _selectedSkillIds = skr.map((r) => r.values.first['skill_id'] as int).toSet();
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) setState(() { if (isStart) _startDate = d; else _endDate = d; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start date is required'))); return; }
    setState(() => _saving = true);
    try {
      final c = await DBHelper().connection;
      await c.transaction((t) async {
        if (_isEdit) {
          await t.query('UPDATE DISASTEREVENT SET description=@d,lat=@la,long=@lo,status=@s,start_date=@sd,end_date=@ed WHERE id=@id', substitutionValues: {
            'd': _descCtrl.text.trim(), 'la': double.tryParse(_latCtrl.text), 'lo': double.tryParse(_longCtrl.text),
            's': _status, 'sd': _startDate, 'ed': _endDate, 'id': widget.editId,
          });
          await t.query('DELETE FROM DISASTEREVENT_SKILLS WHERE event_id=@id', substitutionValues: {'id': widget.editId});
          for (final sid in _selectedSkillIds) {
            await t.query('INSERT INTO DISASTEREVENT_SKILLS(event_id,skill_id) VALUES(@id,@sid)', substitutionValues: {'id': widget.editId, 'sid': sid});
          }
        } else {
          final res = await t.query('INSERT INTO DISASTEREVENT(description,lat,long,status,start_date,end_date) VALUES(@d,@la,@lo,@s,@sd,@ed) RETURNING id', substitutionValues: {
            'd': _descCtrl.text.trim(), 'la': double.tryParse(_latCtrl.text), 'lo': double.tryParse(_longCtrl.text),
            's': _status, 'sd': _startDate, 'ed': _endDate,
          });
          final newId = res.first[0] as int;
          for (final sid in _selectedSkillIds) {
            await t.query('INSERT INTO DISASTEREVENT_SKILLS(event_id,skill_id) VALUES(@id,@sid)', substitutionValues: {'id': newId, 'sid': sid});
          }
        }
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Updated!' : 'Created!'))); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('MMM d, yyyy');
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Event' : 'Add Event'), backgroundColor: cs.inversePrimary),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description), alignLabelWithHint: true), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null, maxLines: 5, minLines: 3, keyboardType: TextInputType.multiline),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(controller: _latCtrl, decoration: const InputDecoration(labelText: 'Latitude', prefixIcon: Icon(Icons.location_on)), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _longCtrl, decoration: const InputDecoration(labelText: 'Longitude', prefixIcon: Icon(Icons.location_on)), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline)), items: const [
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
          ], onChanged: (v) => setState(() => _status = v!)),
          const SizedBox(height: 16),
          // Dates
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(_startDate != null ? df.format(_startDate!) : 'Select Start Date'),
            subtitle: const Text('Start Date *'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outline.withValues(alpha: 0.3))),
            onTap: () => _pickDate(true),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.event),
            title: Text(_endDate != null ? df.format(_endDate!) : 'Select End Date (Optional)'),
            subtitle: const Text('End Date'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outline.withValues(alpha: 0.3))),
            onTap: () => _pickDate(false),
          ),
          const SizedBox(height: 24),
          Row(children: [Icon(Icons.build, color: cs.primary), const SizedBox(width: 8), const Text('Required Skills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          if (_allSkills.isEmpty) Text('No skills in database', style: TextStyle(color: cs.outline))
          else Wrap(spacing: 8, runSpacing: 4, children: _allSkills.map((s) {
            final id = s['id'] as int;
            final sel = _selectedSkillIds.contains(id);
            return FilterChip(label: Text('${s['name']} (${s['category']})'), selected: sel, onSelected: (v) => setState(() { if (v) _selectedSkillIds.add(id); else _selectedSkillIds.remove(id); }), selectedColor: cs.primaryContainer, checkmarkColor: cs.primary);
          }).toList()),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(_isEdit ? 'Update Event' : 'Create Event'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
