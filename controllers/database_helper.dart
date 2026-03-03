import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cukb.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _createTables(Database db, int version) async {
    // PROFIL PERUSAHAAN
    await db.execute('''
    CREATE TABLE profil_perusahaan (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama_perusahaan TEXT NOT NULL,
      jenis_industri TEXT,
      negara TEXT,
      provinsi TEXT,
      kota TEXT,
      alamat TEXT,
      foto_path TEXT
    )
    ''');

    // KATEGORI AKUN
    await db.execute('''
    CREATE TABLE kategori_akun (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL UNIQUE,
      tipe TEXT NOT NULL
    )
    ''');

    // Rapikan urutan: Aset (1), Pendapatan (2), Pengeluaran (3)
    await db.execute('''
    INSERT INTO kategori_akun (id, nama, tipe) VALUES 
    (1, 'Pemasukan', 'Masuk'),
    (2, 'Pengeluaran', 'Keluar')
    ''');

    // AKUN
    await db.execute('''
    CREATE TABLE akun (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL,
      kategori_id INTEGER NOT NULL,
      FOREIGN KEY (kategori_id) REFERENCES kategori_akun (id)
    )
    ''');

    // Rapikan urutan akun sesuai kategori di atas
    await db.execute('''
    INSERT INTO akun (id, nama, kategori_id) VALUES 
    (1, 'Pemasukan', 1),
    (2, 'Pengeluaran', 2)
    ''');

    // JURNAL UMUM (HEADER)
    await db.execute('''
    CREATE TABLE jurnal_umum (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tanggal TEXT NOT NULL,
      keterangan TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    ''');

    // JURNAL DETAIL
    await db.execute('''
    CREATE TABLE jurnal_detail (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      jurnal_id INTEGER NOT NULL,
      akun_id INTEGER NOT NULL,
      nominal REAL DEFAULT 0,
      FOREIGN KEY (jurnal_id) REFERENCES jurnal_umum (id) ON DELETE CASCADE,
      FOREIGN KEY (akun_id) REFERENCES akun (id) ON DELETE RESTRICT
    )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_jurnal_detail_jurnal_id ON jurnal_detail(jurnal_id)');
    await db.execute('CREATE INDEX idx_jurnal_tanggal ON jurnal_umum(tanggal)');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
  }
}