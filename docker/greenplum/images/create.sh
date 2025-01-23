#! /bin/bash
# Author: Andrey Shurenkov

base_dir="$(dirname "$0")"

dockerfile_path="$base_dir/Dockerfile"

build_context="$base_dir"

docker build -f $dockerfile_path -t greenplumdb:6.25.3 $build_context