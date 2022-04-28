#!/usr/bin/python3

import argparse
import subprocess
import re
from pathlib import Path
import json
import sys
from typing import List

TOTAL_TEST = ["read", "write", "end-to-end"]
CMDS = {
    "read": "./gradlew readBench",
    "write": "./gradlew writeBench",
    "end-to-end": "./gradlew readWriteBench",
}

logerr = lambda s: print(f"\033[91m{s}\033[0m")
logdebug = lambda s: print(f"\033[95m[DEBUG] \033[0m{s}")
loginfo = lambda s: print(f"\033[96m{s}\033[0m")
logwarn = lambda s: print(f"\033[33m{s}\033[0m")


def run_cmd(
    cmd: str,
    stderr=subprocess.STDOUT,
    stdout=None,
    check: bool = True,
    print_cmd: bool = False,
) -> subprocess.CompletedProcess:
    if print_cmd:
        loginfo(f"Run command: <{cmd}>")
    if isinstance(cmd, str):
        args = ["bash", "-c", cmd]
        return subprocess.run(args, stderr=stderr, stdout=stdout, check=check)
    elif isinstance(cmd, list):
        return subprocess.run(
            cmd, shell=True, stderr=stderr, stdout=stdout, check=check
        )
    else:
        raise ValueError(f"Invalid cmd: {cmd}")


def arg_parse(parser: argparse.ArgumentParser) -> argparse.Namespace:
    parser.add_argument("--key", "-k", type=Path, help="the public key's path.")
    return parser.parse_args()


def terraform_up() -> subprocess.CompletedProcess:
    cmd = "terraform init && terraform apply -auto-approve "
    return run_cmd(cmd)


def terraform_down() -> subprocess.CompletedProcess:
    cmd = "terraform destroy --auto-approve "
    return run_cmd(cmd)


def boot_strap(config: str, key: str):
    cmd = f"./file/dev-deploy --remote '' simple --config {config} --user 'ubuntu' --key {key} start --disable-restart all"
    return run_cmd(cmd)


def update_ssh_config(host: List[str], key: str):
    for h in host:
        path = Path("$HOME/.ssh/known_hosts")
        key_clean_cmd = f"ssh-keygen -f {path} -R {h}"
        try:
            run_cmd(key_clean_cmd)
        except Exception:
            pass

        cmd = (
            f"ssh -i {key} ubuntu@{h} -o 'StrictHostKeyChecking no' echo hello"
        )
        run_cmd(cmd)


def update_logdevice_config(address: List[str], path: str):
    addr = [f"{ip}:2181" for ip in address]
    ips = ",".join(addr)
    res = f'"ip://{ips}",'
    with open(path, "r+") as file:
        content = file.read()
        pattern = re.compile('"ip://.*')
        if re.search(pattern, content):
            out = re.sub(pattern, res, content)
            file.seek(0)
            file.truncate()
            file.write(out)
        else:
            logerr("invalid logdevice config.")
            sys.exit(1)


def run():
    parser = argparse.ArgumentParser(
        description="HStream perf script.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    args = arg_parse(parser)

    # 1. set up environment
    res = terraform_up()
    if res.returncode != 0:
        logerr(f"terraform_up err, {res.stderr}")
        sys.exit(1)
    loginfo("set up terraform success")

    # 2. boot_strap
    global ssh_cmd
    with open("./file/output", "r") as f:
        config = json.load(f)
        client_ips = config["client_public_ip"]["value"]
        server_ips = config["server_public_ip"]["value"]
        server_access_ips = config["server_access_ip"]["value"]
    update_ssh_config(server_ips, args.key)
    update_ssh_config(client_ips, args.key)
    update_logdevice_config(server_access_ips, "./file/logdevice.conf")
    boot_strap("./file/config.json", args.key)

if __name__ == "__main__":
    run()
