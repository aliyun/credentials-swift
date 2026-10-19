#!/usr/bin/env python3
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(*args):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode:
        sys.stderr.buffer.write(result.stdout)
        result.check_returncode()


def main():
    if sys.platform != "linux" or not Path("/.dockerenv").exists() or os.geteuid() != 0:
        raise RuntimeError("Network fixtures must run as root in an isolated Linux container.")
    if len(sys.argv) < 2 or "--parallel" in sys.argv[1:]:
        raise RuntimeError("Pass a serial test command, for example: swift test --enable-code-coverage")
    for command in ("ip", "openssl", "update-ca-certificates"):
        if shutil.which(command) is None:
            raise RuntimeError(f"Missing fixture prerequisite: {command}")

    root = Path(__file__).resolve().parents[2]
    hosts = Path("/etc/hosts")
    previous_hosts = hosts.read_bytes()
    ca_path = Path(f"/usr/local/share/ca-certificates/credentials-test-{os.getpid()}.crt")
    address_added = False
    hosts_changed = False
    servers = []
    with tempfile.TemporaryDirectory(prefix="credentials-fixture-") as temporary:
        directory = Path(temporary)
        try:
            # Only the test container receives the metadata address, STS mapping and test CA.
            run("ip", "addr", "add", "100.100.100.200/32", "dev", "lo")
            address_added = True
            hosts.write_bytes(previous_hosts + b"\n127.0.0.1 sts.aliyuncs.com\n")
            hosts_changed = True
            run("openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                "-subj", "/CN=Credentials Test CA", "-keyout", str(directory / "ca.key"),
                "-out", str(directory / "ca.crt"), "-addext", "basicConstraints=critical,CA:TRUE")
            run("openssl", "req", "-newkey", "rsa:2048", "-nodes", "-subj", "/CN=localhost",
                "-keyout", str(directory / "server.key"), "-out", str(directory / "server.csr"))
            extensions = directory / "server.ext"
            extensions.write_text("subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n")
            run("openssl", "x509", "-req", "-in", str(directory / "server.csr"),
                "-CA", str(directory / "ca.crt"), "-CAkey", str(directory / "ca.key"),
                "-CAcreateserial", "-days", "1", "-out", str(directory / "server.crt"),
                "-extfile", str(extensions))
            shutil.copyfile(directory / "ca.crt", ca_path)
            run("update-ca-certificates")
            fixture = runpy.run_path(str(root / "Tests/fixtures/credentials_server.py"))
            servers = fixture["start_servers"](str(directory / "server.crt"), str(directory / "server.key"))
            environment = dict(os.environ,
                               CREDENTIALS_TEST_SERVER="http://127.0.0.1:18080",
                               CREDENTIALS_TEST_TLS_HOST="localhost:18443")
            return subprocess.run(sys.argv[1:], cwd=root, env=environment).returncode
        finally:
            for server in servers:
                server.shutdown()
                server.server_close()
            if ca_path.exists():
                ca_path.unlink()
                run("update-ca-certificates", "--fresh")
            if hosts_changed:
                hosts.write_bytes(previous_hosts)
            if address_added:
                run("ip", "addr", "del", "100.100.100.200/32", "dev", "lo")


if __name__ == "__main__":
    sys.exit(main())
