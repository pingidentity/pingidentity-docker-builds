#!/bin/bash

ldapsearch -p ${LDAPS_PORT} -Z -X -b "" -s base "(&)"
