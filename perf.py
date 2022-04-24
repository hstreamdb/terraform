#!/usr/bin/python3

import argparse
import subprocess
import re
from pathlib import Path
import json
import sys
from typing import List
import datetime
from collections import defaultdict
import matplotlib.pyplot as plt

TOTAL_TEST = ["read", "write", "end-to-end"]
CMDS = {
    "read": "./gradlew readBench",
    "write": "./gradlew writeBench",
    "end-to-end": "./gradlew readWriteBench",
}

ssh_cmd = ""

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


def run_test(cmd: str, address: str, path: Path):
    url = f"--service-url {address}" if address is not None else ""
    command = f"{ssh_cmd} 'cd /tmp/bench && {CMDS[cmd]} --args=\"{url} --bench-time 10\"'"

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    result_file = (path / f"{cmd}_{timestamp}.log").as_posix()
    with open(result_file, "a") as file:
        run_cmd(command, file, file)


def arg_parse(parser: argparse.ArgumentParser) -> argparse.Namespace:
    parser.add_argument(
        "--remote", "-r", type=str, help="working node's address."
    )
    parser.add_argument("--key", "-k", type=Path, help="the public key's path.")
    total_tests = TOTAL_TEST[:]
    total_tests.append("all")
    parser.add_argument(
        "--test",
        "-t",
        choices=total_tests,
        nargs="+",
        default=[],
        help="test need to run. user can specify multi test items, e.g: -t read write",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="/tmp",
        type=Path,
        help="result directory path.",
    )
    return parser.parse_args()


def terraform_up() -> subprocess.CompletedProcess:
    cmd = "terraform init && terraform apply -auto-approve "
    # cmd = "terraform apply -auto-approve "
    return run_cmd(cmd)


def terraform_down() -> subprocess.CompletedProcess:
    cmd = "terraform destroy --auto-approve "
    return run_cmd(cmd)


def boot_strap(config: str, key: str):
    cmd = f"./file/dev-deploy --remote '' simple --config {config} --user 'root' --key {key} start --disable-restart all"
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
            f"ssh -i {key} root@{h} -t -o 'StrictHostKeyChecking no' echo hello"
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


def log_analyze(input: str, output: str, interval: int):
    records = defaultdict(list)
    with open(input, "r") as file:
        pattern = re.compile(r"\[([a-zA-Z]+)\].* throughput (\d+.?\d+) MB/s")
        for line in file.readlines():
            if res := re.match(pattern, line):
                records[res.group(1)].append(res.group(2))

    fig, ax = plt.subplots(figsize=(10, 5))
    for key, values in records.items():
        times = [(i + 1) * interval for i in range(len(values))]
        throughput = list(map(lambda x: float(x), values))
        ax.plot(times, throughput, label=key)
    ax.set_xlabel("elapsed time(s)")
    ax.set_ylabel("throughput(MB/s)")
    title = (
        f"{list(records.keys())[0]}_test_result"
        if len(records) == 1
        else "end2end_test_result"
    )
    ax.set_title(title)
    ax.legend()
    fig.savefig(output)
    plt.close(fig)


def run():
    parser = argparse.ArgumentParser(
        description="HStream perf script.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    args = arg_parse(parser)

    # # 1. set up environment
    res = terraform_up()
    if res.returncode != 0:
        logerr(f"terraform_up err, {res.stderr}")
        sys.exit(1)
    loginfo("set up terraform success")
    get_cluster_info = (
        "terraform refresh && terraform output -json > ./file/output"
    )
    run_cmd(get_cluster_info)

    # 2. boot_strap
    global ssh_cmd
    with open("./file/output", "r") as f:
        config = json.load(f)
        client_address = config["client_public_ip"]["value"]
        client_ips = config["client_public_ip"]["value"]
        server_ips = config["server_public_ip"]["value"]
        server_access_ips = config["server_access_ip"]["value"]
    update_ssh_config(server_ips, args.key)
    update_ssh_config(client_ips, args.key)
    update_logdevice_config(server_access_ips, "./file/logdevice.conf")
    boot_strap("./file/config", args.key)

    ssh_cmd = f"ssh -i {args.key} root@{client_address[0]} -t "

    # # 3. run test
    # tests = set()
    # for test in args.test:
    #     if test == 'all':
    #         tests.update(TOTAL_TEST)
    #     else:
    #         tests.add(test)

    # output = args.output
    # output.mkdir(exist_ok=True, parents=True)

    # run_cmd(f"{ssh_cmd} 'cd /tmp/bench && chmod +x gradlew'")
    # server_address = ",".join(map(lambda x: f"{x}:6570", config["server_access_ip"]["value"]))
    # for test in tests:
    #     run_test(test, server_address, output)

    # # 4. analyze logs
    # log_analyze("./test/res", "./test/out.png", 1)


if __name__ == "__main__":
    run()
