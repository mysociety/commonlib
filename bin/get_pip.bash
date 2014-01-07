#!/bin/bash

# Latest pip requires a newer version of setuptools than we can easily get on
# Debian. There is some background here:
#
# http://stackoverflow.com/questions/20905350/latest-pip-fails-with-requires-setuptools-0-8-for-dist-info
# https://github.com/pypa/pip/issues/1422
#
# We should be able to retire this script once we have upgraded from wheezy
# to jessie.

# In the meantime, in the script which prepares your environment (often called
# prepare_environment.bash), you need to run this script just after your
# virtualenv is activated. If you have commonlib available, you can just run
# the script, otherwise, use something like

# curl -s https://raw.github.com/mysociety/commonlib/master/bin/get_pip.bash | bash


# Upgrade pip to a secure version
curl -s https://raw.github.com/pypa/pip/master/contrib/get-pip.py | python

# The latest pip requires a newer version of setuptools than we have
pip install setuptools --no-use-wheel --upgrade
