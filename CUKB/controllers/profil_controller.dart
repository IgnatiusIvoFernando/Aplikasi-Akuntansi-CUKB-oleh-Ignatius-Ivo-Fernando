import '../models/profil_perusahaan.dart';
import 'database_helper.dart';

class ProfilController {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> simpanProfil(ProfilPerusahaan profil) async {
    final db = await _dbHelper.database;

    final existing = await db.query('profil_perusahaan');
    final data = profil.toMap();
    data.remove('id');
    if (existing.isNotEmpty) {
      return await db.update(
        'profil_perusahaan',
        profil.toMap(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      return await db.insert('profil_perusahaan', profil.toMap());
    }
  }

  Future<ProfilPerusahaan?> getProfil() async {
    final db = await _dbHelper.database;
    final result = await db.query('profil_perusahaan');
    return result.isNotEmpty ? ProfilPerusahaan.fromMap(result.first) : null;
  }
}
