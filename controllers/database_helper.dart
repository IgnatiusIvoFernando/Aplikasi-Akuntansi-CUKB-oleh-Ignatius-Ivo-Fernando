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
      foto_path TEXT
    )
  ''');

    // KATEGORI AKUN
    await db.execute('''
    CREATE TABLE kategori_akun (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL UNIQUE
    )
  ''');

    // Insert default kategori - satu perintah
    await db.rawInsert('''
    INSERT OR IGNORE INTO kategori_akun VALUES 
    (1,'Aset'),(2,'Liabilitas'),(3,'Ekuitas'),(4,'Pendapatan'),(5,'Biaya')
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

    // Insert default akun - satu perintah
    await db.rawInsert('''
    INSERT OR IGNORE INTO akun VALUES 
    (1,'Kas',1),(2,'Piutang Usaha',1),(3,'Persediaan',1),(4,'Peralatan',1),
    (5,'Utang Usaha',2),(6,'Utang Bank',2),(7,'Modal Pemilik',3),(8,'Laba Ditahan',3),
    (9,'Pendapatan Jasa',4),(10,'Pendapatan Penjualan',4),(11,'Biaya Gaji',5),
    (12,'Biaya Sewa',5),(13,'Biaya Listrik',5)
  ''');

    // JURNAL UMUM
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
      debit REAL DEFAULT 0,
      kredit REAL DEFAULT 0,
      FOREIGN KEY (jurnal_id) REFERENCES jurnal_umum (id) ON DELETE CASCADE,
      FOREIGN KEY (akun_id) REFERENCES akun (id) ON DELETE RESTRICT
    )
  ''');

    // Indexes
    await db.execute('CREATE INDEX idx_jurnal_detail_jurnal_id ON jurnal_detail(jurnal_id)');
    await db.execute('CREATE INDEX idx_jurnal_detail_akun_id ON jurnal_detail(akun_id)');
    await db.execute('CREATE INDEX idx_jurnal_tanggal ON jurnal_umum(tanggal)');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
  }
}
