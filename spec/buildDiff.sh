#!/bin/sh
cd $WORKDIR
git config --global --add safe.directory /workdir
headref=$(git rev-parse HEAD)
devref=$(git rev-parse dev)

if [[ ! -f "$CACHEDIR/$devref" ]] # Output of builds outdated or nonexistent
then
	rm -rf $CACHEDIR/*
    cp -rf --parents $WORKDIR /tmp && cd /tmp$WORKDIR && \
    git restore . && git clean -fd && git checkout dev && \
    cp $WORKDIR/.busted /tmp$WORKDIR/.busted && cp $WORKDIR/src/HeadlessWrapper.lua /tmp$WORKDIR/src/HeadlessWrapper.lua && rm -rf /tmp$WORKDIR/spec/ && cp -r $WORKDIR/spec/ /tmp$WORKDIR/spec/ && \
    cat $WORKDIR/spec/builds.txt | parallel --will-cite --ungroup --pipe -N50 "cat > /tmp/parallel_links_{#};  BUILDLINKS=/tmp/parallel_links_{#} BUILDCACHEPREFIX=${CACHEDIR} busted --lua=luajit -r generate; rm /tmp/parallel_links_{#}" && \
    BUILDCACHEPREFIX=${CACHEDIR} busted --lua=luajit -r generate && date > "$CACHEDIR/$devref" && echo "[+] Build cache computed for $devref"
fi

if [[ -f "$CACHEDIR/$devref" ]] #Make sure cache of dev branch builds exists and matches current dev
then
    rm -rf /tmp/*
    cat $WORKDIR/spec/builds.txt | parallel --will-cite --ungroup --pipe -N50 'cat > /tmp/parallel_links_{#};  BUILDLINKS="/tmp/parallel_links_{#}" BUILDCACHEPREFIX="/tmp" busted --lua=luajit -r generate; rm /tmp/parallel_links_{#}' && \
    BUILDCACHEPREFIX='/tmp' busted --lua=luajit -r generate && date > "/tmp/$headref" && echo "[+] Build cache computed for $headref"
fi

if [[ -f "/tmp/$headref" ]] # Make sure generating builds for current HEAD was successful
then
    for build in $CACHEDIR/*.lua
    do
        luajit $WORKDIR/spec/buildOutputDiff.lua /tmp/$(basename "$build") "$build"
    done
    for build in $CACHEDIR/*.build
    do
        BASENAME=$(basename "$build")
        echo "[-] Savefile Diff for $BASENAME"
        diff "$build" "/tmp/$BASENAME"
        echo "[+] Savefile Diff for $BASENAME"
    done
fi
