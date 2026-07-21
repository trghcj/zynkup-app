@echo off
echo Building APKs per architecture...
call flutter build apk --split-per-abi
if not exist release mkdir release
copy build\app\outputs\flutter-apk\*.apk release\
echo Done! Compressed APKs are located in the release\ folder.
