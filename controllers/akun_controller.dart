import '../models/akun.dart';
import '../models/kategori.dart';
import 'database_helper.dart';

class AkunController {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Kategori>> getKategori() async {
    final db = await _dbHelper.database;
    final result = await db.query('kategori_akun', orderBy: 'id');
    return result.map((map) => Kategori.fromMap(map)).toList();
  }

  // 2. Ambil Semua Akun dengan Tipe (Masuk/Keluar)
  // Penting untuk menentukan apakah transaksi menambah atau mengurangi saldo
  Future<List<Akun>> getSemuaAkun() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
    SELECT a.*, k.nama as kategori_nama, k.tipe 
    FROM akun a 
    JOIN kategori_akun k ON a.kategori_id = k.id 
    ORDER BY k.nama ASC, a.nama ASC -- Diurutkan agar kategori kumpul jadi satu
  ''');
    return result.map((map) => Akun.fromMap(map)).toList();
  }
  // 3. Ambil Akun Berdasarkan ID (Sertakan tipe kategori)
  Future<Akun?> getAkunById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT a.*, k.nama as kategori_nama, k.tipe 
      FROM akun a 
      JOIN kategori_akun k ON a.kategori_id = k.id 
      WHERE a.id = ?
    ''', [id]);

    return result.isNotEmpty ? Akun.fromMap(result.first) : null;
  }

  // 4. Ambil Akun Khusus untuk Form Transaksi (Single-Entry)
  // Mengurutkan berdasarkan tipe agar user mudah memilih Pemasukan/Pengeluaran
  Future<List<Akun>> getAkunForJurnal() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT a.*, k.nama as kategori_nama, k.tipe 
      FROM akun a 
      JOIN kategori_akun k ON a.kategori_id = k.id 
      ORDER BY k.tipe DESC, k.nama ASC
    ''');

    return result.map((map) => Akun.fromMap(map)).toList();
  }

  // 5. Tambah, Update, dan Hapus (Logika CRUD Tetap Sama)
  Future<int> tambahAkun(Akun akun) async {
    final db = await _dbHelper.database;
    return await db.insert('akun', akun.toMap());
  }

  Future<int> updateAkun(Akun akun) async {
    final db = await _dbHelper.database;
    return await db.update(
      'akun',
      akun.toMap(),
      where: 'id = ?',
      whereArgs: [akun.id],
    );
  }

  Future<int> hapusAkun(int id) async {
    final db = await _dbHelper.database;
    // Catatan: Pastikan tidak ada transaksi yang menggunakan akun ini sebelum dihapus
    return await db.delete(
      'akun',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}