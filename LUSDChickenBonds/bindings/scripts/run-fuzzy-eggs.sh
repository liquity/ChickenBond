#!/bin/sh

anvil > /dev/null &
yarn -s ts-node scripts/fuzzy-eggs.ts
killall anvil
