import 'package:flutter/material.dart';
import '../../config/warna_cukb.dart';
import '../widgets/app_drawer.dart';
import 'profil_perusahaan_page.dart';
import 'daftar_akun_page.dart';

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(selectedMenu: 'pengaturan'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.penanda,
        title: Text(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            SizedBox(
              width: 145,
              height: 45,
              child: Container(
                margin: const EdgeInsets.only(left: 15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Pengaturan",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MenuCard(
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
                _MenuCard(
                  title: "Daftar Akun",
                  icon: Icons.account_balance,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CukbAkun(),
                      ),
                    );
                  },
                ),
              ],
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
        width: 180,
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFBFC4FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.sidebar_list_on,
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
