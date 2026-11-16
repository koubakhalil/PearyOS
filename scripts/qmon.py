"""Send one command to a QEMU human-monitor unix socket and wait for it to finish.
usage: qmon.py <socket> <command>
The HMP monitor echoes typed characters, so we read until the prompt returns after our command."""
import socket
import sys
import time

path, cmd = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX)
s.connect(path)
s.settimeout(2)


def drain(max_wait):
    data = b""
    end = time.time() + max_wait
    while time.time() < end:
        try:
            chunk = s.recv(65536)
        except OSError:
            break
        if not chunk:
            break
        data += chunk
        end = time.time() + 1.0  # keep reading while data keeps arriving
    return data


drain(2)  # banner / prompt
s.sendall((cmd + "\r").encode())
out = drain(20)
# strip the readline echo noise: keep only the tail after the last carriage return
text = out.decode(errors="replace").replace("\x1b[K", "").replace("\x1b[D", "")
print(text[-300:].strip())
s.close()
