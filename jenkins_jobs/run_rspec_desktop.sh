#!/bin/bash
# To be executed from Jenkins execut shell section like:
# source ./jenkins_jobs/run_rspec_desktop.sh GIZA_HOME BUNDLE_GEMFILE RSPEC_FILE_PATH RSPEC_TEST_NAME UIDG_ADMIN PWDG_ADMIN PROPERTIES_ADMIN WORKSPACE

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

RSPEC_TEST_NAME=${!4}
check_not_empty RSPEC_TEST_NAME

UIDG_ADMIN=${!5}
check_not_empty UIDG_ADMIN

PWDG_ADMIN=${!6}
check_not_empty PWDG_ADMIN

PROPERTIES_ADMIN=${!7}
check_not_empty PROPERTIES_ADMIN

JENKINS_WORKSPACE=${!8}
check_not_empty JENKINS_WORKSPACE
check_dir_exists $JENKINS_WORKSPACE
normalize JENKINS_WORKSPACE

PROPERTIES_FILE_PATH=$(get_properties_file_path $RSPEC_FILE_PATH)
check_file_exists $PROPERTIES_FILE_PATH

set_up_credentials UIDG_ADMIN PWDG_ADMIN $PROPERTIES_FILE_PATH

if (echo "$PROPERTIES_ADMIN" | grep -q ":applicationIdentifier:"); then
  if ! (echo "$PROPERTIES_ADMIN" | grep ":applicationIdentifier:" | grep -q "$APP_ID_PREFIX"); then
    echo "Expected applicationIdentifier to contain '$APP_ID_PREFIX'! Exiting."
    exit 1
  fi
fi

set_up_global_properties PROPERTIES_ADMIN
check_working_dir
clean_reports

kill_dirty_processes

function move_html_reports() {
  if [ -d "$GIZA_HOME/rspec_html_reports" ]; then
    mv -f $GIZA_HOME/rspec_html_reports $JENKINS_WORKSPACE
  fi
}

function local_cleanup() {
  move_html_reports
}

trap cleanup_on_exit EXIT

#**************** Building HC app in prpc mobile tab ****************#
cd $GIZA_HOME
run_bundle_install

echo 'Start testing on DESKTOP'
/usr/bin/xvfb-run --server-args="-screen 0 2560x1600x8" bundle exec rspec $RSPEC_FILE_PATH -e "$RSPEC_TEST_NAME" -c -b -f RspecHtmlFormatter -f JUnit -o ${WORKSPACE}/reports/report_build_publish.xml -fd
echo 'Tests on DESKTOP finished SUCCESSFULLY'
move_html_reports
