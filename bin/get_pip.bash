#!/bin/bash

# This script updates pip and setuptools from whatever you currently have (on
# Debian wheezy, this is probably 1.1 and 0.6.24). Run this script just after
# your virtualenv is activated in the script which prepares your environment.
# If you have commonlib available, you can just run the script; otherwise use
# something like:
# curl --silent --location https://raw.github.com/mysociety/commonlib/master/bin/get_pip.bash | bash

# Upgrade pip to a secure version
curl --silent --location https://bootstrap.pypa.io/get-pip.py | python

# Upgrading distribute would install the latest version of setuptools, but we
# instead pin to a specific version in case a newer release breaks everything
# (as 18.6 did).
pip install setuptools==18.5

# We still want to upgrade distribute to prevent bdist_wheel not found errors
pip install distribute==0.7.3
