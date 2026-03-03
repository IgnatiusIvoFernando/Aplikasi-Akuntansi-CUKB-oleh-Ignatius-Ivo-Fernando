import 'jurnal_detail.dart';

class Jurnal {
  int? id;
  DateTime tanggal;
  String keterangan;
  List<JurnalDetail> details;

  Jurnal({
    this.id,
    required this.tanggal,
    required this.keterangan,
    required this.details
  });

  // Tambahkan method toMap untuk keperluan INSERT ke database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tanggal': tanggal.toIso8601String(),
      'keterangan': keterangan,
    };
  }

  // Factory untuk mengambil data dasar jurnal (tanpa details)
  factory Jurnal.fromMap(Map<String, dynamic> map) {
    return Jurnal(
      id: map['id'],
      tanggal: DateTime.parse(map['tanggal']),
      keterangan: map['keterangan'] ?? '',
      details: [], // Inisialisasi list kosong
    );
  }

  factory Jurnal.fromMapWithDetails(Map<String, dynamic> map, List<JurnalDetail> details) {
    return Jurnal(
      id: map['id'],
      tanggal: DateTime.parse(map['tanggal']),
      keterangan: map['keterangan'] ?? '',
      details: details,
    );
  }

  // Getter pembantu untuk menghitung total nominal dalam satu transaksi
  double get totalNominal => details.fold(0, (sum, item) => sum + item.nominal);
}