#!/usr/bin/env python3
"""Menyesuaikan AndroidManifest.xml hasil `flutter create` untuk XyCloudStore.

Yang ditambahkan:
  - nama aplikasi  : XyCloudStore
  - izin internet
  - izin REQUEST_INSTALL_PACKAGES (untuk update via DownloadManager)
  - izin POST_NOTIFICATIONS (Android 13+ untuk progress notif)
  - activity penangkap balikan login sosial (khusus xycloudstore://auth)
  - daftar <queries> supaya bisa membuka WhatsApp, browser, dan email

Pemakaian: python3 tools/patch_manifest.py android/app/src/main/AndroidManifest.xml
"""
import re
import sys

ACTIVITY_CALLBACK = """
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true">
            <intent-filter android:label="flutter_web_auth_2">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="xycloudstore" android:host="auth"/>
            </intent-filter>
        </activity>
    </application>"""

QUERIES = """    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="mailto"/>
        </intent>
        <intent>
            <action android:name="android.support.customtabs.action.CustomTabsService"/>
        </intent>
        <package android:name="com.whatsapp"/>
        <package android:name="com.whatsapp.w4b"/>
        <package android:name="com.limelight"/>
        <package android:name="com.limelight.noir"/>
    </queries>
</manifest>"""


def main() -> int:
    berkas = sys.argv[1] if len(sys.argv) > 1 else 'android/app/src/main/AndroidManifest.xml'
    isi = open(berkas, encoding='utf-8').read()

    isi = re.sub(r'android:label="[^\"]*"', 'android:label="XyCloudStore"', isi, count=1)

    # Permissions untuk update
    perms = []
    if 'android.permission.INTERNET' not in isi:
        perms.append('<uses-permission android:name="android.permission.INTERNET"/>')
    if 'android.permission.REQUEST_INSTALL_PACKAGES' not in isi:
        perms.append('<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>')
    if 'android.permission.POST_NOTIFICATIONS' not in isi:
        perms.append('<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>')
    if 'android.permission.RECORD_AUDIO' not in isi:
        perms.append('<uses-permission android:name="android.permission.RECORD_AUDIO"/>')
    # Batch I: galeri kustom (photo_manager) + login sidik jari (local_auth).
    if 'android.permission.READ_MEDIA_IMAGES' not in isi:
        perms.append('<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>')
    if 'android.permission.READ_MEDIA_VIDEO' not in isi:
        perms.append('<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>')
    if 'android.permission.READ_EXTERNAL_STORAGE' not in isi:
        perms.append('<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>')
    if 'android.permission.USE_BIOMETRIC' not in isi:
        perms.append('<uses-permission android:name="android.permission.USE_BIOMETRIC"/>')

    if perms:
        isi = isi.replace(
            '<application',
            '\n    '.join(perms) + '\n    <application',
            1,
        )

    isi = re.sub(r'android:allowBackup="[^\"]*"', '', isi)
    if 'android:allowBackup' not in isi:
        isi = isi.replace('<application', '<application android:allowBackup="false"', 1)

    # Android 10 (API 29): photo_manager butuh akses penyimpanan legacy.
    if 'android:requestLegacyExternalStorage' not in isi:
        isi = isi.replace('<application', '<application android:requestLegacyExternalStorage="true"', 1)

    if 'flutter_web_auth_2.CallbackActivity' not in isi:
        isi = re.sub(r'\s*</application>', '\n' + ACTIVITY_CALLBACK, isi, count=1)
    # Manifest lama pernah menangkap seluruh scheme xycloudstore. Batasi juga
    # input yang sudah memiliki CallbackActivity agar host referral tidak ambigu.
    isi = re.sub(
        r'<data\s+android:scheme="xycloudstore"(?![^>]*android:host)[^>]*/>',
        '<data android:scheme="xycloudstore" android:host="auth"/>',
        isi,
    )

    if '<queries>' not in isi:
        isi = isi.replace('</manifest>', QUERIES, 1)

    open(berkas, 'w', encoding='utf-8').write(isi)
    print('AndroidManifest.xml diperbarui:', berkas)
    if '<uses-feature android:name="android.hardware.microphone"' not in isi:
        isi = isi.replace('</manifest>',
            '    <uses-feature android:name="android.hardware.microphone" android:required="false"/>\n</manifest>', 1)
        open(berkas, 'w', encoding='utf-8').write(isi)
    print('Permissions: INTERNET + REQUEST_INSTALL_PACKAGES + POST_NOTIFICATIONS + RECORD_AUDIO + READ_MEDIA_* + USE_BIOMETRIC + queries')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
