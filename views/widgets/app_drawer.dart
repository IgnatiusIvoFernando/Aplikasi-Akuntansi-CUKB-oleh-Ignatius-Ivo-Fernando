import 'dart:io';
import 'package:cukb/config/warna_cukb.dart';
import 'package:flutter/material.dart';
import '../../views/akuntansi/jurnal_umum_page.dart';
import '../../views/akuntansi/saldo_akhir_page.dart';
import '../../views/home/home_page.dart';
import '../../views/pengaturan/pengaturan_page.dart';
import '../../controllers/profil_controller.dart';

class AppDrawer extends StatefulWidget {
  final String selectedMenu;
  const AppDrawer({super.key, this.selectedMenu = ''});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? tappedMenu;
  final ProfilController _profilController = ProfilController();
  String _namaPerusahaan = "Nama Perusahaan";
  String? _fotoPath;

  @override
  void initState() {
    super.initState();
    _loadDataProfil();
  }

  Future<void> _loadDataProfil() async {
    final profil = await _profilController.getProfil();
    if (profil != null) {
      setState(() {
        _namaPerusahaan = profil.nama;
        _fotoPath = profil.fotoPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 260,
      backgroundColor: AppColors.background,
      child: Container(
        // Efek Gradasi Latar Belakang agar terlihat seperti kaca/plastik 2000-an
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.layar_primer.withOpacity(0.5),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 50),

            // Logo Header dengan efek Glow/Kilau
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(4, 4),
                      blurRadius: 5,
                    ),
                  ],
                  border: Border.all(color: AppColors.sidebar_list, width: 2),
                  image: (_fotoPath != null && File(_fotoPath!).existsSync())
                      ? DecorationImage(
                    image: FileImage(File(_fotoPath!)),
                    fit: BoxFit.contain,
                  )
                      : null,
                ),
                child: (_fotoPath == null || !File(_fotoPath!).existsSync())
                    ? const Icon(Icons.business_center, size: 50, color: Color(0xFF433B9D))
                    : null,
              ),
            ),

            const SizedBox(height: 15),

            // Nama Perusahaan dengan style "Steel/Chrome"
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.penanda, // Hitam
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.white30),
              ),
              child: Center(
                child: Text(
                  _namaPerusahaan.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 1.2,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Courier', // Gaya retro-komputer
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Menu Items
            _buildRetroMenuItem(
              id: "mengisi",
              title: "MENGISI SALDO",
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => _navigate(context, const HomePage()),
            ),
            _buildRetroMenuItem(
              id: "jurnal",
              title: "JURNAL UMUM",
              icon: Icons.history_edu_outlined,
              onTap: () => _navigate(context, const JurnalUmumPage()),
            ),
            _buildRetroMenuItem(
              id: "saldo",
              title: "SALDO AKHIR",
              icon: Icons.pie_chart_outline,
              onTap: () => _navigate(context, const SaldoAkhirPage()),
            ),
            _buildRetroMenuItem(
              id: "pengaturan",
              title: "PENGATURAN",
              icon: Icons.settings_outlined,
              onTap: () => _navigate(context, const PengaturanPage()),
            ),

            const Spacer(),

            // Footer Versi Aplikasi
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "CUKB v1.0.2000",
                style: TextStyle(color: AppColors.view, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildRetroMenuItem({
    required String id,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    bool isActive = widget.selectedMenu == id;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // Estetika Glossy 2000-an
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isActive
                ? [
              AppColors.sidebar_list_on, // Biru terang
              const Color(0xFF0005AA),    // Biru pekat
            ]
                : [
              AppColors.sidebar_list,     // Ungu-biru default
              const Color(0xFF2F2A60),
            ],
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: AppColors.sidebar_list_on.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
              : [
            const BoxShadow(
              color: Colors.black26,
              offset: Offset(2, 2),
              blurRadius: 2,
            )
          ],
          border: Border.all(
            color: isActive ? Colors.white : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Kilauan Glossy di bagian atas (Reflection)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      shadows: const [
                        Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2),
                      ],
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