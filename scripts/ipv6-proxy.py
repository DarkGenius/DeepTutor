#!/usr/bin/env python3
"""Minimal HTTP CONNECT proxy. Listens on 0.0.0.0:PORT, tunnels TCP upstream.
getaddrinfo on the host resolves AAAA, so IPv6-only targets (like
api.eliza.yandex.net) become reachable from a network without IPv6 egress
(e.g. the Linux VM that podman runs under on macOS)."""
import socket, threading, sys

def pipe(src, dst):
    try:
        while True:
            data = src.recv(16384)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass
            try:
                s.close()
            except Exception:
                pass

def handle(client, addr):
    try:
        client.settimeout(30)
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = client.recv(4096)
            if not chunk:
                return
            buf += chunk
            if len(buf) > 16384:
                return
        head = buf.split(b"\r\n", 1)[0].decode("ascii", "replace")
        parts = head.split()
        if len(parts) < 2:
            client.sendall(b"HTTP/1.1 400 Bad Request\r\n\r\n")
            return
        method, target = parts[0].upper(), parts[1]
        if method != "CONNECT":
            client.sendall(b"HTTP/1.1 405 Method Not Allowed\r\nAllow: CONNECT\r\n\r\n")
            return
        host, _, port_s = target.rpartition(":")
        host = host.strip("[]")
        try:
            port = int(port_s)
        except ValueError:
            port = 443
        upstream = None
        last_err = None
        try:
            infos = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
        except socket.gaierror as e:
            client.sendall(f"HTTP/1.1 502 Bad Gateway\r\n\r\nDNS: {e}".encode())
            return
        for family, socktype, proto, _, sa in infos:
            try:
                s = socket.socket(family, socktype, proto)
                s.settimeout(10)
                s.connect(sa)
                s.settimeout(None)
                upstream = s
                print(f"[{addr[0]}] -> {host}:{port} via {sa}", flush=True)
                break
            except Exception as e:
                last_err = e
                try:
                    s.close()
                except Exception:
                    pass
        if upstream is None:
            msg = f"HTTP/1.1 502 Bad Gateway\r\n\r\nUpstream: {last_err}".encode()
            client.sendall(msg)
            return
        client.settimeout(None)
        client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        t1 = threading.Thread(target=pipe, args=(client, upstream), daemon=True)
        t2 = threading.Thread(target=pipe, args=(upstream, client), daemon=True)
        t1.start(); t2.start()
        t1.join(); t2.join()
    except Exception as e:
        print(f"[{addr[0]}] error: {e}", flush=True)
        try:
            client.close()
        except Exception:
            pass

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", port))
    srv.listen(128)
    print(f"CONNECT proxy listening on 0.0.0.0:{port}", flush=True)
    while True:
        c, addr = srv.accept()
        threading.Thread(target=handle, args=(c, addr), daemon=True).start()

if __name__ == "__main__":
    main()
