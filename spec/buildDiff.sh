#!/bin/sh
headref=$(git rev-parse HEAD)
devref=$(git rev-parse dev)

if [[ ! -f "/root/spec/Cache/$devref" ]] # Output of builds outdated or nonexistent
then
	rm "/root/spec/Cache/*"
    git config --global --add safe.directory /root && \
    mkdir /devRef && cp -r /root/. /devRef/ && cd /devRef && \
    git restore . && git clean -fd && git checkout dev && \
    cp /root/.busted . && rm -rf /devRef/spec/ && cp -r /root/spec/ /devRef/spec/ && \
    BUILDCACHEPREFIX='/root/spec/Cache' busted --lua=luajit -r generate && \
    date > "/root/spec/Cache/$devref" && cd /root && echo "[+] Build cache computed for $devref"
	rm -rf /devRef
fi

if [[ -f "/root/spec/Cache/$devref" ]] #Make sure cache of dev branch builds exists and matches current dev
then
    BUILDCACHEPREFIX='/tmp' busted --lua=luajit -r generate && date > "/tmp/$headref" && echo "[+] Build cache computed for $headref"
fi

if [[ -f "/tmp/$headref" ]] # Make sure generating builds for current HEAD was successful
then
    for build in /root/spec/Cache/*.lua
    do
        BASENAME=$(basename "$build")
        echo "[-] Diff for $BASENAME"
        diff "$build" "/tmp/$BASENAME"
        echo "[+] Diff for $BASENAME"
    done
fi
