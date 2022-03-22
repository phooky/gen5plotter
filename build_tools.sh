#!/bin/bash

if [[ "$1" = "clean" ]]; then
  echo "*** cleaning ***"
  rm -f pru_sw/utils/pasm

  pushd pru_sw/app_loader/interface
  make clean
  popd
  exit 0
fi

echo "*** building ***"

pushd pru_sw/utils/pasm_source
./linuxbuild
popd

pushd pru_sw/app_loader/interface
make
popd

