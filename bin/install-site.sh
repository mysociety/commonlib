#!/bin/sh

# This script can be used to install mySociety sites on a clean
# install of Debian squeeze/wheezy or Ubuntu precise. It contains common
# code that is used in installing sites, and sources a site specific
# script called bin/site-specific-install.sh in each.

# WARNING: This script makes significant changes to your server’s
# setup, including modifying your web server setup, creating a user
# account, creating a database, installing new packages etc.
# Typically you should only use this on a clean install, such as a new
# EC2 instance.

# The usage is:
#
#   install-site.sh [--default] SITE-NAME UNIX-USER [HOST]
#
# ... where --default means to install as the default site for this
# server, rather than a virtualhost for HOST.  HOST is only optional
# if you are installing onto an EC2 instance.

set -e
error_msg() { printf "\033[31m%s\033[0m\n" "$*"; }
notice_msg() { printf "\033[33m%s\033[0m " "$*"; }
done_msg() { printf "\033[32m%s\033[0m\n" "$*"; }
DONE_MSG=$(done_msg done)

DEFAULT_SERVER=false
DEFAULT_PARAMETER=
if [ x"$1" = x"--default" ]
then
    DEFAULT_SERVER=true
    DEFAULT_PARAMETER='--default'
    shift
fi

usage_and_exit() {
    cat >&2 <<EOUSAGE
Usage: $0 [--default] <SITE-NAME> <UNIX-USER> [HOST]
HOST is only optional if you are running this on an EC2 instance.
--default means to install as the default site for this server,
rather than a virtualhost for HOST.
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
    fixmystreet | mapit | theyworkforyou)
        echo ==== Installing $SITE;;
    *)
        echo Installing $SITE with this script is not currently supported.
        exit 1;;
esac

# Install some packages that we will definitely need:
echo -n "Updating package lists... "
apt-get -qq update
echo $DONE_MSG
echo "Installing some core packages..."
for package in git-core lockfile-progs rubygems curl dnsutils lsb-release; do
    echo -n "  $package... "; apt-get -qq install -y $package >/dev/null; echo $DONE_MSG
done

# If we're not running on an EC2 instance, an empty body is returned
# by this request:
echo -n "Testing for being on EC2... "
EC2_HOSTNAME=`curl --max-time 10 -s http://169.254.169.254/latest/meta-data/public-hostname || true`
echo $DONE_MSG

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

if [ $DEFAULT_SERVER = true ]
then
    DIRECTORY="/var/www/$SITE"
else
    DIRECTORY="/var/www/$HOST"
fi
REPOSITORY="$DIRECTORY/$SITE"

REPOSITORY_URL=git://github.com/mysociety/$SITE.git
BRANCH=master

DISTRIBUTION="$(lsb_release -i -s  | tr A-Z a-z)"
DISTVERSION="$(lsb_release -c -s)"

echo -n "Testing $HOST's IP address... "
IP_ADDRESS_FOR_HOST="$(dig +short $HOST)"

if [ x = x"$IP_ADDRESS_FOR_HOST" ]
then
    error_msg "The hostname $HOST didn't resolve to an IP address"
    exit 1
fi
echo $DONE_MSG

generate_locales() {
    echo -n "Generating locales... "
    # If language-pack-en is present, install that:
    apt-get -qq install -y language-pack-en >/dev/null || true

    # We get lots of locale errors if the en_GB.UTF-8 locale isn't
    # present.  (This is from Kagee's script.)
    if [ "$(locale -a | egrep -i '^en_GB.utf-?8$' | wc -l)" = "1" ]
    then
        notice_msg already
    else
        if [ x"$(grep -c '^en_GB.UTF-8 UTF-8' /etc/locale.gen)" = x1 ]
        then
            notice_msg generating...
        else
            notice_msg adding and generating...
            echo "\nen_GB.UTF-8 UTF-8\ncy_GB.UTF-8 UTF-8" >> /etc/locale.gen
        fi
        locale-gen
    fi
    echo $DONE_MSG
}

set_locale() {
    echo 'LANG="en_GB.UTF-8"' > /etc/default/locale
    echo 'LC_ALL="en_GB.UTF-8"' >> /etc/default/locale
    export LANG="en_GB.UTF-8"
    export LC_ALL="en_GB.UTF-8"
}

add_unix_user() {
    echo -n "Adding unix user... "
    # Create the required user if it doesn't already exist:
    if id "$UNIX_USER" 2> /dev/null > /dev/null
    then
        notice_msg already
    else
        adduser --quiet --disabled-password --gecos "A user for the site $SITE" "$UNIX_USER"
    fi
    echo $DONE_MSG
}

add_postgresql_user() {
    su -l -c "createuser --createdb --no-createrole --no-superuser '$UNIX_USER'" postgres || true
}

update_apt_sources() {
    echo -n "Updating APT sources... "
    if [ x"$DISTRIBUTION" = x"ubuntu" ] && [ x"$DISTVERSION" = x"precise" ]
    then
        cat > /etc/apt/sources.list.d/mysociety-extra.list <<EOF
deb http://eu-west-1.ec2.archive.ubuntu.com/ubuntu/ precise multiverse
deb-src http://eu-west-1.ec2.archive.ubuntu.com/ubuntu/ precise multiverse
deb http://eu-west-1.ec2.archive.ubuntu.com/ubuntu/ precise-updates multiverse
deb-src http://eu-west-1.ec2.archive.ubuntu.com/ubuntu/ precise-updates multiverse
EOF
    elif [ x"$DISTRIBUTION" = x"debian" ] && [ x"$DISTVERSION" = x"squeeze" ]
    then
        # Install the basic packages we require:
        cat > /etc/apt/sources.list.d/mysociety-extra.list <<EOF
# Debian mirror to use, including contrib and non-free:
deb http://the.earth.li/debian/ squeeze main contrib non-free
deb-src http://the.earth.li/debian/ squeeze main contrib non-free

# Security Updates:
deb http://security.debian.org/ squeeze/updates main non-free
deb-src http://security.debian.org/ squeeze/updates main non-free

# Debian Backports
deb http://backports.debian.org/debian-backports squeeze-backports main contrib non-free
deb-src http://backports.debian.org/debian-backports squeeze-backports main contrib non-free
EOF
    elif [ x"$DISTRIBUTION" = x"debian" ] && [ x"$DISTVERSION" = x"wheezy" ]
    then
        # Install the basic packages we require:
        cat > /etc/apt/sources.list.d/mysociety-extra.list <<EOF
# Debian mirror to use, including contrib and non-free:
deb http://the.earth.li/debian/ wheezy main contrib non-free
deb-src http://the.earth.li/debian/ wheezy main contrib non-free

# Security Updates:
deb http://security.debian.org/ wheezy/updates main non-free
deb-src http://security.debian.org/ wheezy/updates main non-free
EOF
    else
        error_msg "Unsupported distribution and version combination $DISTRIBUTION $DISTVERSION"
        exit 1
    fi
    apt-get -qq update
    echo $DONE_MSG
}

clone_or_update_repository() {
    echo -n "Cloning or updating repository... "
    # Clone the repository into place if the directory isn't already
    # present:
    if [ -d $REPOSITORY ]
    then
        notice_msg updating...
        cd $REPOSITORY
        git remote set-url origin "$REPOSITORY_URL"
        git fetch origin
        # Check that there are no uncommitted changes before doing a
        # git reset --hard:
        git diff --quiet || { echo "There were changes in the working tree in $REPOSITORY; exiting."; exit 1; }
        git diff --cached --quiet || { echo "There were staged but uncommitted changes in $REPOSITORY; exiting."; exit 1; }
        # If that was fine, carry on:
        git reset --quiet --hard origin/"$BRANCH"
        git submodule --quiet sync
        git submodule --quiet update --recursive
    else
        PARENT="$(dirname $REPOSITORY)"
        notice_msg cloning...
        mkdir -p $PARENT
        git clone --recursive --branch "$BRANCH" "$REPOSITORY_URL" "$REPOSITORY"
    fi
    echo $DONE_MSG
}

install_postfix() {
    echo -n "Installing postfix... "
    # Make sure debconf-set-selections is available
    apt-get -qq install -y debconf >/dev/null
    # Set the things so that we can do this non-interactively
    echo postfix postfix/main_mailer_type select 'Internet Site' | debconf-set-selections
    echo postfix postfix/mail_name string "$HOST" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get -qq -y install postfix >/dev/null
    echo $DONE_MSG
}

install_nginx() {
    echo -n "Installing nginx... "
    apt-get install -qq -y nginx libfcgi-procmanager-perl >/dev/null
    echo $DONE_MSG
}

install_postgis() {
    echo -n "Installing PostGIS... "
    POSTGIS_SCRIPT='https://docs.djangoproject.com/en/dev/_downloads/create_template_postgis-debian.sh'
    su -l -c "curl '$POSTGIS_SCRIPT' | bash -s" postgres
    # According to Matthew's installation instructions, these two SRID
    # may be missing the appropriate +datum from the proj4text column,
    # depending on what PostGIS version is being used.  Check whether
    # they are missing, and if so, update the column.
    for T in 27700:+datum=OSGB36 29902:+datum=ire65
    do
        SRID="${T%%:*}"
        DATUM="${T##*:}"
        EXISTING="$(echo "select proj4text from spatial_ref_sys where srid = '$SRID'" | su -l -c "psql -t -P 'format=unaligned' template_postgis" postgres)"
        if ! echo "$EXISTING" | grep -- "$DATUM"
        then
            echo Adding $DATUM to the proj4text column of spatial_ref_sys for srid $SRID
            NEW_VALUE="${EXISTING% } $DATUM "
            echo "UPDATE spatial_ref_sys SET proj4text = '$NEW_VALUE' WHERE srid = '$SRID'" | su -l -c 'psql template_postgis' postgres
        fi
    done
    echo $DONE_MSG
}

make_log_directory() {
    LOG_DIRECTORY="$DIRECTORY/logs"
    mkdir -p "$LOG_DIRECTORY"
    chown -R "$UNIX_USER"."$UNIX_USER" "$LOG_DIRECTORY"
}

add_website_to_nginx() {
    echo -n "Adding site to nginx... "
    NGINX_SITE="$HOST"
    if [ $DEFAULT_SERVER = true ]
    then
        NGINX_SITE=default
    fi
    NGINX_SITE_FILENAME=/etc/nginx/sites-available/"$NGINX_SITE"
    NGINX_SITE_LINK=/etc/nginx/sites-enabled/"$NGINX_SITE"
    cp $REPOSITORY/conf/nginx.conf.example $NGINX_SITE_FILENAME
    sed -i "s,/var/www/$SITE,$DIRECTORY," $NGINX_SITE_FILENAME
    if [ $DEFAULT_SERVER = true ]
    then
        sed -i "s/^.*listen 80.*$/    listen 80 default_server;/" $NGINX_SITE_FILENAME
    else
        sed -i "/listen 80/a\
\    server_name $HOST;
" $NGINX_SITE_FILENAME
    fi
    ln -nsf "$NGINX_SITE_FILENAME" "$NGINX_SITE_LINK"
    make_log_directory
    /etc/init.d/nginx restart >/dev/null
    echo $DONE_MSG
}

install_sysvinit_script() {
    SYSVINIT_FILENAME=/etc/init.d/$SITE
    cp $REPOSITORY/conf/sysvinit.example $SYSVINIT_FILENAME
    sed -i "s,/var/www/$SITE,$DIRECTORY,g" $SYSVINIT_FILENAME
    sed -i "s/^ *USER=.*/USER=$UNIX_USER/" $SYSVINIT_FILENAME
    chmod a+rx $SYSVINIT_FILENAME
    update-rc.d $SITE start 20 2 3 4 5 . stop 20 0 1 6 .
    /etc/init.d/$SITE restart
}

install_website_packages() {
    echo "Installing packages from repository packages file... "
    EXACT_PACKAGES="$REPOSITORY/conf/packages.$DISTRIBUTION-$DISTVERSION"
    PRECISE_PACKAGES="$REPOSITORY/conf/packages.ubuntu-precise"
    SQUEEZE_PACKAGES="$REPOSITORY/conf/packages.debian-squeeze"
    GENERIC_PACKAGES="$REPOSITORY/conf/packages"
    # If there's an exact match for the distribution and release, use that:
    if [ -e "$EXACT_PACKAGES" ]
    then
        PACKAGES_FILE="$EXACT_PACKAGES"
    # Otherwise, if this is Ubuntu, and there's a version specifically
    # for precise, use that:
    elif [ x"$DISTRIBUTION" = x"ubuntu" ] && [ -e "$PRECISE_PACKAGES" ]
    then
        PACKAGES_FILE="$PRECISE_PACKAGES"
    # Otherwise, if this is Debian, and there's a version specifically
    # for squeeze, use that:
    elif [ x"$DISTRIBUTION" = x"debian" ] && [ -e "$SQUEEZE_PACKAGES" ]
    then
        PACKAGES_FILE="$SQUEEZE_PACKAGES"
    else
        PACKAGES_FILE="$GENERIC_PACKAGES"
    fi
    xargs -a "$PACKAGES_FILE" apt-get -qq -y install >/dev/null
    echo "  $DONE_MSG"
}

overwrite_rc_local() {
    cat > /etc/rc.local <<EOF
#!/bin/sh -e

su -l -c $REPOSITORY/bin/ec2-rewrite-conf $UNIX_USER
/etc/init.d/$SITE restart

exit 0

EOF
    chmod a+rx /etc/rc.local
}

generate_locales
set_locale

add_unix_user

update_apt_sources

# And remove one crippling package, if it's installed:
apt-get -qq remove -y --purge apt-xapian-index >/dev/null || true

clone_or_update_repository

chown -R "$UNIX_USER"."$UNIX_USER" "$DIRECTORY"

. $REPOSITORY/bin/site-specific-install.sh
