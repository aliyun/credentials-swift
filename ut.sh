#!/bin/bash env

SCHEME="AlibabaCloudCredentials-Package"
DESTINATION="platform=OS X,arch=x86_64"
SDK="macosx"
PLATFORM="OSX"

swift package generate-xcodeproj --enable-code-coverage
xcodebuild clean build -project AlibabaCloudCredentials.xcodeproj -scheme "$SCHEME" -sdk "$SDK" -destination "$DESTINATION" -configuration Debug ONLY_ACTIVE_ARCH=NO test
xcodebuild test -project AlibabaCloudCredentials.xcodeproj -scheme "$SCHEME" -sdk "$SDK" -destination "$DESTINATION" -configuration Debug ONLY_ACTIVE_ARCH=NO test 
