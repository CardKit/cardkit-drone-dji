#!/usr/bin/env python

import os
import re
import sys
import shutil
import urllib2
from zipfile import ZipFile
from StringIO import StringIO

PODSPEC_URL = "https://raw.githubusercontent.com/dji-sdk/Mobile-SDK-iOS/master/DJI-SDK-iOS.podspec"
SDK_URL = ""

# download podspec
print("downloading latest DJI SDK podspec from %s" % PODSPEC_URL)
podspec = urllib2.urlopen(PODSPEC_URL)

pattern = re.compile(".*?\"(.*?)\".*?")

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
