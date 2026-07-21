@echo off
echo Building APKs per architecture...
call flutter build apk --split-per-abi
echo Done! Compressed APKs are located in build\app\outputs\apk\release\
