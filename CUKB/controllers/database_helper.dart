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

    return await openDatabase(path, version: 1, onCreate: _createTables);
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
        alamat TEXT,
      )
    ''');

    // KATEGORI AKUN
    await db.execute('''
      CREATE TABLE kategori_akun (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL UNIQUE
      )
    ''');

    // Insert default
    await db.insert('kategori_akun', {'nama': 'Aset'});
    await db.insert('kategori_akun', {'nama': 'Biaya'});
    await db.insert('kategori_akun', {'nama': 'Pendapatan'});

    // AKUN
    await db.execute('''
    CREATE TABLE IF NOT EXISTS akun (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL,
      kategori_id INTEGER NOT NULL,
      FOREIGN KEY (kategori_id) REFERENCES kategori_akun (id)
    )
  ''');

    // Insert default akun tanpa kode
    await db.insert('akun', {'nama': 'Kas', 'kategori_id': 1});
    await db.insert('akun', {'nama': 'Gaji Pegawai', 'kategori_id': 2});
    await db.insert('akun', {'nama': 'Pendapatan Jual', 'kategori_id': 3});

    await db.execute('''
    CREATE TABLE IF NOT EXISTS jurnal_umum (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tanggal TEXT NOT NULL,
      keterangan TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

    // TABEL JURNAL DETAIL (CHILD) dengan FOREIGN KEY
    await db.execute('''
    CREATE TABLE IF NOT EXISTS jurnal_detail (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      jurnal_id INTEGER NOT NULL,
      akun_id INTEGER NOT NULL,
      debit REAL DEFAULT 0,
      kredit REAL DEFAULT 0,
      FOREIGN KEY (jurnal_id) 
        REFERENCES jurnal_umum (id) 
        ON DELETE CASCADE,
      FOREIGN KEY (akun_id) 
        REFERENCES akun (id) 
        ON DELETE RESTRICT
    )
  ''');

    // Index untuk performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_jurnal_detail_jurnal_id ON jurnal_detail(jurnal_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_jurnal_detail_akun_id ON jurnal_detail(akun_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_jurnal_tanggal ON jurnal_umum(tanggal)');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
  }
}
