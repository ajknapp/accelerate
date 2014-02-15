#!/bin/bash

set -x 
set -e

PKGS=" ./ ./accelerate-backend-kit/backend-kit \
       ./accelerate-backend-kit/icc-opencl \
       ./accelerate-multidev/ "
# ./accelerate-cuda/

CBLARGS="--disable-library-profiling  --disable-documentation $*"

#------------------------------------------------------------
# Init sandbox and link it

cabal --version
cabal sandbox init

TOP=`pwd`
for dir in $PKGS; do
  cd $dir
  cabal sandbox init --sandbox=$TOP/.cabal-sandbox/
  cd $TOP
done

#------------------------------------------------------------
# Begin installation

# First, let's make sure everything installs:
cabal install $CBLARGS $PKGS --only-dependencies --enable-tests 
cabal install $CBLARGS $PKGS 

#------------------------------------------------------------
# Begin testing

function test_dir() {
  dir=$1
  shift
  args=$*
  cd $dir
  time cabal test --show-details=always $args
  cd $TOP
}

# Split these out to run with specific arguments:
test_dir $TOP/accelerate-backend-kit/icc-opencl/   test-accelerate-cpu-sequential --test-option="--threads=8" 

# Currentl [2014.02.13] running Cilk from multiple dynamic libs causes errors (backend-kit issue #4)
test_dir $TOP/accelerate-backend-kit/icc-opencl/   test-accelerate-cpu-cilk       --test-option="--threads=1" 

test_dir $TOP/accelerate-multidev/ || echo "acclerate-multidev failed tests!  But that's allowed for now."