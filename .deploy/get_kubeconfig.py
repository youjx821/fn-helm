#!/usr/bin/env python3
"""Fetch /etc/kubernetes/admin.conf from node71 and save it locally for helm."""
import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect("192.168.74.71", username="root", password="123456", timeout=15)
try:
    sftp = client.open_sftp()
    data = sftp.open("/etc/kubernetes/admin.conf").read().decode()
    sftp.close()
finally:
    client.close()

with open(".deploy/kubeconfig", "w", encoding="utf-8", newline="\n") as f:
    f.write(data)

for line in data.splitlines():
    if "server:" in line:
        print("server line:", line.strip())
print("saved to .deploy/kubeconfig")
