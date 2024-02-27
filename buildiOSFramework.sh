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
DEVICE_DIR=${WRK_DIR}/Release-iphoneos/${FMK_NAME}.framework
SIMULATOR_DIR=${WRK_DIR}/Release-iphonesimulator/${FMK_NAME}.framework

# -configuration ${CONFIGURATION}
# Clean and Building both architectures.
# xcodebuild -configuration "Release" -target "${FMK_NAME}" -sdk iphoneos clean build
# xcodebuild -configuration "Release" -target "${FMK_NAME}" -sdk iphonesimulator clean build
xcodebuild -configuration Release -workspace "${PROJECT_NAME}.xcworkspace" -scheme "${TARGET_NAME}" -sdk iphoneos clean build SYMROOT="${WRK_DIR}"
xcodebuild -configuration Release -workspace "${PROJECT_NAME}.xcworkspace" -scheme "${TARGET_NAME}" -sdk iphonesimulator build SYMROOT="${WRK_DIR}"

# Cleaning the oldest.
if [ -d "${INSTALL_DIR}" ]
then
    rm -rf "${INSTALL_DIR}"
fi

mkdir -p ${SRCROOT}/Products

# Create XCFramework
xcodebuild -create-xcframework \
-framework "${DEVICE_DIR}" \
-framework "${SIMULATOR_DIR}" \
-output "${INSTALL_DIR}"

rm -r "${WRK_DIR}"

if [ -d "${INSTALL_DIR}/_CodeSignature" ]
then
    rm -rf "${INSTALL_DIR}/_CodeSignature"
fi

if [ -f "${INSTALL_DIR}/Info.plist" ]
then
    rm "${INSTALL_DIR}/Info.plist"
fi

