#!/bin/sh
# 20240509, rgf: make sure the executable bit gets set for Unix
# 20240531, rgf: make sure oorexxshell on Unix systems gets the executable bit

# Rexx script/program related
find . \( -iname "*.sh" -o -iname "*.rex" -o -iname "*.rxj" -o -iname "*.rxo" -o -iname "*.cls" \) -type f -exec chmod 775 '{}' \;

# Rexx related
find . \( -iname "rexx" -o -iname "rexxc" -o -iname "rxapi" -o -iname "rxqueue" -o -iname "rxsubcom" \) -type f -exec chmod 775 '{}' \;

# Library related
find . \( -iname "lib*so*" -o -iname "lib*dylib*" \) -type f -exec chmod 775 '{}' \;

# ooRexxShell
find . -iname "oorexxshell" -type f -exec chmod 775 '{}' \;

# rexxdebugger
find . -iname "rexxdebugger" -type f -exec chmod 775 '{}' \;

# netrexx
find . \( -iname "nr" -o -iname "nrc" -o -iname "nrws" -o -iname "pipc" -o -iname "pipe" \) -type f -exec chmod 775 '{}' \;

# generated scripts that have no .sh extension
find . \( -iname "run" -o -iname "setenv" \) -type f -exec chmod 775 '{}' \;

# all text files to 664
find . -iname "*.txt" -type f -exec chmod 664 '{}' \;

