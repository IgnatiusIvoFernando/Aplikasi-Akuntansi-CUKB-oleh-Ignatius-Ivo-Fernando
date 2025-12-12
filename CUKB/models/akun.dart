// models/akun.dart
class Akun {
  int? id;
  String nama;
  int kategoriId;
  String? kategoriNama;

  Akun({
    this.id,
    required this.nama,
    required this.kategoriId,
    this.kategoriNama,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,            // Hanya nama saja
      'kategori_id': kategoriId,
    };
  }

  factory Akun.fromMap(Map<String, dynamic> map) {
    return Akun(
      id: map['id'],
      nama: map['nama'] ?? '',
      kategoriId: map['kategori_id'],
      kategoriNama: map['kategori_nama'],
    );
  }

  @override
  String toString() {
    return 'Akun{id: $id, nama: $nama, kategoriId: $kategoriId}';
  }
}