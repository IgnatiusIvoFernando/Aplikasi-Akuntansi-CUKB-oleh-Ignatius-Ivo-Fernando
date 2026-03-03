class Akun {
  int? id;
  String nama;
  int kategoriId;
  String? kategoriNama;
  String? tipe; // TAMBAHKAN field penampung hasil JOIN ini

  Akun({
    this.id,
    required this.nama,
    required this.kategoriId,
    this.kategoriNama,
    this.tipe,
  });

  factory Akun.fromMap(Map<String, dynamic> map) {
    return Akun(
      id: map['id'],
      nama: map['nama'] ?? '',
      kategoriId: map['kategori_id'],
      kategoriNama: map['kategori_nama'],
      tipe: map['tipe'], // Ambil data tipe dari JOIN kategori_akun
    );
  }

  // toMap hanya untuk kolom yang benar-benar ada di tabel 'akun'
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'kategori_id': kategoriId,
    };
  }
}