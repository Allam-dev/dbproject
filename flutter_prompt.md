# Flutter App — Disaster Relief Volunteer Registry

## Project Overview
Build a Flutter desktop/mobile app connected to a local PostgreSQL database called `dbproject`.
The app manages disaster relief volunteers, their skills, and disaster event assignments.

---

## Database Connection
- Host: localhost
- Port: 5432
- Database: dbproject
- Use the `postgres` dart package for direct PostgreSQL connection.

Add to pubspec.yaml:
```yaml
dependencies:
  postgres: ^2.6.4
```

Connection singleton example:
```dart
import 'package:postgres/postgres.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  PostgreSQLConnection? _conn;

  Future<PostgreSQLConnection> get connection async {
    if (_conn == null || _conn!.isClosed) {
      _conn = PostgreSQLConnection('localhost', 5432, 'dbproject',
          username: 'postgres', password: 'YOUR_PASSWORD');
      await _conn!.open();
    }
    return _conn!;
  }
}
```

---

## Database Schema (already created — do NOT recreate)

```sql
SKILL          (id SERIAL PK, name, category)
DISASTEREVENT  (id SERIAL PK, description, lat, long, status, start_date, end_date)
VOLUNTEER      (ssn PK, name, status, id FK→DISASTEREVENT)
VOLUNTEER_PHONE(phone, ssn FK)          -- multivalued phone
VOLUNTEER_SKILLS(ssn FK, skill_id FK)  -- M:N
DISASTEREVENT_SKILLS(event_id FK, skill_id FK) -- M:N
```

---

## Required Screens

### 1. Home Screen
- Bottom navigation bar with 3 tabs: Volunteers | Events | Skills
- App title: "Disaster Relief Registry"

### 2. Volunteers Screen
- List all volunteers (ssn, name, status, assigned event name or "Unassigned")
- Query:
```sql
SELECT v.ssn, v.name, v.status, d.description AS event
FROM VOLUNTEER v
LEFT JOIN DISASTEREVENT d ON v.id = d.id;
```
- Floating action button to Add Volunteer
- Tap a volunteer to open Volunteer Detail Screen

### 3. Volunteer Detail Screen
- Shows volunteer info, their phone numbers, their skills
- Queries:
```sql
SELECT phone FROM VOLUNTEER_PHONE WHERE ssn = @ssn;
SELECT s.name, s.category FROM SKILL s
JOIN VOLUNTEER_SKILLS vs ON s.id = vs.skill_id WHERE vs.ssn = @ssn;
```
- Buttons: Edit, Delete, Assign to Event

### 4. Add / Edit Volunteer Screen
- Fields: SSN (text), Name (text), Status (dropdown: available/deployed/inactive)
- Multi-select checkboxes for Skills (loaded from SKILL table)
- Phone numbers: add/remove dynamically
- Assign to Event: dropdown of active DISASTEREVENT records
- Save runs INSERT or UPDATE + updates junction tables

### 5. Disaster Events Screen
- List all events (id, description, status, start_date)
- Tap to open Event Detail Screen
- FAB to Add Event

### 6. Event Detail Screen
- Shows event info (description, location coords, dates, status)
- Lists required skills for this event
- Lists volunteers assigned to this event
- Query:
```sql
SELECT v.name, v.status FROM VOLUNTEER v WHERE v.id = @event_id;
SELECT s.name FROM SKILL s
JOIN DISASTEREVENT_SKILLS ds ON s.id = ds.skill_id WHERE ds.event_id = @event_id;
```

### 7. Add / Edit Event Screen
- Fields: Description (text), Lat (number), Long (number), Status (dropdown: active/resolved), Start Date (date picker), End Date (date picker, optional)
- Multi-select for required Skills

### 8. Skills Screen
- Simple list of all skills grouped by category
- FAB to add a new skill (name + category)

---

## UI Style
- Use Material 3 design (useMaterial3: true)
- Color scheme: deep orange seed color (disaster/emergency theme)
- Status badges: green = available, orange = deployed, red = inactive / active event
- Use Card widgets for list items
- Show loading indicators while queries run
- Show SnackBar on success/error

---

## State Management
Use setState for simplicity (no need for Provider/Bloc for a college project).

---

## Error Handling
Wrap all DB calls in try/catch. Show error messages via SnackBar.
```dart
try {
  final conn = await DBHelper().connection;
  final results = await conn.query('SELECT ...');
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')));
}
```

---

## Folder Structure
```
lib/
  main.dart
  db/
    db_helper.dart
  screens/
    home_screen.dart
    volunteers_screen.dart
    volunteer_detail_screen.dart
    add_volunteer_screen.dart
    events_screen.dart
    event_detail_screen.dart
    add_event_screen.dart
    skills_screen.dart
  widgets/
    status_badge.dart
    skill_chip.dart
```

Build the full app following this structure. Start with db_helper.dart and main.dart, then each screen.
