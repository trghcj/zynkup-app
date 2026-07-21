#!/bin/bash
echo "Building APKs per architecture..."
flutter build apk --split-per-abi
mkdir -p release
cp build/app/outputs/flutter-apk/*.apk release/
echo "Done! Compressed APKs are located in the release/ folder."
