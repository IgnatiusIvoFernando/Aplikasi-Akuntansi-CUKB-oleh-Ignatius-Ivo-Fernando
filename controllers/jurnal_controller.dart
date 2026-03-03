// controllers/jurnal_controller.dart
import '../models/jurnal_umum_header.dart';
import '../models/jurnal_detail.dart';
import 'database_helper.dart';
import 'akun_controller.dart';

class JurnalController {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AkunController _akunController = AkunController();

  // 1. Simpan jurnal dengan nominal tunggal
  Future<int> saveJurnal(Jurnal jurnal) async {
    // Validasi: Pastikan ada detail transaksi
    if (jurnal.details.isEmpty) {
      throw Exception('Jurnal tidak boleh kosong');
    }

    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // Simpan header jurnal
      final jurnalId = await txn.insert('jurnal_umum', {
        'tanggal': jurnal.tanggal.toIso8601String(),
        'keterangan': jurnal.keterangan,
      });

      // Simpan semua detail dengan kolom 'nominal'
      for (var detail in jurnal.details) {
        await txn.insert('jurnal_detail', {
          'jurnal_id': jurnalId,
          'akun_id': detail.akunId,
          'nominal': detail.nominal, // Menggunakan nominal tunggal
        });
      }

      return jurnalId;
    });
  }

  // 2. Ambil jurnal berdasarkan ID (Sudah disesuaikan ke nominal)
  Future<Jurnal?> getJurnalById(int id) async {
    final db = await _dbHelper.database;

    final jurnalResult = await db.query(
      'jurnal_umum',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (jurnalResult.isEmpty) return null;

    final detailsResult = await db.rawQuery('''
      SELECT 
        jd.*,
        a.nama as akun_nama,
        k.tipe as kategori_tipe 
      FROM jurnal_detail jd
      JOIN akun a ON jd.akun_id = a.id
      JOIN kategori_akun k ON a.kategori_id = k.id
      WHERE jd.jurnal_id = ?
    ''', [id]);

    final details = detailsResult.map((map) => JurnalDetail.fromMap(map)).toList();
    return Jurnal.fromMapWithDetails(jurnalResult.first, details);
  }

  // 3. Rekap Transaksi Harian (Hanya menghitung Masuk vs Keluar)
  Future<Map<String, double>> getTotalHarian(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split('T')[0];

    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN k.tipe = 'Masuk' THEN jd.nominal ELSE 0 END) as total_masuk,
        SUM(CASE WHEN k.tipe = 'Keluar' THEN jd.nominal ELSE 0 END) as total_keluar
      FROM jurnal_detail jd
      JOIN jurnal_umum j ON jd.jurnal_id = j.id
      JOIN akun a ON jd.akun_id = a.id
      JOIN kategori_akun k ON a.kategori_id = k.id
      WHERE date(j.tanggal) = date(?)
    ''', [dateStr]);

    return {
      'masuk': (result.first['total_masuk'] as num?)?.toDouble() ?? 0,
      'keluar': (result.first['total_keluar'] as num?)?.toDouble() ?? 0,
    };
  }

  // 4. Riwayat Transaksi (Log Aktivitas)
  Future<List<Map<String, dynamic>>> getRiwayatTransaksi() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        j.tanggal, 
        j.keterangan, 
        a.nama as nama_akun, 
        k.tipe, 
        jd.nominal
      FROM jurnal_umum j
      JOIN jurnal_detail jd ON j.id = jd.jurnal_id
      JOIN akun a ON jd.akun_id = a.id
      JOIN kategori_akun k ON a.kategori_id = k.id
      ORDER BY j.tanggal DESC
    ''');
  }

  // 5. Hapus Jurnal
  Future<int> deleteJurnal(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'jurnal_umum',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}