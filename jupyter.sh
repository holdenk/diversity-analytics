#!/bin/bash

# This script installs Jupyter notebook (http://jupyter.org/) on a Google Cloud
# Dataproc cluster.
# Jupyter is successor of iPython Notebook
#
# This init action depends on init-action for Conda. Git repo and branch for
# init actions might be overridden by specifying INIT_ACTIONS_REPO and
# INIT_ACTIONS_BRANCH metadata keys.

set -exo pipefail

# Begin secrets
gsutil cp gs://boo-stuff/secrets.sh ./
gsutil cp gs://boo-stuff/secrets.literal ./
source ./secrets.sh
mkdir -p ~/
cat secrets.sh >> ~/.bashrc
# End secrets
# Begin quasi related tf accel work
gsutil cp gs://boo-stuff/tfs.tbz2 ./
tar -xvf tfs.tbz2
virtualenv --python=python3 /home/hkarau/tf_spark_venv_py3/
source /home/hkarau/tf_spark_venv_py3/bin/activate
pip install pyspark==2.3.0
pushd TensorFlowOnSpark
pip install -e .
popd
deactivate
# End quasi related tf accel work

DEBIAN_FRONTEND=noninteractive
# Debian mirrors aren't super reliable so dynamically rewrite because life is "awesome"
sudo apt-get install -y aptitude
sudo aptitude update || sudo apt-get update || sed  s/deb.debian/ftp.ca.debian/g /etc/apt/sources.list  > srclist && sudo mv srclist /etc/apt/sources.list && sudo apt-get update || echo "w/e hope this works"
sudo apt-get install -y firefox-esr
sudo apt-get install -y chromedriver
sudo apt-get install -y xvfb
sudo apt-get install -y pssh
wget https://github.com/mozilla/geckodriver/releases/download/v0.20.0/geckodriver-v0.20.0-linux64.tar.gz
tar -xvf geckodriver-v0.20.0-linux64.tar.gz
sudo mv geckodriver /bin/

export PATH="$PATH:/usr/lib/chromium/"
echo "export PATH=\"\$PATH:/usr/lib/chromium/\"" >> /etc/bash.bashrc

# Hack
wget https://raw.githubusercontent.com/holdenk/diversity-analytics/master/lazy_helpers.py

readonly ROLE="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
readonly INIT_ACTIONS_REPO="$(/usr/share/google/get_metadata_value attributes/INIT_ACTIONS_REPO \
  || echo 'https://github.com/GoogleCloudPlatform/dataproc-initialization-actions.git')"
readonly INIT_ACTIONS_BRANCH="$(/usr/share/google/get_metadata_value attributes/INIT_ACTIONS_BRANCH \
  || echo 'master')"

# Colon-separated list of conda channels to add before installing packages
readonly JUPYTER_CONDA_CHANNELS="$(/usr/share/google/get_metadata_value attributes/JUPYTER_CONDA_CHANNELS)"

# Colon-separated list of conda packages to install, for example 'numpy:pandas'
readonly JUPYTER_CONDA_PACKAGES="$(/usr/share/google/get_metadata_value attributes/JUPYTER_CONDA_PACKAGES)"

echo "Cloning fresh dataproc-initialization-actions from repo ${INIT_ACTIONS_REPO} and branch ${INIT_ACTIONS_BRANCH}..."
git clone -b "${INIT_ACTIONS_BRANCH}" --single-branch "${INIT_ACTIONS_REPO}"

# Ensure we have conda installed.
./dataproc-initialization-actions/conda/bootstrap-conda.sh

source /etc/profile.d/conda.sh

if [ -n "${JUPYTER_CONDA_CHANNELS}" ]; then
  echo "Adding custom conda channels '${JUPYTER_CONDA_CHANNELS//:/ }'"
  conda config --add channels "${JUPYTER_CONDA_CHANNELS//:/,}"
fi

if [ -n "${JUPYTER_CONDA_PACKAGES}" ]; then
  echo "Installing custom conda packages '${JUPYTER_CONDA_PACKAGES/:/ }'"
  # Do not use quotes so that space separated packages turn into multiple arguments
  conda install ${JUPYTER_CONDA_PACKAGES//:/ }
fi

pip install --upgrade pip
# TODO: Post sparklingml on pypi so we don't have to do this
git clone git://github.com/sparklingpandas/sparklingml.git || echo "Already cloned"
pushd sparklingml
git pull
./build/sbt assembly &
sbt_pid=$!
popd
# We end up using system pyspark anyways and pypandoc is having issues
#pip install "pyspark==2.3.0"
pip install perceval
pip install urllib3
pip install beautifulsoup4
pip install requests
pip install "selenium==3.6.0"
pip install zope.interface
pip install nltk
pip install pyarrow
pip install spacy
pip install meetup.api
pip install PyVirtualDisplay
pip install statsmodels
pip install "tensorboard==1.7.0" "tensorflow==1.7.0" &
pip install coffee_boat
pip install PyGithub
pip install backoff
pip install twython
pip install scipy
pip install numpy
pip install pandas
# Wait for sparklingml's sbt build to be finished then install the rest of sparklingml
pushd sparklingml
wait $sbt_pid || echo "sbt finished, no waiting required."
pip install -e .
popd
# See issue: https://github.com/nteract/coffee_boat/issues/47
python -m nltk.downloader vader_lexicon &
python -c "import spacy;spacy.load('en')" || python -m spacy download en &


if [[ "${ROLE}" == 'Master' ]]; then
  conda install jupyter

  # For storing notebooks on GCS. Pin version to make this script hermetic.
  pip install jgscm==0.1.7

  ./dataproc-initialization-actions/jupyter/internal/setup-jupyter-kernel.sh
  ./dataproc-initialization-actions/jupyter/internal/launch-jupyter-kernel.sh
fi
echo "Completed installing Jupyter!"

# Install Jupyter extensions (if desired)
# TODO: document this in readme
if [[ ! -v "${INSTALL_JUPYTER_EXT}" ]]; then
  INSTALL_JUPYTER_EXT=false
fi
if [[ "${INSTALL_JUPYTER_EXT}" = true ]]; then
  echo "Installing Jupyter Notebook extensions..."
  ./dataproc-initialization-actions/jupyter/internal/bootstrap-jupyter-ext.sh
  echo "Jupyter Notebook extensions installed!"
fi
