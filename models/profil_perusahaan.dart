// Update pada class ProfilPerusahaan
class ProfilPerusahaan {
  int? id;
  String nama;
  String? jenisIndustri;
  String? negara;
  String? provinsi;
  String? alamat;
  String? fotoPath; // Tambahan Baru

  ProfilPerusahaan({
    this.id,
    required this.nama,
    this.jenisIndustri,
    this.negara,
    this.provinsi,
    this.alamat,
    this.fotoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_perusahaan': nama,
      'jenis_industri': jenisIndustri,
      'negara': negara,
      'provinsi': provinsi,
      'alamat': alamat,
      'foto_path': fotoPath, // Tambahan Baru
    };
  }

  factory ProfilPerusahaan.fromMap(Map<String, dynamic> map) {
    return ProfilPerusahaan(
      id: map['id'],
      nama: map['nama_perusahaan'] ?? '',
      jenisIndustri: map['jenis_industri'],
      negara: map['negara'],
      provinsi: map['provinsi'],
      alamat: map['alamat'],
      fotoPath: map['foto_path'], // Tambahan Baru
    );
  }
}