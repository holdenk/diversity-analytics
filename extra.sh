#!/bin/bash

echo "Running extra V1.1"

conda install -c anaconda nltk scipy pandas
conda install -c conda-forge spacy


pip install --upgrade pip &
pip_pid=$!
# TODO: Post sparklingml on pypi so we don't have to do this
git clone git://github.com/sparklingpandas/sparklingml.git || echo "Already cloned"
chown -R yarn sparklingml
pushd sparklingml
git pull || echo "Failed to update sparklingml, using old checkout"
./build/sbt assembly &> sbt_outputlog &
sbt_pid=$!
popd

# See issue: https://github.com/nteract/coffee_boat/issues/47
mkdir -p /home/nltk_data
chown -R yarn /home/nltk_data
python -m nltk.downloader vader_lexicon &> vader_install_log &
python -c "import spacy;spacy.load('en')" || python -m spacy download en &> spacy_install_en_log &
wait $pip_pid || echo "Already upgraded pip"
# We end up using system pyspark anyways and pypandoc is having issues
#pip install "pyspark==2.3.0"
pip install perceval
pip install urllib3
pip install beautifulsoup4
pip install requests
pip install "selenium==3.6.0"
pip install zope.interface
pip install pyarrow
pip install meetup.api
pip install statsmodels
pip install backoff
pip install gender-guesser
pip install nameparser
pip install Genderize
# Wait for sparklingml's sbt build to be finished then install the rest of sparklingml
wait $sbt_pid || echo "sbt_pid already installed"
pushd /sparklingml
pip install -e . || echo "Failed to install sparklingml, soft skip."
popd
# nltk data needs to be readable by the user we run as
chown -R yarn /home/nltk_data
cat vader_install_log
pip install twython "tensorboard==1.7.0" "tensorflow==1.7.0" PyGithub coffee_boat PyVirtualDisplay &
echo "Done"
