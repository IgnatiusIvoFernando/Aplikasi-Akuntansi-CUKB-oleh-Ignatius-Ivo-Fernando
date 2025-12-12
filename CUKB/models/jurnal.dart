// models/jurnal.dart
import 'package:intl/intl.dart';

import 'jurnal_detail.dart';

class Jurnal {
  int? id;
  DateTime tanggal;
  String keterangan;

  // RELASI: One-to-Many dengan JurnalDetail
  List<JurnalDetail> details;

  // Calculated fields
  double totalDebit;
  double totalKredit;

  Jurnal({
    this.id,
    required this.tanggal,
    required this.keterangan,
    required this.details,
    this.totalDebit = 0,
    this.totalKredit = 0,
  });

  // Constructor untuk jurnal baru
  Jurnal.empty({
    required this.tanggal,
    required this.keterangan,
  })  : details = [],
        totalDebit = 0,
        totalKredit = 0;

  // Method untuk menghitung total
  void calculateTotals() {
    totalDebit = details.fold(0.0, (sum, detail) => sum + detail.debit);
    totalKredit = details.fold(0.0, (sum, detail) => sum + detail.kredit);
  }

  // Validasi double-entry accounting
  bool isValid() {
    calculateTotals();
    return totalDebit == totalKredit;
  }

  String get tanggalFormatted {
    return DateFormat('dd/MM/yyyy').format(tanggal);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tanggal': tanggal.toIso8601String(),
      'keterangan': keterangan,
    };
  }

  factory Jurnal.fromMap(Map<String, dynamic> map) {
    return Jurnal(
      id: map['id'],
      tanggal: DateTime.parse(map['tanggal']),
      keterangan: map['keterangan'] ?? '',
      details: [],
      totalDebit: (map['total_debit'] as num?)?.toDouble() ?? 0,
      totalKredit: (map['total_kredit'] as num?)?.toDouble() ?? 0,
    );
  }

  // Factory dengan details
  factory Jurnal.fromMapWithDetails(Map<String, dynamic> map, List<JurnalDetail> details) {
    final jurnal = Jurnal(
      id: map['id'],
      tanggal: DateTime.parse(map['tanggal']),
      keterangan: map['keterangan'] ?? '',
      details: details,
      totalDebit: (map['total_debit'] as num?)?.toDouble() ?? 0,
      totalKredit: (map['total_kredit'] as num?)?.toDouble() ?? 0,
    );
    jurnal.calculateTotals();
    return jurnal;
  }

  @override
  String toString() {
    return 'Jurnal{id: $id, tanggal: $tanggalFormatted, keterangan: $keterangan, totalDebit: $totalDebit, totalKredit: $totalKredit, details: ${details.length}}';
  }
}