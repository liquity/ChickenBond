#!/bin/sh

anvil > /dev/null &
yarn -s ts-node scripts/overlord.ts
killall anvil
