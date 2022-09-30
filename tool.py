#!/usr/bin/python3

import argparse
import subprocess
from pathlib import Path
import json
import sys
from jinja2 import Environment, FileSystemLoader
from typing import List, Mapping, NamedTuple, Any

CLUSTER_HOSTS_FILE = "node_info"
CLOUD_PLATFORM = ["ali-cloud", "aws"]
CLUSTER_INFO_FILE = "cluster_info"

logerr = lambda s: print(f"\033[91m{s}\033[0m")
logdebug = lambda s: print(f"\033[95m[DEBUG] \033[0m{s}")
loginfo = lambda s: print(f"\033[96m{s}\033[0m")
logwarn = lambda s: print(f"\033[33m{s}\033[0m")

try:
    import argcomplete
except Exception:
    from unittest.mock import MagicMock

    argcomplete = MagicMock()
    argcomplete.autocomplete = lambda x: logwarn("There is no tab completion supported since no argcomplete found!")


def run_cmd(
    cmd: str,
    stderr=subprocess.STDOUT,
    stdout=None,
    check: bool = True,
    print_cmd: bool = True,
) -> subprocess.CompletedProcess:
    if print_cmd:
        loginfo(f"Run command: <{cmd}>")
    if isinstance(cmd, str):
        args = ["bash", "-c", cmd]
        return subprocess.run(args, stderr=stderr, stdout=stdout, check=check)
    elif isinstance(cmd, list):
        return subprocess.run(cmd, shell=True, stderr=stderr, stdout=stdout, check=check)
    else:
        raise ValueError(f"Invalid cmd: {cmd}")


def parse_start_cmd(parser: argparse.ArgumentParser) -> argparse.Namespace:
    parser.add_argument("--key", "-k", type=Path, help="the public key's path.")
    parser.add_argument("--user", default="ubuntu", help="remote server user name.")
    parser.add_argument(
        "--cloud",
        "-c",
        default="ali-cloud",
        choices=CLOUD_PLATFORM,
        help="cloud server platform.",
    )
    return parser.parse_args()


def terraform_up(cloud: str) -> subprocess.CompletedProcess:
    cmd = ""
    if cloud == "ali-cloud":
        cmd = "cd aliyun && terraform init && terraform apply -auto-approve "
    elif cloud == "aws":
        cmd = "cd aws && terraform init && terraform apply -auto-approve "
    else:
        logerr(f"Unsupported cloud platform: {cloud}")
        exit(1)
    return run_cmd(cmd)


def terraform_down(cloud) -> subprocess.CompletedProcess:
    cmd = ""
    if cloud == "ali-cloud":
        cmd = "cd aliyun && terraform destroy --auto-approve"
    elif cloud == "aws":
        cmd = "cd aws && terraform destroy --auto-approve"
    else:
        logerr(f"Unsupported cloud platform: {cloud}")
        exit(1)
    return run_cmd(cmd)


class NodeInfo(NamedTuple):
    access_ip: str
    public_ip: str
    instance_type: str


def get_nodes_by_instance(nodes: List[NodeInfo], cnt: int) -> List[Mapping[str, str]]:
    if len(nodes) < cnt:
        logerr(f"the number of {nodes[0].instance_type} nodes less than {cnt}")
        exit(1)
    return [{"private_ip": nodes[i].access_ip, "public_ip": nodes[i].public_ip} for i in range(0, cnt)]


def parse_node_info() -> Mapping[str, List[NodeInfo]]:
    with open(CLUSTER_HOSTS_FILE, "r") as f:
        config = json.load(f)
        node_info = config["node_info"]["value"]
    nodes = [NodeInfo(v["access_ip"], v["public_ip"], v["instance_type"]) for _, v in node_info.items()]

    nodes_by_type = {}
    for _, v in enumerate(nodes):
        ls = nodes_by_type.get(v.instance_type, [])
        ls.append(v)
        nodes_by_type[v.instance_type] = ls
    return nodes_by_type


def get_deploy_topology() -> Mapping[str, Any]:
    nodes_by_type = parse_node_info()

    with open("topology.json", "r") as f:
        topo = json.load(f)

    res = {}
    for k, v in topo.items():
        if k == "center":
            center_node = nodes_by_type[v["instance_type"]][0].public_ip
            res["center"] = center_node
            logdebug(f"get center node ip: {center_node}")
        else:
            if v["count"] == 0:
                continue

            host = get_nodes_by_instance(nodes_by_type[v["instance_type"]], v["count"])
            image = v.get("image", "")
            res[k] = {"hosts": host, "image": image}
    res["hadmin"] = res["hstore"]["hosts"][0]
    return res


def config_gen(deploy_topology: Mapping[str, Any], user: str) -> str:
    deploy_topology["user"] = user
    deploy_topology["key_path"] = "~/.ssh/id_rsa"
    environment = Environment(loader=FileSystemLoader("template/"))
    template = environment.get_template("config.yaml")
    content = template.render(deploy_topology)
    results_filename = "config/config.yaml"
    with open(results_filename, "w", encoding="utf-8") as f:
        f.write(content)
    persistent_cluster_info(deploy_topology)
    return results_filename


def persistent_cluster_info(deploy_topoloy: Mapping[str, Any]) -> None:
    with open(CLUSTER_INFO_FILE, "w", encoding="utf-8") as f:
        res = json.dumps(deploy_topoloy, indent=2)
        loginfo(f"cluster info:\n{res}")
        f.write(res)


def set_up_cluster(key: str, user: str, host: str):
    ssh_cmd = f"ssh -i {key} {user}@{host} -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile=/dev/null'"
    scp_config = f"scp -i {key} -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile=/dev/null' -r config {user}@{host}:/hstream_config "
    run_cmd(scp_config)

    run_cmd(f"{ssh_cmd} 'cd /hstream_config && ./hdt init && ./hdt start -c config.yaml -i " f"~/.ssh/id_rsa'")


class Command:
    subCommands = {}

    def __init__(self):
        self.parser = argparse.ArgumentParser(
            description="HStream Deploy Tool.",
            formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        )

    def run(self):
        argcomplete.autocomplete(self.parser)
        subparsers = self.parser.add_subparsers()
        for name, cmd in self.subCommands.items():
            cmd_instance = cmd()
            subparser = subparsers.add_parser(name, help=cmd_instance.Describe)
            subparser.set_defaults(handle=cmd_instance.handle)
            cmd_instance.add_argument(subparser)

        args = self.parser.parse_args()
        if hasattr(args, "handle"):
            args.handle(args)

    def register(self, subCmd):
        self.subCommands[subCmd.Name] = subCmd

    def add_argument(self, parser):
        pass

    def handle(self, args):
        pass


class StartCmd(Command):
    Name = "start"
    Describe = "Set up HStreamDB Cluster"

    def add_argument(self, parser):
        parser.add_argument("--key", "-k", type=Path, help="the public key's path.")
        parser.add_argument("--user", default="root", help="remote server user name.")
        parser.add_argument(
            "--cloud",
            "-c",
            default="ali-cloud",
            choices=CLOUD_PLATFORM,
            help="cloud server platform.",
        )
        parser.add_argument(
            "--skip-terraform",
            "-s",
            action="store_true",
            help="skip starting machines with terraform",
        )

    def handle(self, args):
        # 1. set up environment
        if not args.skip_terraform:
            res = terraform_up(args.cloud)
            if res.returncode != 0:
                logerr(f"terraform_up err, {res.stderr}")
                sys.exit(1)
            loginfo("set up terraform success")

        # 2. generate cluster config file
        deploy_topology = get_deploy_topology()
        config_gen(deploy_topology, args.user)
        loginfo("generate cluster config file success")

        # 3. set up cluster
        set_up_cluster(args.key, args.user, deploy_topology["center"])


class RemoveCmd(Command):
    Name = "remove"
    Describe = "Remove HStreamDB Cluster"

    def add_argument(self, parser):
        parser.add_argument("--key", "-k", type=Path, help="the public key's path.")
        parser.add_argument("--user", default="root", help="remote server user name.")

    def handle(self, args):
        try:
            with open(CLUSTER_INFO_FILE, "r", encoding="utf-8") as f:
                res = json.load(f)
        except FileNotFoundError:
            res = get_deploy_topology()

        ssh_cmd = (
            f"ssh -i {args.key} {args.user}@{res['hadmin'].get('public_ip')} -o 'StrictHostKeyChecking no' "
            f"-o 'UserKnownHostsFile=/dev/null'"
        )
        run_cmd(f"{ssh_cmd} 'cd /hstream_config && ./hdt remove -c config.yaml -i ~/.ssh/id_rsa'")


class DestroyCmd(Command):
    Name = "destroy"
    Describe = "Terraform Destroy."

    def add_argument(self, parser):
        parser.add_argument(
            "--cloud",
            "-c",
            default="ali-cloud",
            choices=CLOUD_PLATFORM,
            help="cloud server platform.",
        )

    def handle(self, args):
        terraform_down(args.cloud)


class InfoCmd(Command):
    Name = "info"
    Describe = "Get cluster info."

    def add_argument(self, parser):
        pass

    def handle(self, args):
        try:
            with open(CLUSTER_INFO_FILE, "r", encoding="utf-8") as f:
                res = json.load(f)
        except FileNotFoundError:
            res = get_deploy_topology()

        loginfo(f"center node: {res['center']}")
        loginfo(f"admin node: {res['hadmin']['public_ip']}")
        if prometheus := res.get("prometheus"):
            loginfo(f"prometheus address: {prometheus['hosts'][0]['public_ip']}:9090")
        if grafana := res.get("grafana"):
            loginfo(f"prometheus address: {grafana['hosts'][0]['public_ip']}:3000")


if __name__ == "__main__":
    c = Command()
    c.register(StartCmd)
    c.register(RemoveCmd)
    c.register(DestroyCmd)
    c.register(InfoCmd)
    c.run()
