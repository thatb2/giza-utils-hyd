#!/bin/bash
# To be executed from Jenkins like:
# source ./jenkins_jobs/build_and_publish_ios  GIZA_HOME BUNDLE_GEMFILE UIDG_ADMIN PWDG_ADMIN PROPERTIES_ADMIN UIDG PWDG PROPERTIES WORKSPACE

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/utils_ios.sh

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

clean_reports
rm -f prpcMobileHC.apk
kill_dirty_processes
setup_begin

function move_html_reports() {
  if [ -d "$GIZA_HOME/rspec_html_reports" ]; then
    if [ ! -d "$GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE/rspec_html_reports_build" ]; then
      echo "Moving to build"
      mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE/rspec_html_reports_build
    else
      echo "Moving to run"
      mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE/rspec_html_reports_run
    fi
  fi
}

function local_cleanup() {
  move_html_reports
}

trap cleanup_on_exit EXIT

#**************** Building HC app in prpc mobile tab ****************#
cd $GIZA_HOME
run_bundle_install

echo 'Start testing HC BUILD'

RSPEC_FILE_PATH="$GIZA_HOME/mobile/features/Offline/DataSync/BuildAndPublish/spec/hc_build_spec.rb"
bundle exec rspec $RSPEC_FILE_PATH -e 'Create application for iOS' -c -b -f RspecHtmlFormatter -f JUnit -o ${WORKSPACE}/reports/report.xml -fd | { tee /dev/stderr | grep "###IPA LINK### " | awk '{print $3}' > /tmp/android-test-build-publish-hc-output.txt; }

echo 'Tests of HC BUILD finished SUCESSFULLY'
mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE/rspec_html_reports_build

app_url=$(cat /tmp/android-test-build-publish-hc-output.txt)
echo "app_url="${app_url}

cd $JENKINS_WORKSPACE
echo 'Downloading built app'
curl -L -o prpcMobileHC.ipa $app_url

echo 'Installing app on device'      
ideviceinstaller -i prpcMobileHC.ipa 

start_appium

RSPEC_FILE_PATH="$GIZA_HOME/mobile/features/Offline/DataSync/BuildAndPublish/spec/hc_launch_spec.rb"
check_file_exists $RSPEC_FILE_PATH

PROPERTIES_FILE_PATH=$(get_properties_file_path $RSPEC_FILE_PATH)
check_file_exists $PROPERTIES_FILE_PATH

set_up_credentials UIDG PWDG $PROPERTIES_FILE_PATH
set_up_global_properties PROPERTIES

cd $GIZA_HOME
echo 'Start testing'

bundle exec rspec $RSPEC_FILE_PATH -c -b -f RspecHtmlFormatter -f JUnit -o ${WORKSPACE}/reports/report.xml -fd

echo 'Tests finished SUCCESSFULLY'

mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE/rspec_html_reports_run

remove_apps_from_device
