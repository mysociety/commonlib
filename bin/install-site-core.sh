#!/bin/sh

# This script will install mySociety sites on a clean install of Debian
# or Ubuntu. It contains common code that starts the installation and
# sources a site-specific script, called either
# bin/site-specific-install.sh or script/site-specific-install.sh.

# WARNING: This script makes significant changes to the server’s setup,
# including modifying the web server setup, creating a user account and
# database, installing new packages, etc. Typically you should only use
# this on a clean install, such as a new EC2 instance.

# The usage is:
#
#   install-site.sh [--dev] [--default] [--systemd] [--docker] SITE-NAME UNIX-USER [HOST]
#
# ... where --default means to install as the default site for this
# server, rather than a virtualhost for HOST.  HOST is only optional
# if you are installing onto an EC2 instance.
#
# --dev will work from a checkout of the repository in your current directory,
# (it will check it out if not present, do nothing if it is), and will be
# passed down to site specific scripts so they can e.g. not install nginx.
#
# --systemd will check for and use a native systemd unit file if a suitable
# template is provided in the source repository.
#
# --docker will set some further variables (including --default) to prevent
# installing additional software into the image.
#

set -e
if [ x$mySociety_installfns_included = x ]; then
    script_dir=$(dirname "$(readlink -f -- "$0")")
    . $script_dir/../shlib/installfns
fi

# $0 might not refer to a file, most commonly in the situation where
# you're piping the script from curl directly to "sh -s".  Since
# Alaveteli on EC2 requires a copy of the install script, we don't
# support running this script by piping directly from curl any more.
if [ ! -f "$0" ]
then
    error_msg "Couldn't find the location of this script:"
    error_msg "Please run it as './install-site.sh ...' or 'sh install-site.sh ...'"
    exit 1
fi

# Parse arguments

DEVELOPMENT_INSTALL=false
if [ x"$1" = x"--dev" -o x"$1" = x"--development" ]
then
    error_msg DEVELOPMENT INSTALL
    DEVELOPMENT_INSTALL=true
    shift
fi

DEFAULT_SERVER=false
DEFAULT_PARAMETER=
if [ x"$1" = x"--default" ]
then
    DEFAULT_SERVER=true
    DEFAULT_PARAMETER='--default'
    shift
fi

SYSTEMD=false
if [ x"$1" = x"--systemd" ]
then
    SYSTEMD=true
    shift
fi

DOCKER=false
INSTALL_DB=true
INSTALL_POSTFIX=true
PACKAGE_SUFFIX=
if [ x"$1" = x"--docker" ]
then
    DOCKER=true
    INSTALL_DB=false
    DEFAULT_SERVER=true
    PACKAGE_SUFFIX=docker
    shift
fi

if [ x"$1" = x"--slim" ]
then
    DOCKER=false
    INSTALL_DB=false
    DEFAULT_SERVER=true
    PACKAGE_SUFFIX=docker
    shift
fi

usage_and_exit() {
    cat >&2 <<EOUSAGE
Usage: $0 [--dev] [--default] [--systemd] [--docker] [--slim] <SITE-NAME> <UNIX-USER> [HOST]
HOST is only optional if you are running this on an EC2 instance.
--default means to install as the default site for this server,
rather than a virtualhost for HOST.
--dev sets things up for a local development environment.
--docker is intended when running this script from a Dockerfile and
sets a number of other local variables controlling behaviour.
--slim similar to Docker, intended for builds without databases and other
backend applications included.
--systemd try and use a native systemd unit file rather than a sysvinit script.
EOUSAGE
    exit 1
}

if [ $# -lt 2 ]
then
    usage_and_exit
fi

SITE="$1"
UNIX_USER="$2"

case "$SITE" in
    fixmystreet | mapit | theyworkforyou | pombola | alaveteli)
        if [ $DOCKER = true ] && [ "$SITE" != 'fixmystreet' ]; then
            echo Installing $SITE using Docker is not currently supported.
            exit 1
        else
            echo ==== Installing $SITE
        fi
        ;;
    *)
        echo Installing $SITE with this script is not currently supported.
        exit 1;;
esac

core_package_install
test_ec2

# Parse HOST argument
if [ $# = 2 ]
then
    if [ x = x$EC2_HOSTNAME ]
    then
        usage_and_exit
    else
        HOST="$EC2_HOSTNAME"
    fi
elif [ $# = 3 ]
then
    HOST="$3"
else
    usage_and_exit
fi

if [ $DEVELOPMENT_INSTALL = true ]; then
    DIRECTORY=$(cd "."; pwd)
elif [ $DEFAULT_SERVER = true ]; then
    DIRECTORY="/var/www/$SITE"
else
    DIRECTORY="/var/www/$HOST"
fi

REPOSITORY="$DIRECTORY/$SITE"
REPOSITORY_URL=${REPOSITORY_URL_OVERRIDE:-https://github.com/mysociety/${SITE}.git}
BRANCH=${BRANCH_OVERRIDE:-master}
DISTRIBUTION="$(lsb_release -i -s  | tr A-Z a-z)"
DISTVERSION="$(lsb_release -c -s)"

# Make sure that the directory exists
mkdir -p "$DIRECTORY"
backup_caller
generate_locales
set_locale
add_unix_user
update_apt_sources
# Remove one crippling package, if it's installed:
apt-get -qq remove -y --purge apt-xapian-index >/dev/null || true
clone_or_update_repository
chown -R "$UNIX_USER"."$UNIX_USER" "$DIRECTORY"
run_site_specific_script
