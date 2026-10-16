"""Frozen executable dispatch; never invoke the frozen bot as a Python interpreter."""
import sys

if __name__ == '__main__':
    if '--desktop-self-test' in sys.argv:
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
        from cryptography.hazmat.backends.openssl.backend import backend
        import ssl, sqlite3, serial, bleak, meshcore, meshcore_cli
        from modules.web_viewer.app import BotDataViewer
        from pathlib import Path
        import modules
        root = Path(modules.__file__).parent
        assert (root / 'commands/ping_command.py').is_file(), 'Missing command discovery resources'
        assert list((root / 'service_plugins').glob('*.py')), 'Missing service discovery resources'
        key = AESGCM.generate_key(bit_length=128)
        cipher = AESGCM(key)
        nonce = bytes(12)
        assert cipher.decrypt(nonce, cipher.encrypt(nonce, b'MeshCore', None), None) == b'MeshCore'
        print('Desktop crypto/import self-test passed:', backend.openssl_version_text(), ssl.OPENSSL_VERSION)
    elif '--desktop-viewer' in sys.argv:
        sys.argv.remove('--desktop-viewer')
        from modules.web_viewer.app import main
        main()
    else:
        # Runtime data paths are relative to the writable bot working directory.
        # Seed missing directories without replacing the user's custom files.
        if getattr(sys, 'frozen', False):
            import shutil
            from pathlib import Path
            bundled = Path(sys._MEIPASS)
            for name in ('translations', 'data'):
                source, destination = bundled / name, Path.cwd() / name
                if source.is_dir() and not destination.exists():
                    shutil.copytree(source, destination)
        from meshcore_bot import main
        main()
