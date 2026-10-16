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
        import asyncio
        from meshcore_bot import main
        main()
