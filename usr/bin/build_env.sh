#!/bin/bash -ex

if [ -z "$1" ]; then
  echo "Need a basedir for where to put it all"
  exit 1
fi

PATH=/sbin:/bin:/usr/sbin:/usr/bin:${BASEDIR}/usr/bin

RUBYSRC=ruby-1.8.7-p248
GEMSSRC=rubygems-1.3.5
XMPPSRC=xmpp4r-0.5

BASEDIR=$1
BINDIR=${BASEDIR}/usr/bin
SRCDIR=${BASEDIR}/usr/src

pushd ${BASEDIR}/usr/build

tar -zxf ${SRCDIR}/${RUBYSRC}.tar.gz
cd ${RUBYSRC}
./configure --prefix=${BASEDIR}/usr --enable-pthread
make
make install
cd ..

tar -zxf ${SRCDIR}/${GEMSSRC}.tgz
cd ${GEMSSRC}
${BINDIR}/ruby setup.rb install
cd ..

${BINDIR}/gem install ${SRCDIR}/${XMPPSRC}.gem

popd

