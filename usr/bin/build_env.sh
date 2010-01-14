#!/bin/bash -ex

if [ -z "$1" ]; then
  echo "Need a prefix for where to put it all"
  exit 1
fi

PATH=/sbin:/bin:/usr/sbin:/usr/bin:${PREFIX}/bin

RUBYSRC=ruby-1.8.7-p248
GEMSSRC=rubygems-1.3.5
XMPPSRC=xmpp4r-0.5

PREFIX=/Users/mac/gaoh
SRCDIR=${PREFIX}/src

pushd ${PREFIX}/usr/build

tar -zxf ${SRCDIR}/${RUBYSRC}.tar.gz
cd ${RUBYSRC}
./configure --prefix=${PREFIX} --enable-pthread
make
make install
cd ..

tar -zxf ${SRCDIR}/${GEMSSRC}.tgz
cd ${GEMSSRC}
${PREFIX}/bin/ruby setup.rb install
cd ..

${PREFIX}/bin/gem install ${SRCDIR}/${XMPPSRC}.gem

popd

