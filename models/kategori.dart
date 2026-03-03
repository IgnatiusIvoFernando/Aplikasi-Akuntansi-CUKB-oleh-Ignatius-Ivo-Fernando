class Kategori {
  int? id;
  String nama;
  String tipe; // TAMBAHKAN INI: Untuk membedakan arus kas Masuk/Keluar

  Kategori({
    this.id,
    required this.nama,
    required this.tipe // Tambahkan ke constructor
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'tipe': tipe, // Masukkan ke map untuk simpan ke DB
    };
  }

  factory Kategori.fromMap(Map<String, dynamic> map) {
    return Kategori(
      id: map['id'],
      nama: map['nama'] ?? '',
      // Pastikan mengambil field 'tipe' dari database
      tipe: map['tipe'] ?? 'Keluar',
    );
  }
}