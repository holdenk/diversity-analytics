#!/bin/bash

# This script installs Jupyter notebook (http://jupyter.org/) on a Google Cloud
# Dataproc cluster.
# Jupyter is successor of iPython Notebook
#
# This init action depends on init-action for Conda. Git repo and branch for
# init actions might be overridden by specifying INIT_ACTIONS_REPO and
# INIT_ACTIONS_BRANCH metadata keys.

set -exo pipefail
echo "Running V: Boo-4"

gsutil cp gs://boo-stuff/extra.sh ./
chmod a+x extra.sh
# Begin secrets
gsutil cp gs://boo-stuff/secrets.sh ./
gsutil cp gs://boo-stuff/secrets.literal ./
source ./secrets.sh
mkdir -p ~/
cat secrets.sh >> ~/.bashrc


readonly ROLE="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"

readonly DEAFULT_INIT_ACTIONS_REPO="gs://dataproc-initialization-actions"
readonly INIT_ACTIONS_REPO="$(/usr/share/google/get_metadata_value attributes/INIT_ACTIONS_REPO ||
  echo ${DEAFULT_INIT_ACTIONS_REPO})"
readonly INIT_ACTIONS_BRANCH="$(/usr/share/google/get_metadata_value attributes/INIT_ACTIONS_BRANCH ||
  echo 'master')"

# Colon-separated list of conda channels to add before installing packages
readonly JUPYTER_CONDA_CHANNELS="$(/usr/share/google/get_metadata_value attributes/JUPYTER_CONDA_CHANNELS || true)"

# Colon-separated list of conda packages to install, for example 'numpy:pandas'
readonly JUPYTER_CONDA_PACKAGES="$(/usr/share/google/get_metadata_value attributes/JUPYTER_CONDA_PACKAGES || true)"

readonly INSTALL_JUPYTER_EXT="$(/usr/share/google/get_metadata_value attributes/INSTALL_JUPYTER_EXT ||
  echo 'false')"

echo "Cloning initialization actions from '${INIT_ACTIONS_REPO}' repo..."
INIT_ACTIONS_DIR=$(mktemp -d -t dataproc-init-actions-XXXX)
readonly INIT_ACTIONS_DIR
export INIT_ACTIONS_DIR
if [[ ${INIT_ACTIONS_REPO} == gs://* ]]; then
  gsutil -m rsync -r "${INIT_ACTIONS_REPO}" "${INIT_ACTIONS_DIR}"
else
  git clone -b "${INIT_ACTIONS_BRANCH}" --single-branch "${INIT_ACTIONS_REPO}" "${INIT_ACTIONS_DIR}"
fi
find "${INIT_ACTIONS_DIR}" -name '*.sh' -exec chmod +x {} \;

# Ensure we have Conda installed.
bash "${INIT_ACTIONS_DIR}/conda/bootstrap-conda.sh"

if [[ -f /etc/profile.d/conda.sh ]]; then
  source /etc/profile.d/conda.sh
fi

if [[ -f /etc/profile.d/effective-python.sh ]]; then
  source /etc/profile.d/effective-python.sh
fi

# Install jupyter on all nodes to start with a consistent python environment
# on all nodes. Also, pin the python version to ensure that conda does not
# update python because the latest version of jupyter supports a higher version
# than the one already installed. See issue #300 for more information.
PYTHON="$(ls /opt/conda/bin/python || command -v python)"
PYTHON_VERSION="$(${PYTHON} --version 2>&1 | cut -d ' ' -f 2)"
conda install jupyter matplotlib "python==${PYTHON_VERSION}"
# Extra PySpark stuff
PYSPARK_PYTHON="${PYTHON}"
PYSPARK_DRIVER_PYTHON="${PYTHON}"
export PYSPARK_PYTHON
export PYSPARK_DRIVER_PYTHON


conda install 'testpath<0.4'

if [ -n "${JUPYTER_CONDA_CHANNELS}" ]; then
  IFS=":" read -r -a channels <<<"${JUPYTER_CONDA_CHANNELS}"
  echo "Adding custom conda channels '${channels[*]}'"
  for channel in "${channels[@]}"; do
    conda config --add channels "${channel}"
  done
fi

if [ -n "${JUPYTER_CONDA_PACKAGES}" ]; then
  IFS=":" read -r -a packages <<<"${JUPYTER_CONDA_PACKAGES}"
  echo "Installing custom conda packages '${packages[*]}'"
  conda install "${packages[@]}"
fi

# For storing notebooks on GCS. Pin version to make this script hermetic.
pip install jgscm==0.1.7

if [[ "${ROLE}" == 'Master' ]]; then
  "${INIT_ACTIONS_DIR}/jupyter/internal/setup-jupyter-kernel.sh"
  "${INIT_ACTIONS_DIR}/jupyter/internal/launch-jupyter-kernel.sh"
fi
echo "Completed installing Jupyter!"

# Install Jupyter extensions (if desired)
# TODO: document this in readme
if [[ "${INSTALL_JUPYTER_EXT}" == true ]]; then
  echo "Installing Jupyter Notebook extensions..."
  "${INIT_ACTIONS_DIR}/jupyter/internal/bootstrap-jupyter-ext.sh"
  echo "Jupyter Notebook extensions installed!"
fi


echo "Starting extra..."
whoami
./extra.sh &> /tmp/extra_log &
extra_pid=$!
disown $extra_pid
echo "Done."
