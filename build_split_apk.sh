#!/bin/bash
echo "Building APKs per architecture..."
flutter build apk --split-per-abi
echo "Done! Compressed APKs are located in build/app/outputs/apk/release/"
