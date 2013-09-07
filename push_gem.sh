#!/bin/bash -x

VERSION=`awk -F \" ' /version/ { print $2 } ' circonus.gemspec`

# To push the version
gem build circonus.gemspec
gem push circonus-${VERSION}.gem
rm -f circonus-${VERSION}.gem

# To yank the version
#gem yank circonus -v ${VERSION}
