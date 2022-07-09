#!/bin/bash

mkdir ./dist; chmod u=rwx,go=rx dist
cp ./.github/ci-config/*.7z ./dist
