#!/bin/bash

##[ Imports ]####################

{
source "$(dirname $0)/utils.sh"

export CXF_VERSION="$(version 3.4.x-fixes)"

./runtests "$@"
} 2>&1 | tee 3.4.x-fixes.log

