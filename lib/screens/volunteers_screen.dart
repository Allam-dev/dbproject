import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../widgets/status_badge.dart';
import 'volunteer_detail_screen.dart';
import 'add_volunteer_screen.dart';

class VolunteersScreen extends StatefulWidget {
  const VolunteersScreen({super.key});

  @override
  State<VolunteersScreen> createState() => _VolunteersScreenState();
}

class _VolunteersScreenState extends State<VolunteersScreen> {
  List<Map<String, dynamic>> _volunteers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVolunteers();
  }

  Future<void> _loadVolunteers() async {
    setState(() => _isLoading = true);
    try {
      final conn = await DBHelper().connection;
      final results = await conn.mappedResultsQuery('''
        SELECT v.ssn, v.name, v.status, d.description AS event
        FROM VOLUNTEER v
        LEFT JOIN DISASTEREVENT d ON v.id = d.id
        ORDER BY v.name
      ''');
      setState(() {
        _volunteers = results.map((row) {
          final v = row['volunteer'] ?? row['VOLUNTEER'] ?? {};
          final d = row['disasterevent'] ?? row['DISASTEREVENT'] ?? {};
          // Flatten from the mapped result
          return {
            'ssn': v['ssn'] ?? '',
            'name': v['name'] ?? '',
            'status': v['status'] ?? '',
            'event': d['event'] ?? d['description'] ?? 'Unassigned',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading volunteers: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Disaster Relief Registry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVolunteers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _volunteers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 80, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'No volunteers found',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add one',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVolunteers,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _volunteers.length,
                    itemBuilder: (context, index) {
                      final v = _volunteers[index];
                      return _VolunteerCard(
                        volunteer: v,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VolunteerDetailScreen(
                                ssn: v['ssn'].toString(),
                              ),
                            ),
                          );
                          _loadVolunteers();
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddVolunteerScreen()),
          );
          _loadVolunteers();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Volunteer'),
      ),
    );
  }
}

class _VolunteerCard extends StatelessWidget {
  final Map<String, dynamic> volunteer;
  final VoidCallback onTap;

  const _VolunteerCard({required this.volunteer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final event = volunteer['event'];
    final hasEvent = event != null && event.toString().isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  (volunteer['name'] ?? 'V')[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      volunteer['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SSN: ${volunteer['ssn']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.assignment,
                          size: 14,
                          color: hasEvent
                              ? colorScheme.primary
                              : colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hasEvent ? event.toString() : 'Unassigned',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: hasEvent
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                              color: hasEvent
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(
                  status: volunteer['status']?.toString() ?? 'unknown'),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
