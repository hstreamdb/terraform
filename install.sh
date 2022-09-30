#!/bin/bash

set -e

mkdir -p download && pushd download
wget https://github.com/hstreamdb/deployment-tool/releases/download/v0.1.0/deployment-tool-v0.1.0-linux-amd64.tar.gz
tar -xzf deployment-tool-v0.1.0-linux-amd64.tar.gz
mv ./bin/hdt ../config/hdt
popd && rm -rf download
