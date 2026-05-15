# Wikilow Proot Installer

Sebuah script installer Linux distribution berbasis proot yang profesional, ringan, dan mudah digunakan di Termux.

## Fitur Utama

- **Multi-Distro**: Mendukung Alpine, Arch Linux, Debian, Fedora, Kali Linux, Ubuntu, dan Void Linux.
- **Smart Integration**: Deteksi otomatis `proot-distro` official. Anda bisa memilih menggunakan rootfs official atau instalasi manual (external).
- **Tanpa Desktop Mode**: Instalasi bersih tanpa paket GUI/Desktop Environment untuk performa maksimal.
- **Sudo Support**: Dilengkapi dengan stub `sudo` dan konfigurasi otomatis untuk user non-root.
- **Hardware Mocking**: Simulasi `cpuinfo` dan `meminfo` untuk kompatibilitas script pihak ketiga di dalam proot.
- **Akses Storage**: Bind mount otomatis ke `/sdcard`, `/storage`, dan `/mnt`.
- **Branding**: Banner Wikilow yang elegan dan profesional di installer maupun saat login distro.
- **Manajemen Distro**: Dilengkapi dengan fitur Uninstall untuk membersihkan instalasi distro.

## Syarat Instalasi

Sebelum menjalankan script, pastikan perangkat Anda memenuhi syarat berikut:
1.  **Aplikasi Termux**: Gunakan versi terbaru (direkomendasikan dari F-Droid).
2.  **Akses Internet**: Dibutuhkan untuk mengunduh rootfs dan dependensi.
3.  **Ruang Penyimpanan**: Minimal 500MB - 2GB tergantung distro yang dipilih.
4.  **Izin Storage**: Jalankan `termux-setup-storage` sebelum memulai (script akan mengecek ini secara otomatis).

## Cara Penggunaan

Ikuti langkah-langkah di bawah ini untuk memulai:

### 1. Download Script
Gunakan command berikut di Termux:
```bash
wget https://raw.githubusercontent.com/Santuybe/proot-non-root/master/proot_non-root.sh
```

### 2. Berikan Izin Eksekusi
```bash
chmod +x proot_non-root.sh
```

### 3. Jalankan Script
```bash
./proot_non-root.sh
```

### 4. Navigasi Menu
- Pilih **Action** (Install atau Uninstall).
- Pilih **Distribusi** dari list yang tersedia.
- Pilih **Metode Instalasi** (Official atau Manual).
- Ikuti petunjuk untuk pembuatan **User Non-Root** jika diperlukan.

### 5. Menjalankan Distro
Setelah selesai, sebuah launcher akan dibuat sesuai nama distro, misalnya `ubuntu.sh`. Jalankan dengan:
```bash
./ubuntu.sh
```

## Troubleshooting

- **Akses Storage Tidak Terbaca**: Pastikan Anda sudah memberikan izin storage di Android untuk aplikasi Termux.
- **Gagal Download**: Pastikan koneksi internet stabil. Jika gagal, coba pilih opsi 'Reinstall' dari menu.
- **Alpine Error**: Jika distro Alpine gagal mencari shell, script terbaru sudah menyertakan deteksi otomatis antara `/bin/bash` dan `/bin/sh`.

---
**Repository**: [https://github.com/Santuybe/](https://github.com/Santuybe/)
