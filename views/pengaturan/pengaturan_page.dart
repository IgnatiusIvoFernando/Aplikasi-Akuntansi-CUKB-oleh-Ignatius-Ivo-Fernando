import 'package:flutter/material.dart';
import '../../config/warna_cukb.dart';
import '../widgets/app_drawer.dart';
import 'profil_perusahaan_page.dart';
import 'daftar_akun_page.dart';

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mengambil informasi lebar layar
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'pengaturan'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text("Akuntansi", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Header Pengaturan (Label Hitam)
            Container(
              margin: const EdgeInsets.only(left: 15),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Pengaturan",
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            const SizedBox(height: 20),
            // Menu Cards menggunakan Padding & LayoutBuilder/Expanded
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Expanded(
                    child: _MenuCard(
                      title: "Profil Perusahaan",
                      icon: Icons.work,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfilPerusahaanPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 15), // Jarak antar kartu
                  Expanded(
                    child: _MenuCard(
                      title: "Daftar Akun",
                      icon: Icons.account_balance,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CukbAkun(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        // Menghapus width statis agar mengikuti Expanded dari parent-nya
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFBFC4FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FittedBox agar teks panjang tidak pecah ke bawah/overflow
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.sidebar_list_on,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Icon(icon, size: 40, color: Colors.black),
          ],
        ),
      ),
    );
  }
}