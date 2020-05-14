#!/usr/bin/env bash
# coding=utf-8

# WARNING: DO NOT EDIT!
#
# This file was generated by plugin_template, and is managed by it. Please use
# './plugin-template --travis pulp_npm' to update this file.
#
# For more info visit https://github.com/pulp/plugin_template

set -mveuo pipefail

source .github/utils.sh

export POST_SCRIPT=$GITHUB_WORKSPACE/.github/post_script.sh
export POST_DOCS_TEST=$GITHUB_WORKSPACE/.github/post_docs_test.sh
export FUNC_TEST_SCRIPT=$GITHUB_WORKSPACE/.github/func_test_script.sh

# Needed for both starting the service and building the docs.
# Gets set in .github/settings.yml, but doesn't seem to inherited by
# this script.
export DJANGO_SETTINGS_MODULE=pulpcore.app.settings
export PULP_SETTINGS=$GITHUB_WORKSPACE/.github/settings/settings.py

if [ "$TEST" = "docs" ]; then
  cd docs
  make PULP_URL="http://pulp" html
  cd ..

  if [ -f $POST_DOCS_TEST ]; then
    source $POST_DOCS_TEST
  fi
  exit
fi

cd ../pulp-openapi-generator

./generate.sh pulpcore python
pip install ./pulpcore-client
./generate.sh pulp_npm python
pip install ./pulp_npm-client
cd $GITHUB_WORKSPACE

if [ "$TEST" = 'bindings' ]; then
  python $GITHUB_WORKSPACE/.github/test_bindings.py
  cd ../pulp-openapi-generator
  if [ ! -f $GITHUB_WORKSPACE/.github/test_bindings.rb ]
  then
    exit
  fi

  rm -rf ./pulpcore-client

  ./generate.sh pulpcore ruby 0
  cd pulpcore-client
  gem build pulpcore_client
  gem install --both ./pulpcore_client-0.gem
  cd ..
  rm -rf ./pulp_npm-client

  ./generate.sh pulp_npm ruby 0

  cd pulp_npm-client
  gem build pulp_npm_client
  gem install --both ./pulp_npm_client-0.gem
  cd ..
  ruby $GITHUB_WORKSPACE/.github/test_bindings.rb
  exit
fi

cat unittest_requirements.txt | cmd_stdin_prefix bash -c "cat > /tmp/unittest_requirements.txt"
cmd_prefix pip3 install -r /tmp/unittest_requirements.txt

# Run unit tests.
cmd_prefix bash -c "PULP_DATABASES__default__USER=postgres django-admin test --noinput /usr/local/lib/python3.7/site-packages/pulp_npm/tests/unit/"

# Run functional tests
export PYTHONPATH=$GITHUB_WORKSPACE:$GITHUB_WORKSPACE/../pulpcore${PYTHONPATH:+:${PYTHONPATH}}

if [[ "$TEST" == "performance" ]]; then
  wget -qO- https://github.com/crazy-max/travis-wait-enhanced/releases/download/v1.0.0/travis-wait-enhanced_1.0.0_linux_x86_64.tar.gz | sudo tar -C /usr/local/bin -zxvf - travis-wait-enhanced
  echo "--- Performance Tests ---"
  if [[ -z ${PERFORMANCE_TEST+x} ]]; then
    travis-wait-enhanced --interval=1m --timeout=40m -- pytest -vv -r sx --color=yes --pyargs --capture=no --durations=0 pulp_npm.tests.performance
  else
    travis-wait-enhanced --interval=1m --timeout=40m -- pytest -vv -r sx --color=yes --pyargs --capture=no --durations=0 pulp_npm.tests.performance.test_$PERFORMANCE_TEST
  fi
  exit
fi

if [ -f $FUNC_TEST_SCRIPT ]; then
  source $FUNC_TEST_SCRIPT
else
    pytest -v -r sx --color=yes --pyargs pulp_npm.tests.functional
fi

if [ -f $POST_SCRIPT ]; then
  source $POST_SCRIPT
fi
