#!/usr/bin/env python3
"""Ansible Vault 1.1 (AES256) tanpa perlu ansible terinstal.

  vault.py encrypt <password> <plain-in> <vault-out>
  vault.py decrypt <password> <vault-in>        -> plaintext ke stdout (exit 1 bila password salah)

Butuh python3-cryptography (bawaan RHEL 9).
"""
import binascii
import hashlib
import hmac
import os
import sys

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

HEADER = b"$ANSIBLE_VAULT;1.1;AES256"


def _keys(password, salt):
    d = hashlib.pbkdf2_hmac("sha256", password, salt, 10000, dklen=80)
    return d[:32], d[32:64], d[64:80]


def encrypt(password, plain):
    salt = os.urandom(32)
    k1, k2, iv = _keys(password, salt)
    padder = padding.PKCS7(128).padder()
    data = padder.update(plain) + padder.finalize()
    enc = Cipher(algorithms.AES(k1), modes.CTR(iv), default_backend()).encryptor()
    ct = enc.update(data) + enc.finalize()
    mac = hmac.new(k2, ct, hashlib.sha256).hexdigest().encode()
    body = binascii.hexlify(b"\n".join([binascii.hexlify(salt), mac, binascii.hexlify(ct)]))
    lines = [body[i:i + 80] for i in range(0, len(body), 80)]
    return HEADER + b"\n" + b"\n".join(lines) + b"\n"


def decrypt(password, blob):
    lines = blob.strip().splitlines()
    if not lines or not lines[0].startswith(b"$ANSIBLE_VAULT;"):
        raise ValueError("bukan file vault")
    raw = binascii.unhexlify(b"".join(l.strip() for l in lines[1:]))
    salt_h, mac_h, ct_h = raw.split(b"\n", 2)
    salt, ct = binascii.unhexlify(salt_h), binascii.unhexlify(ct_h)
    k1, k2, iv = _keys(password, salt)
    if not hmac.compare_digest(hmac.new(k2, ct, hashlib.sha256).hexdigest().encode(), mac_h.strip()):
        raise ValueError("password salah")
    dec = Cipher(algorithms.AES(k1), modes.CTR(iv), default_backend()).decryptor()
    data = dec.update(ct) + dec.finalize()
    unpad = padding.PKCS7(128).unpadder()
    return unpad.update(data) + unpad.finalize()


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    op, pw = sys.argv[1], sys.argv[2].encode()
    if op == "encrypt":
        with open(sys.argv[3], "rb") as f:
            out = encrypt(pw, f.read())
        with open(sys.argv[4], "wb") as f:
            f.write(out)
    elif op == "decrypt":
        try:
            with open(sys.argv[3], "rb") as f:
                sys.stdout.buffer.write(decrypt(pw, f.read()))
        except Exception:  # noqa: BLE001
            sys.exit(1)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
