#!/usr/bin/env bash
set -euo pipefail

# Pass through the standard Helm manifest
cat <&0

cat << EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpcan
  labels:
    app: httpcan
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpcan
  template:
    metadata:
      labels:
        app: httpcan
    spec:
      containers:
        - name: httpcan
          image: ${ARTIFACTORY_REGISTRY}/httpcan:0.5.3
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: httpcan
  labels:
    app: httpcan
spec:
  selector:
    app: httpcan
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
EOF
