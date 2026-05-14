import 'package:postgres/postgres.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  PostgreSQLConnection? _conn;

  Future<PostgreSQLConnection> get connection async {
    if (_conn == null || _conn!.isClosed) {
      _conn = PostgreSQLConnection(
        dotenv.env['DB_HOST']!,
        int.parse(dotenv.env['DB_PORT']!),
        dotenv.env['DB_NAME']!,
        username: dotenv.env['DB_USERNAME'],
        password: dotenv.env['DB_PASSWORD'],
      );
      await _conn!.open();
    }
    return _conn!;
  }

  Future<void> close() async {
    if (_conn != null && !_conn!.isClosed) {
      await _conn!.close();
    }
  }
}
