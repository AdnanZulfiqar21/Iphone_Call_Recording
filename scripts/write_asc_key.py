#!/usr/bin/env python3
"""Writes the App Store Connect API key from $ASC_KEY_P8 as a canonical PEM file.

Pasted secrets often lose their shape (line breaks turned into spaces, Windows line
endings, missing BEGIN/END lines, or the whole file base64-encoded). The key body is
recovered from any of those forms and rewrapped. Nothing from the key is ever printed.
Usage: write_asc_key.py <output path>
"""
import base64
import binascii
import os
import re
import sys

HEADER, FOOTER = "-----BEGIN PRIVATE KEY-----", "-----END PRIVATE KEY-----"


def body_of(text: str) -> bytes:
    text = text.replace("\r", "")
    if "BEGIN" not in text:
        # The whole .p8 file may have been base64-encoded before pasting.
        try:
            decoded = base64.b64decode(re.sub(r"\s+", "", text), validate=True).decode("ascii")
            if "BEGIN" in decoded:
                text = decoded
        except (binascii.Error, UnicodeDecodeError, ValueError):
            pass
    text = re.sub(r"-----(BEGIN|END)[A-Z ]*-----", "", text)
    return base64.b64decode(re.sub(r"\s+", "", text), validate=True)


def main() -> int:
    raw = os.environ.get("ASC_KEY_P8", "")
    try:
        der = body_of(raw)
    except (binascii.Error, ValueError):
        der = b""
    # A P-256 PKCS#8 private key is a DER SEQUENCE of roughly 138 bytes.
    if not der or der[0] != 0x30 or not 100 <= len(der) <= 200:
        print("::error::ASC_KEY_P8 is not the text of an App Store Connect .p8 key "
              f"(decoded {len(der)} bytes; expected about 138). Open the AuthKey_XXXX.p8 file in a "
              "text editor and paste its entire contents, including the BEGIN and END lines.")
        return 1
    b64 = base64.b64encode(der).decode("ascii")
    lines = [b64[i:i + 64] for i in range(0, len(b64), 64)]
    with open(sys.argv[1], "w", encoding="ascii") as f:
        f.write("\n".join([HEADER, *lines, FOOTER]) + "\n")
    os.chmod(sys.argv[1], 0o600)
    print(f"API key written ({len(der)}-byte key, canonical PEM)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
