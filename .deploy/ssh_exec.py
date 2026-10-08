#!/usr/bin/env python3
"""Run a command on a remote host over SSH with password auth.

Usage: ssh_exec.py <host> <command>
Credentials are fixed for this deployment env (root/123456).
"""
import sys
import paramiko

HOST = sys.argv[1]
CMD = sys.argv[2]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username="root", password="123456", timeout=15)
try:
    stdin, stdout, stderr = client.exec_command(CMD, timeout=600)
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
