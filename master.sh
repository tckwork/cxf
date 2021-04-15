#!/bin/bash

##[ Imports ]####################

{
source "$(dirname $0)/utils.sh"

export CXF_VERSION="$(version master)"

./runtests "$@"
} 2>&1 | tee master.log

