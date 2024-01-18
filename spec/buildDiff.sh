#!/bin/sh
cd $WORKDIR
umask 0
git config --global --add safe.directory /workdir
git config --global --add advice.detachedHead false
headref=$(git rev-parse HEAD)
devref=$(git rev-parse origin/dev)

if [[ ! -f "$CACHEDIR/$devref" ]] # Output of builds outdated or nonexistent
then
	rm $CACHEDIR/*.lua
    rm $CACHEDIR/*.build
    rm $CACHEDIR/*.xml
    cp -rf --parents $WORKDIR /tmp && cd /tmp$WORKDIR && \
    git restore . && git clean -fd && git checkout origin/dev && \
    cp $WORKDIR/.busted /tmp$WORKDIR/.busted && cp $WORKDIR/src/HeadlessWrapper.lua /tmp$WORKDIR/src/HeadlessWrapper.lua && rm -rf /tmp$WORKDIR/spec/ && cp -r $WORKDIR/spec/ /tmp$WORKDIR/spec/ && \
    cat $WORKDIR/spec/builds.txt | dos2unix | parallel --will-cite --ungroup --pipe -N50 'LINKSBATCH="$(mktemp){#}"; cat > $LINKSBATCH; BUILDLINKS=${LINKSBATCH} BUILDCACHEPREFIX=${CACHEDIR} busted --lua=luajit -r generate' && \
    BUILDCACHEPREFIX=${CACHEDIR} busted --lua=luajit -r generate && date > "$CACHEDIR/$devref" && echo "[+] Build cache computed for $devref" && cd $WORKDIR
fi

if [[ -f "$CACHEDIR/$devref" ]] #Make sure cache of dev branch builds exists and matches current dev
then
    rm -rf /tmp/*
    cat $WORKDIR/spec/builds.txt | dos2unix | parallel --will-cite --ungroup --pipe -N50 'LINKSBATCH="$(mktemp){#}"; cat > $LINKSBATCH; BUILDLINKS=${LINKSBATCH} BUILDCACHEPREFIX="/tmp" busted --lua=luajit -r generate' && \
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
