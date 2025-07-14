#!/bin/bash

rm -f docs/* & > /dev/null

zig build-lib -femit-docs src/Termio.zig

rm -f Termio.lib & > /dev/null
rm -f Termio.lib.obj & > /dev/null
