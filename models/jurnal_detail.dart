// models/jurnal_detail.dart
import 'akun.dart';

class JurnalDetail {
  int? id;
  int jurnalId;
  int akunId;
  double debit;
  double kredit;

  // RELASI: Untuk join dengan tabel akun
  Akun? akun; // Foreign key relation

  JurnalDetail({
    this.id,
    required this.jurnalId,
    required this.akunId,
    required this.debit,
    required this.kredit,
    this.akun,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jurnal_id': jurnalId,
      'akun_id': akunId,
      'debit': debit,
      'kredit': kredit,
    };
  }

  factory JurnalDetail.fromMap(Map<String, dynamic> map) {
    return JurnalDetail(
      id: map['id'],
      jurnalId: map['jurnal_id'],
      akunId: map['akun_id'],
      debit: (map['debit'] as num?)?.toDouble() ?? 0,
      kredit: (map['kredit'] as num?)?.toDouble() ?? 0,
    );
  }

  // Factory dengan join akun
  factory JurnalDetail.fromMapWithAkun(Map<String, dynamic> map) {
    return JurnalDetail(
      id: map['id'],
      jurnalId: map['jurnal_id'],
      akunId: map['akun_id'],
      debit: (map['debit'] as num?)?.toDouble() ?? 0,
      kredit: (map['kredit'] as num?)?.toDouble() ?? 0,
      akun: map['akun_id'] != null ? Akun.fromMap({
        'id': map['akun_id'],
        'nama': map['akun_nama'],
        'kategori_id': map['akun_kategori_id'],
      }) : null,
    );
  }

  @override
  String toString() {
    return 'JurnalDetail{id: $id, jurnalId: $jurnalId, akunId: $akunId, debit: $debit, kredit: $kredit, akun: $akun}';
  }
}