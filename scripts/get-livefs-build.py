#!/usr/bin/python3
from launchpadlib.launchpad import Launchpad
import os
import requests
import sys

base = "https://api.launchpad.net/devel/~tobhe/+livefs/ubuntu/jammy/ubuntu-asahi/+build/"

lp = Launchpad.login_anonymously('sru-scanner', 'production', version='devel')
build = lp.load(base + sys.argv[1])
dest = sys.argv[2]

os.makedirs(dest, exist_ok=True)
for u in build.getFileUrls():
    #if not u.endswith('.squashfs'):
    #    continue
    f = os.path.join(dest, os.path.basename(u))
    if os.path.exists(f):
        continue
    print('downloading', u)
    with requests.get(u, stream=True) as r:
        r.raise_for_status()
        with open(f, 'wb') as fp:
            for chunk in r.iter_content(chunk_size=1 << 20):
                fp.write(chunk)
