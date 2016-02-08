#!/bin/bash
# To be executed from Jenkins execut shell section like:
# source ./jenkins_jobs/run_rspec_andr.sh GIZA_HOME BUNDLE_GEMFILE RSPEC_FILE_PATH APP_URL UIDG PWDG PROPERTIES WORKSPACE
#set +x
source ~/.rvm/scripts/rvm
#set -x
#set -e


DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/utils.sh

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

function stub_html_reports() {
  cp -a $JENKINS_WORKSPACE/jenkins_jobs/rspec_html_reports $GIZA_HOME
}

function move_html_reports() {
  if [ -d "$GIZA_HOME/rspec_html_reports" ]; then
    mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE
  fi
}

function local_cleanup() {
  move_html_reports
  adb logcat  -v time -d > $JENKINS_WORKSPACE/logs/logcat.log
}

trap cleanup_on_exit EXIT

stub_html_reports
check_server_connection

set_up_credentials UIDG PWDG $PROPERTIES_FILE_PATH
set_up_global_properties PROPERTIES

# commenting the following code since it is not required for every test case.
#echo 'Downloading latest stable app'
#rm -f *.apk

#wget --quiet -O prpcMobileHC.apk $APP_URL

adb kill-server
sleep 10
#adb start-server
#sleep 5
#remove_apps_from_device $APP_ID_PREFIX 'Applications removed BEFORE test'

#echo 'Installing app on device'
#adb install -r *.apk

start_appium
pwd
sleep 2
cd_to_giza_home
#set +x
#source ~/.rvm/scripts/rvm
#set -x
#cd "$GIZA_HOME"
echo "Bundle Install"
run_bundle_install

echo "Start testing of '$RSPEC_FILE_PATH'"
adb devices | grep -v 'List'
adb devices | grep -v 'List' > abc.txt
_file="abc.txt"
sleep 2
function start_adb() {
  count=0
  while [  $(tr -d "\r\n" < "$_file"|wc -c) -eq 0 ] ;  do
      let "count+=1"
      echo "Waiting for adb to start ..."
      if [ ${count} -eq 5 ]; then
          return 1
      fi
      adb kill-server
      sleep 20
      adb devices | grep -v 'List' > abc.txt
      sleep 2
  done
}
start_adb
rm -rf $GIZA_HOME/abc.txt
adb logcat -c
trap cleanup_on_exit EXIT
bundle exec rspec  -f RspecHtmlFormatter $RSPEC_FILE_PATH -c -b -f JUnit -o ${JENKINS_WORKSPACE}/reports/report.xml -fd
adb logcat -v time -d > $JENKINS_WORKSPACE/logs/logcat.log
echo 'Tests finished SUCCESSFULLY'
move_html_reports
#remove_apps_from_device $APP_ID_PREFIX 'Applications removed AFTER test'
