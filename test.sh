#!/usr/bin/env bash

set -ex

# Pull sub-chart dependencies (PostgreSQL / Redis from the Bitnami OCI registry)
helm dependency build fn

# Lint and render the templates to catch API / schema regressions
helm lint fn
helm template fn-test fn > /dev/null
