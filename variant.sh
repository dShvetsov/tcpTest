#! /usr/bin/env bash

echo $((0x$(echo "denshv@lvk.cs.msu.su" | sha512sum | head -c6) % 10))
