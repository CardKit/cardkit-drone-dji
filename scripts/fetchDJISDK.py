#!/usr/bin/env python

import os
import re
import sys
import shutil
import urllib2
from zipfile import ZipFile
from StringIO import StringIO

PODSPEC_URL = "https://raw.githubusercontent.com/dji-sdk/Mobile-SDK-iOS/master/DJI-SDK-iOS.podspec"
# Hard-coding to use SDK 3.5.1 for now. 
# If you want to use the latest SDK, please set SDK_URL = ""
#SDK_URL = "http://dh7g4ai1w5iq6.cloudfront.net/ios_sdk/iOS_Mobile_SDK_3.5.1_170116.zip"
SDK_URL = ""

FRAMEWORK_PATH = "Frameworks/DJISDK.framework"

# check if the framework is present
if os.path.exists(FRAMEWORK_PATH):
	exit(0)

# download podspec
print("downloading latest DJI SDK podspec from %s" % PODSPEC_URL)
podspec = urllib2.urlopen(PODSPEC_URL)

pattern = re.compile(".*?\"(.*?)\".*?")

# if SDK_URL is empty, fetch the latest SDK source URL.
if SDK_URL == "":
	for line in podspec:
		if line.lstrip().startswith("s.source"):
			match = pattern.match(line)
			if not match is None:
				SDK_URL = match.group(1)

if SDK_URL == "":
	print("error finding DJI SDK URL from podspec")
	sys.exit(1)


# download SDK
print("downloading latest DJI SDK from %s" % SDK_URL)
sdk = urllib2.urlopen(SDK_URL)
sdk_zip = ZipFile(StringIO(sdk.read()))

# extract
print("extracting DJI SDK")
sdk_zip.extractall()

if not os.path.exists("iOS_Mobile_SDK"):
	print("didn't find iOS_Mobile_SDK, check to see what was extracted")
	sys.exit(1)

if not os.path.exists("iOS_Mobile_SDK/DJISDK.framework"):
	print("didn't find iOS_Mobile_SDK/DJISDK.framework, check to see what was extracted")
	sys.exit(1)

# move DJISDK.framework into Frameworks/
print("moving items into place")
if not os.path.exists("Frameworks"):
	os.mkdir("Frameworks")
shutil.move("iOS_Mobile_SDK/DJISDK.framework", "Frameworks")

# clean up
print("cleaning up")
shutil.rmtree("__MACOSX")
shutil.rmtree("iOS_Mobile_SDK")

# done
print("done")
