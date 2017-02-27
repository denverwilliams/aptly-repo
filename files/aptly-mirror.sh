#!/bin/bash
#
tempdir=$(mktemp -d )  || { echo "Failed to create temp file"; exit 1; }
line="---------------------------------------------------"

# If I need tempfiles lets do it cleanly
function cleanup {
  echo ${line}
  cat ${tempdir}/*
  rm -rf ${tempdir}
  echo "Removed ${tempdir}"
  exit
}


function fail {
    errcode=$? # save the exit code as the first thing done in the trap function
    echo "error $errorcode"
    echo "the command executing at the time of the error was"
    echo "$BASH_COMMAND"
    echo "on line ${BASH_LINENO[0]}"
    # do some error handling, cleanup, logging, notification
    # $BASH_COMMAND contains the command that was being executed at the time of the trap
    # ${BASH_LINENO[0]} contains the line number in the script of that command
    # exit the script or return to try again, etc.
    cleanup
    exit $errcode  # or use some other value or do return instead
}

# Catch the crtl-c and others nicely
trap cleanup EXIT SIGHUP SIGINT SIGTERM
trap fail ERR
#

# Wanted to output a nicer message while I debug things.
print(){
 echo "$1"
 echo "${line}"
}

# I needed this to get snapshots to work. Its not ideal to hardcode this
# but it is what it is right now.
components="main,universe,multiverse,restricted"

# Using an associative array
declare -A MIRROR

#MIRROR[stable_main]="http://ftp.us.debian.org/debian stable main"
#MIRROR[stable_contrib]="http://ftp.us.debian.org/debian stable contrib"
#MIRROR[stable_updates-main]="http://ftp.us.debian.org/debian stable-updates main"
#MIRROR[stable_updates-contrib]="http://ftp.us.debian.org/debian stable-updates contrib"
#
#MIRROR[testing_main]="http://ftp.us.debian.org/debian testing main"
#MIRROR[testing_contrib]="http://ftp.us.debian.org/debian testing contrib"
#MIRROR[testing_updates-main]="http://ftp.us.debian.org/debian testing-updates main"
#MIRROR[testing_updates-contrib]="http://ftp.us.debian.org/debian testing-updates contrib"

#MIRROR[wheezy_main]="http://ftp.us.debian.org/debian wheezy main"
#MIRROR[wheezy_contrib]="http://ftp.us.debian.org/debian wheezy contrib"
#MIRROR[wheezy_updates-main]="http://ftp.us.debian.org/debian wheezy-updates main"
#MIRROR[wheezy_updates-contrib]="http://ftp.us.debian.org/debian wheezy-updates contrib"

#MIRROR[jessie_main]="http://ftp.us.debian.org/debian jessie main"
#MIRROR[jessie_contrib]="http://ftp.us.debian.org/debian jessie contrib"
#MIRROR[jessie_updates-main]="http://ftp.us.debian.org/debian jessie-updates main"
#MIRROR[jessie_updates-contrib]="http://ftp.us.debian.org/debian jessie-updates contrib"

### Adding some other repos
# Currently these could be mirrored but the logic right now in the script
# won't create the proper snapshots or publish them.
#
#MIRROR[salt]="http://ppa.launchpad.net/saltstack/salt/ubuntu trusty main"
#MIRROR[docker]="http://get.docker.io/ubuntu docker main"
#MIRROR[percona]="http://repo.percona.com/apt trusty main"
#MIRROR[openstack-icehouse]="ppa:openstack-ubuntu-testing/icehouse"
#MIRROR[ansible]="ppa:rquillo/ansible"
#
# By lumping the componets all together may make things easier sometimes but has
# issues if you plan to audit where packages originated.
#
MIRROR[ubuntu]="http://nz.archive.ubuntu.com/ubuntu trusty main universe multiverse restricted"
MIRROR[ubuntu-security]="http://nz.archive.ubuntu.com/ubuntu trusty-security main universe multiverse restricted"
MIRROR[ubuntu-updates]="http://nz.archive.ubuntu.com/ubuntu trusty-updates main universe multiverse restricted"
MIRROR[ubuntu]="http://nz.archive.ubuntu.com/ubuntu trusty main universe multiverse restricted"

# This will create the mirror the first time if its not already on the machine.
start_time(){
  date > ${tempdir}/start
  echo -n "Start:  "
  cat ${tempdir}/start
}

end_time(){
  # Timestamp for just to see how long it takes
  echo -n "Finish: "
  date > ${tempdir}/end
  cat ${tempdir}/end
}

create_mirror(){
  # Timestamp
  # Just wanting a list of mirrors before I started
  start_time
  aptly mirror list > ${tempdir}/mirror-list

  for mirror in "${!MIRROR[@]}"; do
    if ! aptly mirror show $mirror > /dev/null ; then
      print "aptly mirror create $mirror ${MIRROR[$mirror]}"
      aptly -architectures="amd64" mirror create $mirror ${MIRROR[$mirror]}
    fi
  done
  end_time
}

# Updating the mirrors and creates a snapshot for the day. Then publishes the mirror.
# The publishing off a new snapshot requires dropping the already published right now.
update_mirror(){
  start_time
  aptly mirror list -raw | xargs -n 1 aptly mirror update
  end_time
}

create_snapshot(){
  start_time
  for mirror in "${!MIRROR[@]}"; do
    if ! aptly snapshot show ${mirror}-$(date +%Y%m%d) > /dev/null ; then
      print "aptly snapshot create ${mirror}-$(date +%Y%m%d) from $mirror"
      aptly snapshot create ${mirror}-$(date +%Y%m%d) from mirror $mirror
    fi
  done
  end_time
}

publish(){
#  start_time
  for mirror in "${!MIRROR[@]}"; do
    echo ${mirror}  | sed -e s/_.*$//g >> ${tempdir}/distribution
  done
  for distribution in $(cat ${tempdir}/distribution | sort -u) ; do
    snapshot_list=$(aptly snapshot list -raw | grep ${distribution}| grep -v updates | tr "\\n" " " )
    snapshot_list_updates=$(aptly snapshot list -raw | grep ${distribution} | grep updates | tr "\\n" " " )

    #print "aptly publish $1 -component="main,contrib" -distribution=${distribution} ${snapshot_list} atg"
    aptly publish $1 -component="${components}" -distribution="${distribution}" ${snapshot_list} atg
    #print "aptly publish $1 -component="main,contrib" -distribution=${distribution}-updates ${snapshot_list_updates} atg"
    aptly publish $1 -component="${components}" -distribution="${distribution}"-updates ${snapshot_list_updates} atg
  done
  rm -f ${tempdir}/distribution
  }
#  end_time


# Do things here
create_mirror
update_mirror
create_snapshot
#publish snapshot
publish switch

aptly publish list


# Clean up the aptly db of dangling references and packages nolonger used in the repos or
# snapshots
aptly db cleanup
aptly graph
mv /tmp/aptly-graph* /aptly/public/aptly-graph.png

aptly serve
