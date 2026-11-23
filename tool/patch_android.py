#!/usr/bin/env python3
"""Apply the app's Android customizations on top of `flutter create` output.

Run from CI after `flutter create`. Fails loudly if the generated template
no longer matches what we expect, instead of producing a broken APK.
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID = ROOT / 'android'
OVERRIDES = ROOT / 'android_overrides'
MIN_SDK = 24
KOTLIN_VERSION = '2.1.0'
DESUGAR_LIB = 'com.android.tools:desugar_jdk_libs:2.1.4'


def fail(what):
    sys.exit(f'patch_android.py: could not patch {what}')


def sub_once(text, pattern, repl, what):
    new, count = re.subn(pattern, repl, text, count=1)
    if count != 1:
        fail(what)
    return new


def copy_overrides():
    src_root = OVERRIDES / 'app'
    for src in src_root.rglob('*'):
        if src.is_file():
            dst = ANDROID / 'app' / src.relative_to(src_root)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)


def patch_app_gradle():
    kts = ANDROID / 'app' / 'build.gradle.kts'
    is_kts = kts.exists()
    path = kts if is_kts else ANDROID / 'app' / 'build.gradle'
    text = path.read_text()

    text = sub_once(
        text, r'minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion',
        f'minSdk = {MIN_SDK}' if is_kts else f'minSdkVersion {MIN_SDK}', 'minSdk')

    desugar_flag = ('isCoreLibraryDesugaringEnabled = true' if is_kts
                    else 'coreLibraryDesugaringEnabled true')
    text = sub_once(text, r'compileOptions\s*\{',
                    lambda m: m.group(0) + '\n        ' + desugar_flag, 'compileOptions')

    # A fixed signing key (checked in) so every CI build can update the
    # installed app without uninstalling it.
    if is_kts:
        signing = '''signingConfigs {
        getByName("debug") {
            storeFile = rootProject.file("../android_overrides/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
    '''
    else:
        signing = '''signingConfigs {
        debug {
            storeFile rootProject.file('../android_overrides/debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
    }
    '''
    text = sub_once(text, r'buildTypes\s*\{', lambda m: signing + m.group(0), 'signingConfigs')

    dep = (f'coreLibraryDesugaring("{DESUGAR_LIB}")' if is_kts
           else f"coreLibraryDesugaring '{DESUGAR_LIB}'")
    text += f'\ndependencies {{\n    {dep}\n}}\n'
    path.write_text(text)


def version_tuple(v):
    return tuple(int(p) for p in v.split('.'))


def patch_kotlin_version():
    pattern = r'(org\.jetbrains\.kotlin\.android["\']\)?\s+version\s+["\'])([\d.]+)'

    def bump(m):
        current = m.group(2)
        if version_tuple(current) >= version_tuple(KOTLIN_VERSION):
            return m.group(0)
        return m.group(1) + KOTLIN_VERSION

    for name in ('settings.gradle.kts', 'settings.gradle'):
        path = ANDROID / name
        if path.exists():
            text, count = re.subn(pattern, bump, path.read_text())
            if count:
                path.write_text(text)
                return
    fail('Kotlin plugin version')


if __name__ == '__main__':
    if not ANDROID.is_dir():
        fail('android/ (run flutter create first)')
    copy_overrides()
    patch_app_gradle()
    patch_kotlin_version()
    print('Android customizations applied.')
