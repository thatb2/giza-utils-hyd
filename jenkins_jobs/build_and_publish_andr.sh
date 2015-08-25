#!/bin/bash
# To be executed from Jenkins like:
# source ./jenkins_jobs/build_and_publish_andr.sh  GIZA_HOME BUNDLE_GEMFILE UIDG_ADMIN PWDG_ADMIN PROPERTIES_ADMIN UIDG PWDG PROPERTIES WORKSPACE

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/utils.sh

function start_appium2() {
  echo 'Starting appium with 1600x900x8 screen'
  /usr/bin/xvfb-run --server-args="-screen 0 1600x900x8" appium --session-override -p 4444 > $JENKINS_WORKSPACE/logs/appium.log 2>&1 &
  sleep 5
}


APP_ID_PREFIX="com.pega"

GIZA_HOME=${!1}
check_not_empty GIZA_HOME
check_dir_exists $GIZA_HOME
normalize GIZA_HOME

BUNDLE_GEMFILE=${!2}
check_not_empty BUNDLE_GEMFILE

UIDG_ADMIN=${!3}
check_not_empty UIDG_ADMIN

PWDG_ADMIN=${!4}
check_not_empty PWDG_ADMIN

PROPERTIES_ADMIN=${!5}
check_not_empty PROPERTIES_ADMIN

UIDG=${!6}
check_not_empty UIDG

PWDG=${!7}
check_not_empty PWDG

PROPERTIES=${!8}
check_not_empty PROPERTIES

JENKINS_WORKSPACE=${!9}
check_not_empty JENKINS_WORKSPACE
check_dir_exists $JENKINS_WORKSPACE
normalize JENKINS_WORKSPACE

RSPEC_FILE_PATH="$GIZA_HOME/mobile/features/Offline/DataSync/BuildAndPublish/spec/hc_build_spec.rb"
check_file_exists $RSPEC_FILE_PATH

PROPERTIES_FILE_PATH=$(get_properties_file_path $RSPEC_FILE_PATH)
check_file_exists $PROPERTIES_FILE_PATH

set_up_credentials UIDG_ADMIN PWDG_ADMIN $PROPERTIES_FILE_PATH

if ! (echo "$PROPERTIES_ADMIN" | grep ":applicationIdentifier:" | grep -q "$APP_ID_PREFIX"); then
  echo "Expected applicationIdentifier to contain '$APP_ID_PREFIX'! Exiting."
  exit 1
fi

set_up_global_properties PROPERTIES_ADMIN

check_working_dir
clean_reports
rm -f prpcMobileHC.apk
kill_dirty_processes
check_server_connection
setup_begin


function move_html_reports() {
  if [ -d "$GIZA_HOME/rspec_html_reports" ]; then
    if [ ! -d "$GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE/rspec_html_reports_build" ]; then
      mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE/rspec_html_reports_build
    else
      mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE/rspec_html_reports_run
    fi
  fi
}

function local_cleanup() {
  move_html_reports
  adb logcat -v time -d > $JENKINS_WORKSPACE/logs/logcat.log
}

trap cleanup_on_exit EXIT

#**************** Building HC app in prpc mobile tab ****************#
cd $GIZA_HOME
bundle update rspec_html_formatter > /dev/null
bundle install > /dev/null

echo 'Start testing HC BUILD'
/usr/bin/xvfb-run --server-args="-screen 0 2560x1600x8" bundle exec rspec $RSPEC_FILE_PATH -e 'Create application for Android' -c -b -f RspecHtmlFormatter -f JUnit -o ${WORKSPACE}/reports/report_build_publish.xml -fd | { tee /dev/stderr | grep "###APK LINK### " > /tmp/android-test-build-publish-hc-output.txt; }
echo 'Tests of HC BUILD finished SUCESSFULLY'
move_html_reports
app_url=$(cat /tmp/android-test-build-publish-hc-output.txt | sed 's/^###APK LINK### //')

echo "app_url="${app_url}
cd $JENKINS_WORKSPACE

echo 'Downloading latest stable app'
wget --quiet -O prpcMobileHC.apk $app_url

adb kill-server
reconnect
sleep 2
remove_apps_from_device $APP_ID_PREFIX 'Applications removed BEFORE test'

echo 'Installing fresh application on device'
adb install prpcMobileHC.apk

start_appium2

RSPEC_FILE_PATH="$GIZA_HOME/mobile/features/Offline/DataSync/BuildAndPublish/spec/hc_launch_spec.rb"
check_file_exists $RSPEC_FILE_PATH

PROPERTIES_FILE_PATH=$(get_properties_file_path $RSPEC_FILE_PATH)
check_file_exists $PROPERTIES_FILE_PATH

set_up_credentials UIDG PWDG $PROPERTIES_FILE_PATH
set_up_global_properties PROPERTIES

cd "$GIZA_HOME"
echo 'Start testing'
adb logcat -c
bundle exec rspec -f RspecHtmlFormatter $RSPEC_FILE_PATH -c -b -f JUnit -o ${JENKINS_WORKSPACE}/reports/report_run.xml -fd
adb logcat -v time -d > $JENKINS_WORKSPACE/logs/logcat.log
echo 'Tests finished SUCCESSFULLY'
move_html_reports
remove_apps_from_device $APP_ID_PREFIX 'Applications removed AFTER test'
