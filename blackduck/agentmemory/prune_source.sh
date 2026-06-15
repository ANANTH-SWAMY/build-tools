#!/bin/bash -ex
pushd agentmemory
# Test/dev tooling, examples and docs are not part of the shipped package.
rm -rf tests examples docs
popd
