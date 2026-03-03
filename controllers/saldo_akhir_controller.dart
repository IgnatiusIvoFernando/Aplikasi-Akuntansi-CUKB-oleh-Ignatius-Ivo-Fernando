import 'database_helper.dart';

class SaldoAkhirController {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 1. Mendapatkan Ringkasan Total Saldo (Uang Masuk vs Uang Keluar)
  Future<Map<String, double>> getRingkasanSaldo() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        k.tipe,
        SUM(jd.nominal) as total
      FROM jurnal_detail jd
      JOIN akun a ON jd.akun_id = a.id
      JOIN kategori_akun k ON a.kategori_id = k.id
      GROUP BY k.tipe
    ''');

    double masuk = 0;
    double keluar = 0;

    for (var row in result) {
      if (row['tipe'] == 'Masuk') {
        masuk = (row['total'] as num).toDouble();
      } else if (row['tipe'] == 'Keluar') {
        keluar = (row['total'] as num).toDouble();
      }
    }

    return {
      'masuk': masuk,
      'keluar': keluar,
      'saldo': masuk - keluar,
    };
  }

  // 2. Mendapatkan Saldo per Akun (Berdasarkan Nominal Tunggal)
  Future<List<Map<String, dynamic>>> getSaldoAkhir() async {
    final db = await _dbHelper.database;

    // Saldo akhir per akun dihitung berdasarkan akumulasi nominal
    // Tipe 'Masuk' dianggap positif, 'Keluar' dianggap pengurang bagi total kas
    final result = await db.rawQuery('''
      SELECT 
        a.id,
        a.nama,
        k.nama as kategori_nama,
        k.tipe as kategori_tipe,
        IFNULL(SUM(jd.nominal), 0) AS total_nominal
      FROM akun a
      JOIN kategori_akun k ON a.kategori_id = k.id
      LEFT JOIN jurnal_detail jd ON jd.akun_id = a.id
      GROUP BY a.id
      ORDER BY k.tipe DESC, a.nama ASC
    ''');
    return result;
  }

  // 3. Mendapatkan Saldo per Akun Berdasarkan Periode (Bulan & Tahun)
  Future<List<Map<String, dynamic>>> getSaldoAkhirByPeriode(String bulan, String tahun) async {
    final db = await DatabaseHelper().database;

    // Format bulan-tahun untuk pencocokan (yyyy-mm)
    String periode = "$tahun-$bulan";

    return await db.rawQuery('''
    SELECT 
      j.tanggal, 
      a.nama, 
      k.tipe as kategori_tipe, 
      d.nominal as nominal_periode
    FROM jurnal_umum j
    JOIN jurnal_detail d ON j.id = d.jurnal_id
    JOIN akun a ON d.akun_id = a.id
    JOIN kategori_akun k ON a.kategori_id = k.id
    WHERE strftime('%Y-%m', j.tanggal) = ?
    ORDER BY j.tanggal ASC, j.id ASC
  ''', [periode]);
  }

  // 4. Mendapatkan Rekapitulasi Per Periode (Bulanan)
  Future<List<Map<String, dynamic>>> getSaldoPeriode() async {
    final db = await _dbHelper.database;

    return await db.rawQuery('''
    SELECT 
      strftime('%Y', j.tanggal) as tahun,
      strftime('%m', j.tanggal) as bulan_angka,
      CASE strftime('%m', j.tanggal)
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
      SUM(CASE WHEN k.tipe = 'Masuk' THEN jd.nominal ELSE 0 END) as total_masuk,
      SUM(CASE WHEN k.tipe = 'Keluar' THEN jd.nominal ELSE 0 END) as total_keluar
    FROM jurnal_umum j
    LEFT JOIN jurnal_detail jd ON j.id = jd.jurnal_id
    LEFT JOIN akun a ON jd.akun_id = a.id
    LEFT JOIN kategori_akun k ON a.kategori_id = k.id
    GROUP BY strftime('%Y', j.tanggal), strftime('%m', j.tanggal)
    ORDER BY tahun DESC, bulan_angka DESC
  ''');
  }
}