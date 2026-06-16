#!/bin/bash -ex
set -x
PRODUCT=$1
RELEASE=$2
VERSION=$3
BLD_NUM=$4

git clone ssh://git@github.com/couchbaselabs/agentmemory.git
pushd agentmemory
if git rev-parse --verify --quiet ${VERSION} >& /dev/null
then
    echo "Tag ${VERSION} exists, checking it out"
    git checkout ${VERSION}
else
    echo "No tag ${VERSION}, assuming master"
fi

# Black Duck Detect only inspects the venv whose path blackduck-detect-scan.sh
# passes to run-scanner via --python-venv: detect.pip.path / detect.python.path
# are pinned to "${venv}" (= "${PROD_DIR}/.venv"). The orchestrator creates that
# venv as Python 3.11, but agentmemory needs 3.12 (python_requires>=3.12, and
# requirements.lock is hash-pinned to cp312 wheels). Installing into a private
# venv would leave "${venv}" empty, so the PIP detector would find nothing and
# the BOM/import would come back empty. Recreate "${venv}" itself as 3.12 and
# install into it -- the orchestrator explicitly leaves room for projects that
# need to control their own python version. ($venv is in scope because this
# script is sourced; fall back to ${PROD_DIR}/.venv for standalone runs.)
venv="${venv:-${PROD_DIR}/.venv}"
rm -rf "${venv}"
uv venv --python 3.12 --python-preference only-managed "${venv}"
source "${venv}/bin/activate"
python -m ensurepip --upgrade --default-pip

# requirements.lock is the exact, hash-pinned closure the Docker image ships
# (uv pip compile --generate-hashes). Installing it makes the Detect PIP
# inspector report the production versions rather than a fresh PyPI re-resolve.
# The presence of hashes auto-enables pip's --require-hashes mode.
pip install -r requirements.lock

# Install the project itself (no deps, they are already pinned above) so the
# agentmemory package appears as the BOM root.
pip install -e . --no-deps
popd
