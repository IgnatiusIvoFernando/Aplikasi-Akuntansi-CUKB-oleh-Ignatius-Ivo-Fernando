import 'package:flutter/material.dart';
import '../../config/warna_cukb.dart';
import '../../controllers/akun_controller.dart';
import '../../models/akun.dart';
import '../../models/kategori.dart';
import '../../views/widgets/app_drawer.dart';

class CukbAkun extends StatefulWidget {
  const CukbAkun({super.key});

  @override
  _CukbAkunState createState() => _CukbAkunState();
}

class _CukbAkunState extends State<CukbAkun> {
  final TextEditingController _namaController = TextEditingController();
  // Controller tambahan untuk dialog edit
  final TextEditingController _editController = TextEditingController();

  Kategori? kategoriDipilih;

  final AkunController _akunController = AkunController();
  List<Kategori> _kategoriList = [];
  Map<int, List<Akun>> _akunByKategori = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final kategori = await _akunController.getKategori();
      final akun = await _akunController.getSemuaAkun();

      Map<int, List<Akun>> grouped = {};
      for (var k in kategori) {
        final akunByKat = akun.where((a) => a.kategoriId == k.id).toList();
        grouped[k.id!] = akunByKat;
      }

      setState(() {
        _kategoriList = kategori;
        _akunByKategori = grouped;
      });
    } catch (e) {
      print('Error loading data: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _tambahAkun() async {
    if (_namaController.text.isEmpty || kategoriDipilih == null) {
      _showSnackBar('Nama dan Kategori harus diisi');
      return;
    }

    final akun = Akun(
      nama: _namaController.text,
      kategoriId: kategoriDipilih!.id!,
    );

    try {
      await _akunController.tambahAkun(akun);
      _showSnackBar('Akun "${akun.nama}" berhasil ditambahkan');
      _namaController.clear();
      setState(() => kategoriDipilih = null);
      await _loadData();
    } catch (e) {
      _showSnackBar('Gagal menambahkan akun: $e');
    }
  }

  // MODIFIKASI: Fungsi Hapus Akun
  Future<void> _hapusAkun(Akun akun) async {
    bool konfirmasi = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Akun"),
        content: Text("Yakin ingin menghapus akun '${akun.nama}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (konfirmasi) {
      try {
        await _akunController.hapusAkun(akun.id!);
        _showSnackBar('Akun berhasil dihapus');
        _loadData();
      } catch (e) {
        _showSnackBar('Gagal menghapus: $e');
      }
    }
  }

  // MODIFIKASI: Fungsi Edit Akun
  Future<void> _editAkun(Akun akun) async {
    _editController.text = akun.nama;
    bool konfirmasi = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Nama Akun"),
        content: TextField(
          controller: _editController,
          decoration: const InputDecoration(labelText: "Nama Akun Baru"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Simpan")),
        ],
      ),
    ) ?? false;

    if (konfirmasi && _editController.text.isNotEmpty) {
      try {
        akun.nama = _editController.text;
        await _akunController.updateAkun(akun);
        _showSnackBar('Akun berhasil diperbarui');
        _loadData();
      } catch (e) {
        _showSnackBar('Gagal memperbarui: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: AppDrawer(selectedMenu: 'pengaturan'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.penanda,
        title: const Text('Daftar Akun Jurnal Umum', style: TextStyle(fontSize: 20, color: Colors.white)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(left: 15),
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Daftar Akun Jurnal Umum",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _kategoriList.map((kategori) {
                    final akunList = _akunByKategori[kategori.id!] ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(kategori.nama, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                            SizedBox(width: 10),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                              child: Text('${akunList.length} akun', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (akunList.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text('Belum ada akun', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                          )
                        else
                          ...akunList.map((akun) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Color(0xFFD1C9FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                      child: Icon(_getKategoriIcon(kategori.nama), size: 20, color: _getKategoriColor(kategori.nama)),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(akun.nama, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
                                    ),
                                    // MODIFIKASI: Tombol Edit & Hapus (Tetap Minimalis)
                                    IconButton(
                                      icon: Icon(Icons.edit_note, color: Colors.blue[700], size: 22),
                                      onPressed: () => _editAkun(akun),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                    ),
                                    SizedBox(width: 15),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.red[700], size: 20),
                                      onPressed: () => _hapusAkun(akun),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        SizedBox(height: 20),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              // FORM TAMBAH AKUN BARU (Tidak berubah)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Pastikan start agar sejajar dengan gaya HomePage
                    children: [
                      // HEADER: Mengikuti gaya "Edit Jurnal" (Hitam Glossy)
                      Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFF000000),
                              Color(0xFF222222),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          border: Border(
                            bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline, color: Colors.white.withOpacity(0.8), size: 24),
                              const SizedBox(width: 12),
                              const Text(
                                "Tambah Akun Baru",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // BODY FORM: Mengikuti gaya "Layar Primer" dengan Border Putih
                      Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: AppColors.layar_primer,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Nama Akun",
                              style: TextStyle(fontSize: 15, color: AppColors.list_period),
                            ),
                            const SizedBox(height: 5),
                            TextFormField(
                              controller: _namaController,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: "Contoh: Kas, Bank, Gaji Pegawai",
                                hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                                border: UnderlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Kategori",
                              style: TextStyle(fontSize: 15, color: AppColors.list_period),
                            ),
                            const SizedBox(height: 5),
                            // Dropdown disesuaikan agar bersih tanpa kotak warna ungu (sesuai gaya input jurnal)
                            DropdownButtonFormField<Kategori>(
                              value: kategoriDipilih,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                border: UnderlineInputBorder(),
                                contentPadding: EdgeInsets.zero,
                              ),
                              hint: const Text("Pilih Kategori Akun", style: TextStyle(fontSize: 13)),
                              items: _kategoriList.map((kategori) {
                                return DropdownMenuItem<Kategori>(
                                  value: kategori,
                                  child: Row(
                                    children: [
                                      Icon(_getKategoriIcon(kategori.nama), color: AppColors.list_period, size: 20),
                                      const SizedBox(width: 10),
                                      Text(kategori.nama, style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => kategoriDipilih = value),
                            ),
                            const SizedBox(height: 35),

                            // Tombol Simpan (Align ke kiri sesuai tombol Simpan Jurnal)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 150,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0E0077), Color(0xFF3A2AD8)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3A2AD8).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _tambahAkun,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  ),
                                  child: const Text(
                                    "Simpan",
                                    style: TextStyle(color: Colors.white, fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getKategoriIcon(String kategoriNama) {
    switch (kategoriNama) {
      case "Aset": return Icons.account_balance_wallet;
      case "Biaya": return Icons.money_off;
      case "Pendapatan": return Icons.attach_money;
      case "Kewajiban": return Icons.account_balance;
      case "Modal": return Icons.business;
      default: return Icons.category;
    }
  }

  Color _getKategoriColor(String kategoriNama) {
    switch (kategoriNama) {
      case "Aset": return Color(0xFF4CAF50);
      case "Biaya": return Color(0xFFF44336);
      case "Pendapatan": return Color(0xFF2196F3);
      case "Kewajiban": return Color(0xFFFF9800);
      case "Modal": return Color(0xFF9C27B0);
      default: return Colors.grey;
    }
  }
}