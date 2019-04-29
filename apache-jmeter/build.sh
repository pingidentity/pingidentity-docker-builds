#!/usr/bin/env sh
set -x

company=pingidentity
image=apache-jmeter
VERSION=5.1.1
docker build --build-arg JMETER_VERSION=${VERSION} -t ${company}/${image}:${VERSION} .
docker tag ${company}/${image}:${VERSION} ${company}/${image}:latest