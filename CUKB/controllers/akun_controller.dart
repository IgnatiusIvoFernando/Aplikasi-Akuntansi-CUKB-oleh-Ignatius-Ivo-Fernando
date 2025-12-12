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

  Future<int> tambahAkun(Akun akun) async {
    final db = await _dbHelper.database;
    return await db.insert('akun', akun.toMap());
  }

  Future<List<Akun>> getSemuaAkun() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT a.*, k.nama as kategori_nama 
      FROM akun a 
      JOIN kategori_akun k ON a.kategori_id = k.id 
      ORDER BY a.nama
    ''');
    return result.map((map) => Akun.fromMap(map)).toList();
  }

  Future<List<Akun>> getAkunByKategori(String kategoriNama) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT a.*, k.nama as kategori_nama 
      FROM akun a 
      JOIN kategori_akun k ON a.kategori_id = k.id 
      WHERE k.nama = ?
    ''',
      [kategoriNama],
    );
    return result.map((map) => Akun.fromMap(map)).toList();
  }
  // controllers/akun_controller.dart (TAMBAHKAN)
  Future<Akun?> getAkunById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
    SELECT a.*, k.nama as kategori_nama 
    FROM akun a 
    JOIN kategori_akun k ON a.kategori_id = k.id 
    WHERE a.id = ?
  ''', [id]);

    return result.isNotEmpty ? Akun.fromMap(result.first) : null;
  }

  Future<List<Akun>> getAkunForJurnal() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
    SELECT a.*, k.nama as kategori_nama 
    FROM akun a 
    JOIN kategori_akun k ON a.kategori_id = k.id 
    ORDER BY a.kategori_id
  ''');

    return result.map((map) => Akun.fromMap(map)).toList();
  }

}
