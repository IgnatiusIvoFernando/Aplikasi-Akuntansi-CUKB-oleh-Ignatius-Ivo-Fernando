import 'akun.dart';

class JurnalDetail {
  int? id;
  int jurnalId;
  int akunId;
  double nominal;

  // RELASI: Opsional untuk menampung data akun hasil JOIN
  Akun? akun;

  JurnalDetail({
    this.id,
    required this.jurnalId,
    required this.akunId,
    required this.nominal,
    this.akun,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jurnal_id': jurnalId,
      'akun_id': akunId,
      'nominal': nominal,
    };
  }

  factory JurnalDetail.fromMap(Map<String, dynamic> map) {
    return JurnalDetail(
      id: map['id'],
      jurnalId: map['jurnal_id'],
      akunId: map['akun_id'],
      nominal: (map['nominal'] as num?)?.toDouble() ?? 0,
    );
  }

  // TAMBAHKAN INI: Untuk memudahkan pembacaan saat melakukan JOIN dengan tabel Akun
  factory JurnalDetail.fromMapWithAkun(Map<String, dynamic> map) {
    return JurnalDetail(
      id: map['id'],
      jurnalId: map['jurnal_id'],
      akunId: map['akun_id'],
      nominal: (map['nominal'] as num?)?.toDouble() ?? 0,
      akun: map['akun_nama'] != null
          ? Akun.fromMap({
        'id': map['akun_id'],
        'nama': map['akun_nama'],
        'kategori_id': map['akun_kategori_id'],
        'tipe': map['kategori_tipe'], // Sangat penting untuk logika saldo
      })
          : null,
    );
  }
}