#!/bin/bash

X8664=x86_64
AARCH64=aarch64
TEST_LINK=test-link
COMMON_PACKAGES="meson gcc check-devel valgrind doxygen"
LOGFILE=$(date +%m%d%y%H%M%S).log
TIMEOUT=500
LIBEVDEV_REPO=https://gitlab.freedesktop.org/libevdev/libevdev

source /usr/share/beakerlib/beakerlib.sh

function installAarch64Package
{
    rlRun "rpm-ostree -A install $package"
}

function installX8664Package
{
    rlRun "dnf install -y $package"
}

function log
{
    if [ ! -e $LOGDIR ]
    then
	mkdir $LOGDIR
    fi
    if [ -f $LOGFILE ]
    then
        touch $LOGFILE
    fi
    echo -e "$1" >> $LOGDIR/$LOGFILE
}


function setupRepos
{
    rlRun "rm -rf libevdev"
    log "running on hwpf $hwpf\""

    for package in $COMMON_PACKAGES; do
        echo "package name: $package"
        package_exist=$(rpm -qa | grep ^$package-)
        if [ -z $package_exist ]
        then
            log "installing package $package"
	    if [ $hwpf == $X8664 ]
            then
		installX8664Package $package
	    elif [ $hwpf == $AARCH64 ]
	    then
		installAarch64Package $package
	    fi
        fi
    done

    if [ $hwpf == $X8664 ]
    then
	rlRun "dnf install -y cmake"
    fi

    rlRun "git clone $LIBEVDEV_REPO"
    cd libevdev
    mkdir logs
    LOGDIR=$(pwd)/logs
    rlRun "meson setup builddir"
    
    # compile according to hardware type
    if [ $hwpf == $X8664 ]
    then
	cd builddir
	rlRun "meson compile"
    else
	rlRun "meson compile -C builddir"
	cd builddir
    fi
    TESTS_DIR=$(pwd)
    log "tests dir at $TESTS_DIR\n"
}

function setup
{
    rlPhaseStartSetup
    hwpf=$(uname -i)
    setupRepos
    rlPhaseEnd
}

function getTests
{
    if [ $(pwd) != $TESTS_DIR ]
    then
	cd $TESTS_DIR
    fi
    ALL_TESTS=()
    ALL_TESTS=$(ls -d  test-* | grep -v "\.")
}

function runtest
{
    rlPhaseStartTest
    cd $TESTS_DIR
    getTests
    for test in ${ALL_TESTS[*]}; do
            log "$test"
	    test_exec=$(CK_DEFAULT_TIMEOUT=$TIMEOUT ./$test)
            test_res=$?
            if [ -n "$test_exec" ]
            then
                log "$test_exec"
            fi

	    if [ "$test" == "$TEST_LINK" ]
	    then
		rlAssertGreater "Assert $test return code" $test_res 0 
	    else
		rlAssertEquals "Assert $test return code" $test_res 0
	    fi
	    log "$test return value: $test_res\n"
    done
    rlPhaseEnd
}

function main
{
    rlJournalStart
    setup
    runtest
    echo "Detailed results can be found in: $LOGDIR/$LOGFILE"
    rlJournalEnd
}

main
exit $?

