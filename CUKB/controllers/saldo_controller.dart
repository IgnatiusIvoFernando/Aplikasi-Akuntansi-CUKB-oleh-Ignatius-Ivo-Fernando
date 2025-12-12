import 'database_helper.dart';

class SaldoAkhirController {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getSaldoAkhir() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        akun.id,
        akun.nama,
        IFNULL(SUM(jd.debit), 0) AS debit,
        IFNULL(SUM(jd.kredit), 0) AS kredit
      FROM akun
      LEFT JOIN jurnal_detail jd ON jd.akun_id = akun.id
      GROUP BY akun.id
      ORDER BY akun.nama
    ''');

    return result;
  }

  Future<List<Map<String, dynamic>>> getSaldoAkhirByPeriode(
      String bulan, String tahun) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery("""
    SELECT 
      akun.id,
      akun.nama,
      IFNULL(SUM(jd.debit), 0) AS debit,
      IFNULL(SUM(jd.kredit), 0) AS kredit
    FROM akun
    LEFT JOIN jurnal_detail jd ON jd.akun_id = akun.id
    LEFT JOIN jurnal_umum j ON j.id = jd.jurnal_id
    WHERE strftime('%m', j.tanggal) = ? 
      AND strftime('%Y', j.tanggal) = ?
    GROUP BY akun.id
    ORDER BY akun.nama
  """, [bulan, tahun]);

    return result;
  }

  Future<List<Map<String, dynamic>>> getSaldoPeriode() async {
    final db = await _dbHelper.database;

    return await db.rawQuery('''
    SELECT 
      strftime('%Y', tanggal) as tahun,
      strftime('%m', tanggal) as bulan_angka,
      CASE strftime('%m', tanggal)
        WHEN '01' THEN 'Januari'
        WHEN '02' THEN 'Februari'
        WHEN '03' THEN 'Maret'
        WHEN '04' THEN 'April'
        WHEN '05' THEN 'Mei'
        WHEN '06' THEN 'Juni'
        WHEN '07' THEN 'Juli'
        WHEN '08' THEN 'Agustus'
        WHEN '09' THEN 'September'
        WHEN '10' THEN 'Oktober'
        WHEN '11' THEN 'November'
        WHEN '12' THEN 'Desember'
      END as bulan_nama,
      COUNT(DISTINCT j.id) as jumlah_transaksi,
      SUM(jd.debit) as total_debit,
      SUM(jd.kredit) as total_kredit
    FROM jurnal_umum j
    LEFT JOIN jurnal_detail jd ON j.id = jd.jurnal_id
    GROUP BY strftime('%Y', tanggal), strftime('%m', tanggal)
    ORDER BY tahun DESC, bulan_angka DESC
  ''');
  }

}
