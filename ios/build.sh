#!/bin/bash
#
# build script for automatically building GT.framework
#

#
# iphone and simulator sdks
#

DIST_DIR_NAME=GT.embeddedframework_v2.2.3
DISTGZ=GT.embeddedframework_v2.2.3.tar.gz
Demo4GT_proj_ios=Demo4GT_proj_ios

DIST_GZ_DIR=GT.embeddedframework

XCODEBUILD=xcodebuild

#
# project configuration
#
PROJECT_NAME=GT
PROJBASE=.
BASEDIR=.
BUILD_DIR=build
DIST_DIR=result
HEADERDIR=$BUILD_DIR/include

#
# error code
#
returnCode=0

#
# build styles
#
TARGET_LIST=(GT)
CONFIG_LIST=(Debug)

#
# prepare build directories
#
prepareDirs()
{
    rm -rf $DIST_DIR
    mkdir $DIST_DIR

    rm -rf $BUILD_DIR
    mkdir $BUILD_DIR
}

#
# choose an sdk
#
chooseSDKs()
{
# show xcodebuild verison
${XCODEBUILD} -version

SDK_VERSION=""

[[ $SDK_NAME =~ "iphoneos" ]]
if [ $? = 0 ]
then
echo "$SDK_NAME has iphoneos"
SDK_VERSION=${SDK_NAME#*iphoneos}
fi

[[ $SDK_NAME =~ "iphonesimulator" ]]
if [ $? = 0 ]
then
echo "$SDK_NAME has iphonesimulator"
SDK_VERSION=${SDK_NAME#*iphonesimulator}
fi

echo "SDK_VERSION:$SDK_VERSION"

IPHONE_SDK="iphoneos"${SDK_VERSION}
SIMULATOR_SDK="iphonesimulator"${SDK_VERSION}

echo "SDK choosen: $SIMULATOR_SDK and $IPHONE_SDK"
}

#
# build GT sdk(device and simulator version)
#
buildGTSdk()
{
    # device build
    echo "${XCODEBUILD} -target $TARGET -configuration $CONFIG -sdk $IPHONE_SDK"
    ${XCODEBUILD} -target $TARGET -project "GTKit.xcodeproj" -configuration $CONFIG -sdk $IPHONE_SDK
    ret=$?
    if ! [ $ret = 0 ] ;then
        echo "Error, ${XCODEBUILD} returns $ret building device version of GT"
        returnCode=$(($returnCode + $ret))
        exit 1002
    fi

    # simulator build
    # hannahliao
    echo "${XCODEBUILD} -target $TARGET -configuration $CONFIG -sdk $SIMULATOR_SDK"
    ${XCODEBUILD} -target $TARGET -project "GTKit.xcodeproj" -configuration $CONFIG -sdk $SIMULATOR_SDK
    ret=$?
    if ! [ $ret = 0 ] ;then
        echo "Error, ${XCODEBUILD} returns $ret building simulator version of GT"
        returnCode=$(($returnCode + $ret))
        exit 1003
    fi
}


#
# copy headers to a temporary directory
#
copyHeaders()
{
    /bin/echo Copying header files
    FRAMEWORK_DIR=$FRAMEWORK_BUILD_PATH/$FRAMEWORK_NAME.framework

    /bin/cp ${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/$FRAMEWORK_NAME.framework/*.h $FRAMEWORK_DIR/Headers/
}

copyResource()
{
    /bin/echo Copying resources files
    FRAMEWORK_DIR=$FRAMEWORK_BUILD_PATH/$FRAMEWORK_NAME.framework

    /bin/cp ${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/$FRAMEWORK_NAME.framework/*.png $FRAMEWORK_DIR/Resources/
}

#
# create framework
#
createFramework()
{
    # Clean any existing framework that might be there
    if [ -d "$FRAMEWORK_BUILD_PATH" ]
    then
        echo "Framework: Cleaning framework..."
        rm -rf "$FRAMEWORK_BUILD_PATH"
    fi

    # build the canonical Framework bundle directory structure
    echo "Framework: Setting up directories..."
    EMBEDDEDFRAMEWORK_DIR=$FRAMEWORK_BUILD_PATH/$FRAMEWORK_NAME.embeddedframework
    mkdir -p $EMBEDDEDFRAMEWORK_DIR
    mkdir -p $EMBEDDEDFRAMEWORK_DIR/Resources

    FRAMEWORK_DIR=$EMBEDDEDFRAMEWORK_DIR/$FRAMEWORK_NAME.framework
    mkdir -p $FRAMEWORK_DIR
    mkdir -p $FRAMEWORK_DIR/Headers

    /bin/cp ${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME $FRAMEWORK_DIR/

    /bin/cp ${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/$FRAMEWORK_NAME.framework/Headers/*.h $FRAMEWORK_DIR/Headers/

    /bin/cp -R ${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/$FRAMEWORK_NAME.bundle $EMBEDDEDFRAMEWORK_DIR/Resources/

    echo "${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/$FRAMEWORK_NAME.bundle"

    # combine lib files for various platforms into one
    echo "Framework: Creating library..."

    IPHONE_LIB="${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
    SIMULATOR_LIB="${PROJBASE}/$BUILD_DIR/$CONFIG-iphonesimulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"

    CREATE_ARG_FOR_LIPO=""

    if [ -f $IPHONE_LIB ]
    then
        CREATE_ARG_FOR_LIPO="$CREATE_ARG_FOR_LIPO $IPHONE_LIB"
    fi

    if [ -f $SIMULATOR_LIB ]
    then
        CREATE_ARG_FOR_LIPO="$CREATE_ARG_FOR_LIPO $SIMULATOR_LIB"
    fi

    echo "lipo -create $CREATE_ARG_FOR_LIPO -o $FRAMEWORK_DIR/$FRAMEWORK_NAME"
    lipo -create $CREATE_ARG_FOR_LIPO -o "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
}


#
# compress the dist folder (excluding hidden files)
#
createDistributionPackage()
{
    /bin/echo Compressing...
    cd $BUILD_DIR

    /usr/bin/tar --exclude '.*' -czf $DISTGZ $DIST_DIR_NAME

    cd ..
}

echo Starting...

# prepare directories
prepareDirs

# pick an sdk
chooseSDKs

#
# loop through all build styles and build them all
#
for S in ${TARGET_LIST[*]}
do
    TARGET=$S

    FRAMEWORK_NAME=GT

    for C in ${CONFIG_LIST[*]}
    do
        CONFIG=$C

        echo "CURRENT_TARGET = $TARGET"
        echo "CURRENT_CONFIG = $CONFIG"

        FRAMEWORK_BUILD_PATH="${PROJBASE}/$BUILD_DIR/$DIST_DIR_NAME"
        echo "FRAMEWORK_BUILD_PATH = $FRAMEWORK_BUILD_PATH"

        rm -rf ${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/$FRAMEWORK_NAME.framework
        rm -rf ${PROJBASE}/$BUILD_DIR/$CONFIG-iphonesimulator/$FRAMEWORK_NAME.framework

        # build sdk
        buildGTSdk


        if  [ -f ${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/Demo4GT.ipa ]
        then
            cp ${PROJBASE}/$BUILD_DIR/$CONFIG-iphoneos/Demo4GT.ipa $DIST_DIR/Demo4GT_$CONFIG.ipa
            continue
        fi

        # create framework
        createFramework
        # create distribution package
        createDistributionPackage

        # copy package to upload folder
        echo "Copying $BUILD_DIR/$DISTGZ to upload folder"
        mv $BUILD_DIR/$DISTGZ result/

        # copy to demo prj
        rm -rf ../$Demo4GT_proj_ios/$DIST_GZ_DIR
        echo "Copying $BUILD_DIR/$DIST_DIR_NAME/DIST_GZ_DIR to ../$Demo4GT_proj_ios/"
        cp -R $BUILD_DIR/$DIST_DIR_NAME/$DIST_GZ_DIR ../$Demo4GT_proj_ios/
    done
done

#
# exit
#
/bin/echo Done.
if ! [ $returnCode = 0 ]
then
exit 1001
fi

exit 0
