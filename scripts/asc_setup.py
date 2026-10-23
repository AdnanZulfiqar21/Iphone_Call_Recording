#!/usr/bin/env python3
"""Prepares App Store Connect for a CallCapture upload using the team's API key.

1. Registers the explicit bundle IDs for the app and its widget extension if missing
   (Xcode's automatic signing only created a wildcard ID for development).
2. Checks that an app record exists for the app bundle ID. If not, tries to create it and
   prints Apple's answer; Apple may require the record to be created in App Store Connect.

Uses only the standard library and the `openssl` command for the ES256 signature.
Never prints the key or the token.
Usage: asc_setup.py <key.p8>   (env: ASC_KEY_ID, ASC_ISSUER_ID)
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
APP_ID = "com.adnanzulfiqar.callcapture"
IDS = [(APP_ID, "CallCapture"), (APP_ID + ".widgets", "CallCapture Widgets")]
APP_NAME, SKU, LOCALE = "CallCapture", "callcapture001", "en-US"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_to_raw(sig: bytes) -> bytes:
    """openssl emits an ASN.1 DER ECDSA signature; JWT ES256 needs r||s, 32 bytes each."""
    assert sig[0] == 0x30
    i = 2 if sig[1] < 0x80 else 2 + (sig[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert sig[i] == 0x02
        n = sig[i + 1]
        out += sig[i + 2:i + 2 + n].lstrip(b"\x00").rjust(32, b"\x00")
        i += 2 + n
    return out


def token(key_path: str, key_id: str, issuer: str) -> str:
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 1_000,
                                 "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{payload}".encode()
    sig = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input,
                         capture_output=True, check=True).stdout
    return f"{header}.{payload}.{b64url(der_to_raw(sig))}"


class Client:
    def __init__(self, jwt: str):
        self.jwt = jwt

    def call(self, method: str, path: str, body=None):
        req = urllib.request.Request(API + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Authorization": f"Bearer {self.jwt}",
                                              "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            try:
                return e.code, json.loads(e.read() or b"{}")
            except ValueError:
                return e.code, {}


def errors(doc) -> str:
    return "; ".join(f"{e.get('title', '')}: {e.get('detail', '')}" for e in doc.get("errors", [])) or "no detail"


def bundle_id(client: Client, identifier: str):
    q = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": 200})
    status, doc = client.call("GET", f"/bundleIds?{q}")
    if status != 200:
        raise SystemExit(f"::error::Listing bundle IDs failed ({status}): {errors(doc)}")
    return next((d for d in doc.get("data", []) if d["attributes"]["identifier"] == identifier), None)


def main() -> int:
    client = Client(token(sys.argv[1], os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"]))
    app_bundle = None
    for identifier, name in IDS:
        found = bundle_id(client, identifier)
        if found:
            print(f"Bundle ID {identifier}: already registered")
        else:
            status, doc = client.call("POST", "/bundleIds", {"data": {"type": "bundleIds", "attributes": {
                "identifier": identifier, "name": name, "platform": "IOS"}}})
            if status != 201:
                print(f"::error::Registering bundle ID {identifier} failed ({status}): {errors(doc)}")
                return 1
            found = doc["data"]
            print(f"Bundle ID {identifier}: registered")
        if identifier == APP_ID:
            app_bundle = found

    q = urllib.parse.urlencode({"filter[bundleId]": APP_ID})
    status, doc = client.call("GET", f"/apps?{q}")
    if status == 200 and doc.get("data"):
        print(f"App record for {APP_ID}: exists ({doc['data'][0]['attributes'].get('name')})")
        return 0
    status, doc = client.call("POST", "/apps", {"data": {"type": "apps",
        "attributes": {"name": APP_NAME, "sku": SKU, "primaryLocale": LOCALE, "bundleId": APP_ID},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": app_bundle["id"]}}}}})
    if status == 201:
        print(f"App record for {APP_ID}: created ({APP_NAME})")
        return 0
    print(f"::error::No App Store Connect app record for {APP_ID}, and Apple did not allow creating one "
          f"through the API ({status}: {errors(doc)}). Create it once in App Store Connect: Apps → + → "
          f"New App, bundle ID {APP_ID}, SKU {SKU}. See docs/execution/DEVICE_TESTING.md.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
