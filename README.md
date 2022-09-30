# terraform

Deploy HStreamDB cluster on AWS/Ali-Cloud with terraform.

## Usage

### Clone the repository

```shell
git clone git@github.com:hstreamdb/terraform.git && cd terraform
```

### Download deployment-tool

```shell
./install.sh
```

- The binary is placed in `./config` directory.

### Update terraform.tfvars

Update the `terraform.tvar` file to meet your deployment requirements.

- For ali-cloud, the path is `./aliyun/terraform.tfvars`
- For aws, the path is `./aws/terraform.tfvars`

### Update `topology.json`

Each Component has three fields:

- `count`: number of the instances of the component
- `instance_type`: specifications of the cloud server on which the instance is deployed
- `image`: docker image of the component

#### `center` server

The deployment process will be synchronized to the cloud server specified by the `center` field, which has been configured SSH mutual trust with other servers.

No need to have a separate node for the `center` server

### Set up cluster

```ssh
./tool.py start -k <key-pair> --user <username> -c ali-cloud
```

- fill in the key-pair which used to connect to connect to `center` server with SSH
- fill in the username which used to log in `center` server
- use `-c` to specified which cloud you want to deploy to, the valid value should be `-c ali-cloud` or `-c aws`

### Remove cluster

Remove cluster will stop all started instances and delete all related records.

```shell
./tool.py remove -k <key-pair> --user <username> -c ali-cloud
```

### Destroy cluster

Destroy cluster uses terraform to destroy all previously created infrastructure.

```shell
./tool.py destroy -c ali-cloud
```

- use `-c` to specified which cloud you want to deploy to, the valid value should be `-c ali-cloud` or `-c aws`
