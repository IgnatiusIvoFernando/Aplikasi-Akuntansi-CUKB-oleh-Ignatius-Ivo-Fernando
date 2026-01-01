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
      final existingId = existing.first['id'];
      return await db.update(
        'profil_perusahaan',
        data,
        where: 'id = ?',
        whereArgs: [existingId],
      );
    } else {
      return await db.insert('profil_perusahaan', data);
    }
  }

  Future<ProfilPerusahaan?> getProfil() async {
    final db = await _dbHelper.database;
    final result = await db.query('profil_perusahaan');
    return result.isNotEmpty ? ProfilPerusahaan.fromMap(result.first) : null;
  }
}
