#!/usr/bin/python3
import json
import optparse

from launchpadlib.launchpad import Launchpad

p = optparse.OptionParser()
p.add_option('--ppa')
p.add_option('--livefs')
p.add_option('--arch', default='amd64')
p.add_option('--pocket', default='Release')
p.add_option('--metadata', action='append', default=[])
o, a = p.parse_args()
owner, _, distro, series, name = o.livefs.split('/')

if owner.startswith('~'):
    owner = owner[1:]

metadata_override = {}
for override in o.metadata:
    k, v = override.split('=', 1)
    metadata_override[k] = json.loads(v)
lp = Launchpad.login_with('sru-scanner', 'production', version='devel')
distro = lp.distributions[distro]
if o.ppa:
    archive = lp.archives.getByReference(reference=o.ppa)
else:
    archive = distro.main_archive
series = distro.getSeries(name_or_version=series)
das = series.getDistroArchSeries(archtag=o.arch)

f = lp.livefses.getByName(
    distro_series=series, owner=lp.people[owner], name=name)
build = f.requestBuild(
    archive=archive, distro_arch_series=das, pocket=o.pocket.title(),
    metadata_override=metadata_override)

print(build.web_link)
