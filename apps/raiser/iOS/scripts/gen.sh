rm -rf Raiser.xcodeproj
rm Raiser/Info.plist
xcodegen
xcode-build-server config -project *.xcodeproj -scheme Raiser
