#!/usr/bin/python3

import argparse
import subprocess
import re
from pathlib import Path
import json
import sys
from typing import List, Dict

CLUSTER_HOSTS_FILE = "./file/topology"
STORE_CONFIG_FILE = "./file/logdevice.conf"
CLUSTER_CONFIG_FILE = "./file/config.json"
PROMETHUS_CONFIG_TEMPLATE = "./file/prometheus-cfg/prometheus.template"
PROMETHUS_CONFIG_FILE = "./file/prometheus-cfg/prometheus.yml"

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
    parser.add_argument("--user", default="ubuntu", help="remote server user name.")
    return parser.parse_args()


def terraform_up() -> subprocess.CompletedProcess:
    cmd = "terraform init && terraform apply -auto-approve "
    return run_cmd(cmd)


def terraform_down() -> subprocess.CompletedProcess:
    cmd = "terraform destroy --auto-approve "
    return run_cmd(cmd)


def boot_strap(config: str, key: str, user: str):
    cmd = f"./file/dev-deploy --remote '' simple --config {config} --user '{user}' --key {key} start --disable-restart all"
    return run_cmd(cmd)


def update_ssh_config(host: List[str], key: str, user: str):
    for h in host:
        path = Path("$HOME/.ssh/known_hosts")
        key_clean_cmd = f"ssh-keygen -f {path} -R {h}"
        try:
            run_cmd(key_clean_cmd)
        except Exception:
            pass

        cmd = (
            f"ssh -i {key} {user}@{h} -o 'StrictHostKeyChecking no' echo hello"
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


def update_prometheus_config(hosts: Dict[str, str], path: str, template: str = PROMETHUS_CONFIG_TEMPLATE):
    with open(template, "r+") as file:
        content = file.read()
        for k, v in hosts.items():
            pattern = re.compile(k)
            if re.search(pattern, content):
                content = re.sub(pattern, v, content)

    with open(path, "w") as file:
        file.write(content)


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
    with open(CLUSTER_HOSTS_FILE, "r") as f:
        config = json.load(f)
        cal_ips = config["client_public_ip"]["value"]
        store_ips = config["server_public_ip"]["value"]
        store_access_ips = config["server_access_ip"]["value"]
        cal_access_ips = config["client_access_ip"]["value"]
        store_hosts = {f"hs-s{idx + 1}": ip for (idx, ip) in enumerate(store_access_ips)}
        cal_hosts = {f"hs-c{idx + 1}": ip for (idx, ip) in enumerate(cal_access_ips)}
        hosts = {**store_hosts, **cal_hosts}
    update_ssh_config(store_ips, args.key, args.user)
    update_ssh_config(cal_ips, args.key, args.user)
    update_prometheus_config(hosts, PROMETHUS_CONFIG_FILE)
    update_logdevice_config(store_access_ips, STORE_CONFIG_FILE)
    boot_strap(CLUSTER_CONFIG_FILE, args.key, args.user)


if __name__ == "__main__":
    run()
