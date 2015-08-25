#!/bin/bash

# this file should be run in /Meeples folder on jenkins
# this script copies jobs with full configuration from ML9 to ML9 (hyd,kr/cw)

#copy jobs - CW & Build and publish
for dirpath in $(find . -type d -maxdepth 2 -regex '.*CW.*'); do
  echo cp -r $dirpath "${dirpath/CW/ML9CW}"
  cp -r $dirpath "${dirpath/CW/ML9CW}"
done

for dirpath in $(find . -type d -maxdepth 2 -regex '.*Build-and-publish.*'); do
  echo cp -r $dirpath "${dirpath/Build/ML9Build}"
  cp -r $dirpath "${dirpath/Build/ML9Build}"
done

for dirpath in $(find . -type d -maxdepth 2 -regex '.*HC.*'); do
  echo cp -r $dirpath "${dirpath/HC/ML9HC}"
  cp -r $dirpath "${dirpath/HC/ML9HC}"
done

for dirpath in $(find . -type d -maxdepth 2 -regex '.*Set.*'); do
  echo cp -r $dirpath "${dirpath/Set/ML9Set}"
  cp -r $dirpath "${dirpath/Set/ML9Set}"
done

#change names of copied jobs
for dirpath in $(find . -type d -maxdepth 2 -regex '.*ML9.*') ; do
  name=`echo $dirpath`
  if [[ $name =~ .*hyd02_8043.* ]]; then
     mv "$dirpath" "${dirpath/hyd02_8043/hyd03_8743}"
  fi
   if [[ $name =~ .*kra06_8282.* ]]; then
    mv "$dirpath" "${dirpath/kra06_8282/kra03_8282}"
  fi
   if [[ $name =~ .*hyd02_9191.* ]]; then
    mv "$dirpath" "${dirpath/hyd02_9191/hyd03_9191}"
  fi
   if [[ $name =~ .*kra06_8243.* ]]; then
    mv "$dirpath" "${dirpath/kra06_8243/kra03_8243}"
  fi
done

#change properties in these changed jobs:
for configfile in $(find . -regex '.*ML9.*/config.xml.*') ; do
  echo $configfile

  #hyd8043
  sed -e s/ssdehydwin02.rpega.com:8043/ssdehydwin03.rpega.com:8743/ $configfile >test.tmp && mv test.tmp $configfile
  sed -e s/com.pega.mobile.prpcoffline.n028043debug/com.pega.mobile.prpcoffline.n038743debug/ $configfile >test.tmp && mv test.tmp $configfile
  sed -e s/_Build-and-publish-android-hyd02_8043/_Build-and-publish-android-hyd03_8743/ $configfile >test.tmp && mv test.tmp $configfile

  #hyd02:9191
  sed -e s/ssdehydwin02.rpega.com:9191/ssdehydwin03.rpega.com:9191/ $configfile >test.tmp && mv test.tmp $configfile
  sed -e s/com.pega.mobile.prpcoffline.n029191debug/com.pega.mobile.prpcoffline.n039191debug/ $configfile >test.tmp && mv test.tmp $configfile
  sed -e s/_Build-and-publish-android-hyd02_8043/_Build-and-publish-android-hyd03_9191/ $configfile >test.tmp && mv test.tmp $configfile

  #kra06:8243
  sed -e s/kra-eng-sls06.rpega.com:8243/kra-eng-sls03.rpega.com:8243/ $configfile >test.tmp && mv test.tmp $configfile
  sed -e s/com.pega.mobile.prpcoffline.nkra88243debug/com.pega.mobile.prpcoffline.nkra98243debug/ $configfile >test.tmp && mv test.tmp $configfile
  sed -e s/_Build-and-publish-android-kra06_8243/_Build-and-publish-android-kra03_8243/ $configfile >test.tmp && mv test.tmp $configfile

  #kra06:8282
  sed -e s/kra-eng-sls06.rpega.com:8282/kra-eng-sls03.rpega.com:8282/ $configfile >test.tmp && mv test.tmp $configfile
  sed -e s/com.pega.mobile.prpcoffline.nkra88282debug/com.pega.mobile.prpcoffline.nkra98282debug/ $configfile >test.tmp && mv test.tmp $configfile
  sed -e s/_Build-and-publish-android-kra06_8282/_Build-and-publish-android-kra03_8282/ $configfile >test.tmp && mv test.tmp test
done

#delete ML9 label
for dirpath in $(find . -type d -maxdepth 2 -regex '.*ML9.*') ; do
  name=`echo $dirpath`
  echo $string
  if [[ $name =~ .*ML9CW.* ]]; then
    mv "$dirpath" "${dirpath/ML9CW/CW}"
  fi
  if [[ $name =~ .*ML9Build.* ]]; then
    mv "$dirpath" "${dirpath/ML9Build/Build}"
  fi
  if [[ $name =~ .*ML9Set.* ]]; then
    mv "$dirpath" "${dirpath/ML9Set/Set}"
  fi
  if [[ $name =~ .*ML9HC.* ]]; then
    mv "$dirpath" "${dirpath/ML9HC/HC}"
  fi
done
