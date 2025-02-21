import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'registros.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS registros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            acesso_autorizado BOOLEAN NOT NULL,
            hora TEXT NOT NULL,
            data TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Função para inserir registro
  Future<void> insertRegistro(Map<String, dynamic> registro) async {
    final db = await database;
    await db.insert('registros', registro);
  }

  // Função para buscar todos os registros
  Future<List<Map<String, dynamic>>> getRegistros() async {
    final db = await database;
    final result = await db.query('registros');
    return result;
  }
}