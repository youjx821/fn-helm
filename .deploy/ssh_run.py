#!/usr/bin/env python3
"""Upload a script to a remote host via SFTP and execute it.

Usage: ssh_run.py <host> <local_script_path>
"""
import sys
import paramiko

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

HOST = sys.argv[1]
LOCAL = sys.argv[2]
REMOTE = "/tmp/" + LOCAL.replace("\\", "/").split("/")[-1]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username="root", password="123456", timeout=15)
try:
    sftp = client.open_sftp()
    sftp.put(LOCAL, REMOTE)
    sftp.close()
    stdin, stdout, stderr = client.exec_command(f"bash {REMOTE}", timeout=900)
    out = stdout.read().decode("utf-8", "replace")
    err = stderr.read().decode("utf-8", "replace")
    rc = stdout.channel.recv_exit_status()
    if out:
        print(out, end="")
    if err:
        print("[STDERR]", err, end="", file=sys.stderr)
    sys.exit(rc)
finally:
    client.close()
