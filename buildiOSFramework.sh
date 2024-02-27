#!/bin/sh

PROJECT_NAME='AliyunOSSSDK'
TARGET_NAME="AliyunOSSSDK iOS"
SRCROOT='.'

# Sets the target folders and the final framework product.
FMK_NAME='AliyunOSSiOS'

# Install dir will be the final output to the framework.
# The following line create it in the root folder of the current project.
INSTALL_DIR=${SRCROOT}/Products/${FMK_NAME}.xcframework

# Working dir will be deleted after the framework creation.
WRK_DIR=./build
DEVICE_DIR=${WRK_DIR}/Release-iphoneos/${FMK_NAME}
SIMULATOR_DIR=${WRK_DIR}/Release-iphonesimulator/${FMK_NAME}
DEVICE_FRAMEWORK_DIR=${DEVICE_DIR}.xcarchive/Products/Library/Frameworks/${FMK_NAME}.framework
SIMULATOR_FRAMEWORK_DIR=${SIMULATOR_DIR}.xcarchive/Products/Library/Frameworks/${FMK_NAME}.framework

# -configuration ${CONFIGURATION}
# Clean and Building both architectures.
# xcodebuild -configuration "Release" -target "${FMK_NAME}" -sdk iphoneos clean build
# xcodebuild -configuration "Release" -target "${FMK_NAME}" -sdk iphonesimulator clean build
xcodebuild archive -workspace "${PROJECT_NAME}.xcworkspace" -scheme "${TARGET_NAME}" -configuration Release -destination 'generic/platform=iOS Simulator' -archivePath "${SIMULATOR_DIR}" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
xcodebuild archive -workspace "${PROJECT_NAME}.xcworkspace" -scheme "${TARGET_NAME}" -configuration Release -destination 'generic/platform=iOS' -archivePath "${DEVICE_DIR}" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Cleaning the oldest.
if [ -d "${INSTALL_DIR}" ]
then
    rm -rf "${INSTALL_DIR}"
fi

mkdir -p ${SRCROOT}/Products

# Uses the Lipo Tool to merge both binary files (i386/x86_64 + armv7/armv64) into one Universal final product.
xcodebuild -create-xcframework -framework "${DEVICE_FRAMEWORK_DIR}" -framework "${SIMULATOR_FRAMEWORK_DIR}" -output "${INSTALL_DIR}"

rm -r "${WRK_DIR}"
