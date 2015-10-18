# zhouzhuo 2015/10/10

#!/bin/sh

PROJECT_NAME='AliyunOSSiOS'
WORKSPACE='AliyunOSSiOS.xcworkspace'
DERIVEDDATAPATH='DERIVEDDATA'
SRCROOT='.'

# delete product foler
rm -rf ${SRCROOT}/Products

# Sets the target folders and the final framework product.
FMK_NAME=${PROJECT_NAME}

# Install dir will be the final output to the framework.
# The following line create it in the root folder of the current project.
INSTALL_DIR=${SRCROOT}/Products/${PROJECT_NAME}.framework

# Working dir will be deleted after the framework creation.
WRK_DIR=${DERIVEDDATAPATH}/Build/Products
DEVICE_DIR=${WRK_DIR}/Release-iphoneos/${FMK_NAME}.framework
SIMULATOR_DIR=${WRK_DIR}/Release-iphonesimulator/${FMK_NAME}.framework

# -configuration ${CONFIGURATION}
# Clean and Building both architectures.
xcodebuild -configuration "Release" -workspace "${WORKSPACE}" -scheme "${FMK_NAME}" -sdk iphoneos -derivedDataPath "${DERIVEDDATAPATH}" clean build
xcodebuild -configuration "Release" -workspace "${WORKSPACE}" -scheme "${FMK_NAME}" -sdk iphonesimulator -derivedDataPath "${DERIVEDDATAPATH}" clean build

# Cleaning the oldest.
if [ -d "${INSTALL_DIR}" ]
then
    rm -rf "${INSTALL_DIR}"
fi

mkdir -p "${INSTALL_DIR}"

cp -R "${DEVICE_DIR}/" "${INSTALL_DIR}/.."

# Uses the Lipo Tool to merge both binary files (i386 + armv6/armv7) into one Universal final product.
lipo -create "${DEVICE_DIR}/${FMK_NAME}" "${SIMULATOR_DIR}/${FMK_NAME}" -output "${INSTALL_DIR}/${FMK_NAME}"

rm -r "${WRK_DIR}"
rm -r "${DERIVEDDATAPATH}"

if [ -d "${INSTALL_DIR}/_CodeSignature" ]
then
    rm -rf "${INSTALL_DIR}/_CodeSignature"
fi

if [ -f "${INSTALL_DIR}/Info.plist" ]
then
    rm "${INSTALL_DIR}/Info.plist"
fi
