import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  Map<String, List<Map<String, dynamic>>> _grouped = {};
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
      final r = await c.mappedResultsQuery('SELECT id,name,category FROM SKILL ORDER BY category,name');
      final skills = r.map((row) {
        final s = row.values.first;
        return {'id': s['id'], 'name': s['name'], 'category': s['category']};
      }).toList();

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final s in skills) {
        final cat = s['category']?.toString() ?? 'Other';
        grouped.putIfAbsent(cat, () => []).add(s);
      }
      setState(() {
        _grouped = grouped;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addSkill() async {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.add_circle, size: 40),
        title: const Text('Add Skill'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Skill Name', prefixIcon: Icon(Icons.build)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: catCtrl,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final c = await DBHelper().connection;
      await c.query(
        'INSERT INTO SKILL(name,category) VALUES(@n,@c)',
        substitutionValues: {'n': nameCtrl.text.trim(), 'c': catCtrl.text.trim()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skill added!')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteSkill(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Skill?'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final c = await DBHelper().connection;
      await c.transaction((t) async {
        await t.query('DELETE FROM VOLUNTEER_SKILLS WHERE skill_id=@id', substitutionValues: {'id': id});
        await t.query('DELETE FROM DISASTEREVENT_SKILLS WHERE skill_id=@id', substitutionValues: {'id': id});
        await t.query('DELETE FROM SKILL WHERE id=@id', substitutionValues: {'id': id});
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'))); _load(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = _grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.inversePrimary,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _grouped.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.build_outlined, size: 80, color: cs.outline),
                  const SizedBox(height: 16),
                  Text('No skills found', style: TextStyle(fontSize: 18, color: cs.outline)),
                  const SizedBox(height: 8),
                  Text('Tap + to add one', style: TextStyle(color: cs.outline)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: categories.length,
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      final skills = _grouped[cat]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(children: [
                              Icon(Icons.category, size: 18, color: cs.primary),
                              const SizedBox(width: 8),
                              Text(cat, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary, letterSpacing: 0.5)),
                            ]),
                          ),
                          ...skills.map((s) => Card(
                            child: ListTile(
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.bolt, color: cs.primary),
                              ),
                              title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(cat, style: TextStyle(fontSize: 12, color: cs.outline)),
                              trailing: IconButton(icon: Icon(Icons.delete_outline, color: cs.error), onPressed: () => _deleteSkill(s['id'] as int, s['name']?.toString() ?? '')),
                            ),
                          )),
                        ],
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSkill,
        icon: const Icon(Icons.add),
        label: const Text('Add Skill'),
      ),
    );
  }
}
