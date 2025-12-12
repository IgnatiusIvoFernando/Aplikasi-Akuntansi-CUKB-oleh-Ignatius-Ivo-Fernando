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
  // HANYA controller untuk nama
  final TextEditingController _namaController = TextEditingController();

  // Kategori yang dipilih
  Kategori? kategoriDipilih;

  // Controller dan state untuk data
  final AkunController _akunController = AkunController();
  List<Kategori> _kategoriList = [];
  List<Akun> _akunList = [];
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
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Ambil kategori dari database
      final kategori = await _akunController.getKategori();

      // 2. Ambil semua akun dari database
      final akun = await _akunController.getSemuaAkun();

      // 3. Group akun by kategori
      Map<int, List<Akun>> grouped = {};
      for (var k in kategori) {
        final akunByKat = akun.where((a) => a.kategoriId == k.id).toList();
        grouped[k.id!] = akunByKat;
      }

      setState(() {
        _kategoriList = kategori;
        _akunList = akun;
        _akunByKategori = grouped;
      });
    } catch (e) {
      print('Error loading data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _tambahAkun() async {
    // Validasi sederhana
    if (_namaController.text.isEmpty) {
      _showSnackBar('Nama akun harus diisi');
      return;
    }

    if (kategoriDipilih == null) {
      _showSnackBar('Kategori harus dipilih');
      return;
    }

    // Buat objek Akun TANPA KODE
    final akun = Akun(
      nama: _namaController.text,
      kategoriId: kategoriDipilih!.id!,
    );

    try {
      // Simpan ke database
      await _akunController.tambahAkun(akun);
      _showSnackBar('Akun "${akun.nama}" berhasil ditambahkan');

      // Reset form
      _namaController.clear();
      setState(() => kategoriDipilih = null);

      // Reload data
      await _loadData();
    } catch (e) {
      _showSnackBar('Gagal menambahkan akun: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        title: const Text(
          'CUKB',
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // HEADER: Daftar Akun
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

              // LIST KATEGORI DENGAN AKUN (DARI DATABASE)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _kategoriList.map((kategori) {
                    final akunList = _akunByKategori[kategori.id!] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header kategori dengan jumlah akun
                        Row(
                          children: [
                            Text(
                              kategori.nama,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${akunList.length} akun',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (akunList.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Belum ada akun',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
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
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Icon berdasarkan kategori
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        _getKategoriIcon(kategori.nama),
                                        size: 20,
                                        color: _getKategoriColor(kategori.nama),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        akun.nama,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                        SizedBox(height: 20), // Spasi antar kategori
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // FORM TAMBAH AKUN BARU
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // HEADER HITAM
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle, color: Colors.white, size: 24),
                            SizedBox(width: 10),
                            Text(
                              "Tambah Akun Baru",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // BODY FORM
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: AppColors.layar_primer,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label
                            Text(
                              "Nama Akun",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Input nama
                            Container(
                              width: double.infinity,
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8D8DCE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                controller: _namaController,
                                style: TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: "Contoh: Kas, Bank, Gaji Pegawai",
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Label kategori
                            Text(
                              "Kategori",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Dropdown kategori
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8D8DCE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<Kategori>(
                                value: kategoriDipilih,
                                isExpanded: true,
                                underline: Container(),
                                dropdownColor: Color(0xFF8D8DCE),
                                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                                style: TextStyle(color: Colors.white, fontSize: 14),
                                hint: Text(
                                  "Pilih Kategori Akun",
                                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                ),
                                items: _kategoriList.map((kategori) {
                                  return DropdownMenuItem<Kategori>(
                                    value: kategori,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getKategoriIcon(kategori.nama),
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Text(kategori.nama),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    kategoriDipilih = value;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 30),

                            // BUTTON SIMPAN
                            Center(
                              child: Container(
                                width: 180,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0E0077),
                                      Color(0xFF3A2AD8),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF3A2AD8).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _tambahAkun,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save, color: Colors.white, size: 20),
                                      SizedBox(width: 10),
                                      Text(
                                        "Simpan Akun",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
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

  // Helper functions untuk icon dan warna kategori
  IconData _getKategoriIcon(String kategoriNama) {
    switch (kategoriNama) {
      case "Aset":
        return Icons.account_balance_wallet;
      case "Biaya":
        return Icons.money_off;
      case "Pendapatan":
        return Icons.attach_money;
      case "Kewajiban":
        return Icons.account_balance;
      case "Modal":
        return Icons.business;
      default:
        return Icons.category;
    }
  }

  Color _getKategoriColor(String kategoriNama) {
    switch (kategoriNama) {
      case "Aset":
        return Color(0xFF4CAF50); // Hijau
      case "Biaya":
        return Color(0xFFF44336); // Merah
      case "Pendapatan":
        return Color(0xFF2196F3); // Biru
      case "Kewajiban":
        return Color(0xFFFF9800); // Orange
      case "Modal":
        return Color(0xFF9C27B0); // Ungu
      default:
        return Colors.grey;
    }
  }
}