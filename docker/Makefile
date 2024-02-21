#!/usr/bin/make -f

NPROCS := $(shell nproc)
export MAKEFLAGS=-j ${NPROCS}

ifdef SILENT
override SILENT=-q
endif


.PHONY: default
default: testinfra

.PHONY: clean
clean:
	docker images -a | grep 'proxysql/testing' | awk '{ print $3 }' | xargs -r docker rmi -f
	docker images -a | grep '<none>' | awk '{ print $3 }' | xargs -r docker rmi -f

.PHONY: cleanall
cleanall:
	docker system prune -a


.PHONY: testinfra
testinfra: $(wildcard testinfra-*)


.SILENT:
.PHONY: testinfra-*
testinfra-*:
	echo 'building $@'
	cp -f ../../proxysql/binaries/proxysql_*-debian11_amd64.deb ./testinfra-proxysql-dev/
	# try building both amd64 and arm64, fallback to amd64
#	docker buildx infra -t proxysql/testing:$@ --pull --platform linux/arm64,linux/amd64 $@ --push ${SILENT} || \
#	docker buildx infra -t proxysql/testing:$@ --pull --platform linux/amd64 $@ --push ${SILENT}
	# build for local tesing only
	docker build --rm --tag proxysql/testing:$@ $@ ${SILENT}
	echo 'tagged $@'


images:
	echo 'Available images:'
	docker images | grep "proxysql/testing:testinfra"
