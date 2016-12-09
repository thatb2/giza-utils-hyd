#!/bin/bash
# To be executed from Jenkins execut shell section like:
# source ./jenkins_jobs/giza_svn_update.sh GIZA_HOME

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/utils.sh

GIZA_HOME=${!1}
check_not_empty GIZA_HOME
check_dir_exists $GIZA_HOME
normalize GIZA_HOME

cd $GIZA_HOME
git checkout master
git clean -fd
git checkout .
git gc --prune
git status
git pull origin master
#svn revert -R .
#svn update -r HEAD --non-interactive --no-auth-cache --username readonly --password readonly --accept tf
#svn checkout -r HEAD --non-interactive --no-auth-cache --username readonly --password readonly --accept tf
