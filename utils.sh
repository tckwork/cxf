#!/bin/bash

function stage {
    STAGE="${1?Specify a stage name}"
    echo -e "\n\033[38;5;172m$STAGE\033[0m\n"
}

function fail {
    echo -e "\n\033[38;5;196m$STAGE FAILED\033[0m\n"
    exit 1
}

function copydep {
    local dep="${1?Specify a maven coordinate}"
    local dest="${2?Specify a destination}"
    mvn org.apache.maven.plugins:maven-dependency-plugin:2.8:get \
	-DremoteRepositories=https://repository.apache.org/snapshots,https://repository.apache.org \
	-Dartifact="$dep" \
	-Dtransitive=false "-Ddest=$dest"
}
