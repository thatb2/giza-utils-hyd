#!/bin/bash
# To be executed from Jenkins execut shell section like:
# source ./jenkins_jobs/run_rspec_andr.sh GIZA_HOME BUNDLE_GEMFILE RSPEC_FILE_PATH APP_URL UIDG PWDG PROPERTIES WORKSPACE

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/utils_ios.sh

APP_ID_PREFIX="com.pega"

GIZA_HOME=${!1}
check_not_empty GIZA_HOME
check_dir_exists $GIZA_HOME
normalize GIZA_HOME

BUNDLE_GEMFILE=${!2}
check_not_empty BUNDLE_GEMFILE

RSPEC_FILE_PATH=${!3}
check_not_empty RSPEC_FILE_PATH
check_file_exists $RSPEC_FILE_PATH

APP_URL=${!4}
check_not_empty APP_URL

UIDG=${!5}
check_not_empty UIDG

PWDG=${!6}
check_not_empty PWDG

PROPERTIES=${!7}
check_not_empty PROPERTIES

JENKINS_WORKSPACE=${!8}
check_not_empty JENKINS_WORKSPACE
check_dir_exists $JENKINS_WORKSPACE
normalize JENKINS_WORKSPACE

PROPERTIES_FILE_PATH=$(get_properties_file_path $RSPEC_FILE_PATH)
check_file_exists $PROPERTIES_FILE_PATH

check_working_dir
clean_reports
kill_dirty_processes
setup_begin

function move_html_reports() {
  if [ -d "$GIZA_HOME/rspec_html_reports" ]; then
    mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE
  fi
}

function local_cleanup() {
  move_html_reports
#  adb logcat  -v time -d > $JENKINS_WORKSPACE/logs/logcat.log
}

trap cleanup_on_exit EXIT

check_server_connection

set_up_credentials UIDG PWDG $PROPERTIES_FILE_PATH
set_up_global_properties PROPERTIES

echo 'Downloading latest stable app'
rm -f *.ipa

curl -L -o prpcMobileHC.ipa $APP_URL

remove_apps_from_device $APP_ID_PREFIX 'Applications removed BEFORE test'

echo 'Installing app on device'
ideviceinstaller -u $(get_udid_ios_device) -i *.ipa

start_appium
cd "$GIZA_HOME"
run_bundle_install

echo "Start testing of '$RSPEC_FILE_PATH'"
#adb logcat -c
bundle exec rspec  -f RspecHtmlFormatter $RSPEC_FILE_PATH -c -b -f JUnit -o ${JENKINS_WORKSPACE}/reports/report.xml -fd
#adb logcat -v time -d > $JENKINS_WORKSPACE/logs/logcat.log
echo 'Tests finished SUCCESSFULLY'
move_html_reports
remove_apps_from_ios_device $APP_ID_PREFIX 'Applications removed AFTER test'
