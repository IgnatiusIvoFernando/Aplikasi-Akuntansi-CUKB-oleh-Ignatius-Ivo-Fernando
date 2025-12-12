// controllers/jurnal_controller.dart
import '../models/jurnal.dart';
import '../models/jurnal_detail.dart';
import 'database_helper.dart';
import 'akun_controller.dart';

class JurnalController {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AkunController _akunController = AkunController();

  // Simpan jurnal dengan details
  Future<int> saveJurnal(Jurnal jurnal) async {
    // Validasi double-entry
    if (!jurnal.isValid()) {
      throw Exception('Jurnal tidak valid: Debit ($jurnal.totalDebit) ≠ Kredit ($jurnal.totalKredit)');
    }

    // Validasi semua akun ada di database
    for (var detail in jurnal.details) {
      final akun = await _akunController.getAkunById(detail.akunId);
      if (akun == null) {
        throw Exception('Akun dengan ID ${detail.akunId} tidak ditemukan');
      }
    }

    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // 1. Simpan header jurnal
      final jurnalId = await txn.insert('jurnal_umum', {
        'tanggal': jurnal.tanggal.toIso8601String(),
        'keterangan': jurnal.keterangan,
      });

      // 2. Simpan semua details
      for (var detail in jurnal.details) {
        await txn.insert('jurnal_detail', {
          'jurnal_id': jurnalId,
          'akun_id': detail.akunId,
          'debit': detail.debit,
          'kredit': detail.kredit,
        });
      }

      return jurnalId;
    });
  }

  // Ambil jurnal dengan details dan akun
  Future<Jurnal?> getJurnalById(int id) async {
    final db = await _dbHelper.database;

    // Ambil header jurnal
    final jurnalResult = await db.query(
      'jurnal_umum',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (jurnalResult.isEmpty) return null;

    final jurnalMap = jurnalResult.first;

    // Ambil details dengan JOIN akun
    final detailsResult = await db.rawQuery('''
      SELECT 
        jd.*,
        a.nama as akun_nama,
        a.kategori_id as akun_kategori_id
      FROM jurnal_detail jd
      JOIN akun a ON jd.akun_id = a.id
      WHERE jd.jurnal_id = ?
      ORDER BY jd.id
    ''', [id]);

    // Konversi ke JurnalDetail dengan Akun
    final details = detailsResult.map((map) {
      return JurnalDetail.fromMapWithAkun(map);
    }).toList();

    return Jurnal.fromMapWithDetails(jurnalMap, details);
  }

  // Ambil semua jurnal untuk tanggal tertentu
  Future<List<Jurnal>> getJurnalByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split('T')[0];

    // Ambil semua jurnal untuk tanggal tersebut
    final jurnalsResult = await db.rawQuery('''
      SELECT 
        j.*,
        COALESCE(SUM(jd.debit), 0) as total_debit,
        COALESCE(SUM(jd.kredit), 0) as total_kredit
      FROM jurnal_umum j
      LEFT JOIN jurnal_detail jd ON j.id = jd.jurnal_id
      WHERE date(j.tanggal) = date(?)
      GROUP BY j.id
      ORDER BY j.tanggal DESC, j.id DESC
    ''', [dateStr]);

    // Untuk setiap jurnal, ambil details-nya
    final jurnals = <Jurnal>[];

    for (var jurnalMap in jurnalsResult) {
      final jurnalId = jurnalMap['id'] as int;

      // Ambil details dengan akun
      final detailsResult = await db.rawQuery('''
        SELECT 
          jd.*,
          a.nama as akun_nama,
          a.kategori_id as akun_kategori_id
        FROM jurnal_detail jd
        JOIN akun a ON jd.akun_id = a.id
        WHERE jd.jurnal_id = ?
        ORDER BY jd.id
      ''', [jurnalId]);

      final details = detailsResult.map((map) {
        return JurnalDetail.fromMapWithAkun(map);
      }).toList();

      jurnals.add(Jurnal.fromMapWithDetails(jurnalMap, details));
    }

    return jurnals;
  }

  // Di controllers/jurnal_controller.dart - TAMBAHKAN method ini


// Atau jika mau lebih sederhana:
  Future<List<Map<String, dynamic>>> getBulanTahunTransaksi() async {
    final db = await _dbHelper.database;

    return await db.rawQuery('''
    SELECT DISTINCT
      strftime('%Y', tanggal) as tahun,
      strftime('%m', tanggal) as bulan_angka
    FROM jurnal_umum
    ORDER BY tahun DESC, bulan_angka DESC
  ''');
  }
  // Hapus jurnal (akan hapus details juga karena CASCADE)
  Future<int> deleteJurnal(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'jurnal_umum',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get neraca saldo (laporan akun)
  Future<List<Map<String, dynamic>>> getNeracaSaldo() async {
    final db = await _dbHelper.database;

    return await db.rawQuery('''
      SELECT 
        a.id as akun_id,
        a.nama,
        k.nama as kategori,
        COALESCE(SUM(jd.debit), 0) as total_debit,
        COALESCE(SUM(jd.kredit), 0) as total_kredit,
        (COALESCE(SUM(jd.debit), 0) - COALESCE(SUM(jd.kredit), 0)) as saldo
      FROM akun a
      LEFT JOIN kategori_akun k ON a.kategori_id = k.id
      LEFT JOIN jurnal_detail jd ON a.id = jd.akun_id
      LEFT JOIN jurnal_umum j ON jd.jurnal_id = j.id
      GROUP BY a.id
      ORDER BY a.id
    ''');
  }

  // Get total debit dan kredit per hari
  Future<Map<String, double>> getTotalHarian(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split('T')[0];

    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(debit), 0) as total_debit,
        COALESCE(SUM(kredit), 0) as total_kredit
      FROM jurnal_detail jd
      JOIN jurnal_umum j ON jd.jurnal_id = j.id
      WHERE date(j.tanggal) = date(?)
    ''', [dateStr]);

    return {
      'debit': (result.first['total_debit'] as num?)?.toDouble() ?? 0,
      'kredit': (result.first['total_kredit'] as num?)?.toDouble() ?? 0,
    };
  }
}