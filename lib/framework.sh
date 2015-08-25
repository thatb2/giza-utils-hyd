#!/bin/bash

[[ -z $DEBUG ]] && DEBUG="true"

# To exit from subshell
export _PID=$$

function trace() {
    if [[ -z "${NO_COLOR}" ]]; then
        >&2 echo -e "\e[35m$*\e[0m"
    else
        >&2 echo -e "$*"
    fi
}

function debug() {
    if [[ ${DEBUG} == "true" ]]; then
        if [[ -z "${NO_COLOR}" ]]; then
            >&2 echo -e "\e[37m$*\e[0m"
        else
            >&2 echo -e "$*"
        fi
    fi
}

function info() {
    if [[ -z "${NO_COLOR}" ]]; then
        >&2 echo -e "\e[32m$*\e[0m"
    else
        >&2 echo -e "$*"
    fi
}

function error() {
    if [[ -z "${NO_COLOR}" ]]; then
        >&2 echo -e "\e[31m$*\e[0m"
    else
        >&2 echo -e "$*"
    fi
}

function fail() {
    if [[ -z "${NO_COLOR}" ]]; then
        >&2 echo -e "\e[31m$*\e[0m"
    else
        >&2 echo -e "$*"
    fi
    # TERM already trapped by onexit
    #trap "exit 1" TERM
    kill -s TERM $_PID
}

function confirm() {
    read -p "$* [yes/no] " result
    echo "${result}"
}

#[[ "${BASH_SOURCE[0]}" != "${0}" ]] || \
#    fail "${BASH_SOURCE[0]} cannot be called directly."
#
#((BASH_VERSINFO[0] < 4)) && \
#    fail "Sorry, you need at least bash-4.0 to run this script."

function resolve() {
    local -r module=$(which "$1")
    if [[ ! -x "${module}" ]]; then
        echo 
    else
        echo "${module}"
    fi
}

function require() {
    local -r module="$(resolve "$1")"
    [[ -z "${module}" ]] && fail "$1 executable not found"
}

declare -a _exit_handlers_

function _onexit_() {
    for i in "${_exit_handlers_[@]}"; do
        info "onexit: $i"
        eval $i
    done
    trap - INT TERM EXIT
    if [[ -n ${EXIT_CODE} ]]; then
        info "Exiting with ${EXIT_CODE}"
        exit ${EXIT_CODE}
    fi
}

function onexit() {
    local -r n=${#_exit_handlers_[*]}
    _exit_handlers_[$n]="$*"
}

trap _onexit_ INT TERM SIGTERM EXIT

# Parse uri; first arg is uri to parse, remaining instructions on which component to return
# uri, schema, address, user, password, host, port, path, query, fragment
# usage examples:
# - parse full uri
#   declare -a comps=($(parse_uri "http://...." uri))
#   echo ${comps[0]}
# - parse host and port
#   declare -a comps=($(parse_uri "http://...." host port))
#   echo host=${comps[0]} port=${comps[1]}
function parse_uri() {
    local _uri_="$1"

    # safe escaping
    _uri_="${_uri_//\`/%60}"
    _uri_="${_uri_//\"/%22}"

    local -r _pattern_='^(([a-z]{3,5})://)?((([^:\/]+)(:([^@\/]*))?@)?([^:\/?]+)(:([0-9]+))?)(\/[^?]*)?(\?[^#]*)?(#.*)?$'
    [[ "${_uri_}" =~ ${_pattern_} ]] || return 1;

    # component extraction
    _uri_=${BASH_REMATCH[0]}
    _schema_=${BASH_REMATCH[2]}
    _address_=${BASH_REMATCH[3]}
    _user_=${BASH_REMATCH[5]}
    _password_=${BASH_REMATCH[7]}
    _host_=${BASH_REMATCH[8]}
    _port_=${BASH_REMATCH[10]}
    _path_=${BASH_REMATCH[11]}
    _query_=${BASH_REMATCH[12]}
    _fragment_=${BASH_REMATCH[13]}

    shift
    while (( $# )); do
        case "$1" in
            "uri")
                echo "${_uri_}"
                ;;
            "schema")
                echo "${_schema_}"
                ;;
            "address")
                echo "${_address_}"
                ;;
            "user")
                echo "${_user_}"
                ;;
            "password")
                echo "${_password_}"
                ;;
            "host")
                echo "${_host_}"
                ;;
            "port")
                echo "${_port_}"
                ;;
            "path")
                echo "${_path_}"
                ;;
            "query")
                echo "${_query_}"
                ;;
            "fragment")
                echo "${_fragment_}"
                ;;
        esac
        shift
    done
}

function property() {
    local -r _param_name_="$1"
    local -r _config_file_="$2"
    debug "awk \"/${_param_name_}:/ {print \$2}\" ${_config_file_}"
    awk "/${_param_name_}:/ {print \$2}" "${_config_file_}"
}

function load_config() {
    local -r config_file="$1"
    local context=$2
    local key val

    if [[ -r "${config_file}" ]]; then
        mapfile -t lines < <(cat "${config_file}" | awk '! /#/ { print }')
        for key_value_pair in "${lines[@]}"; do
           if [[ -n "${key_value_pair}" ]]; then
               # each line is assumed to be key value
               key="$(echo "${key_value_pair}" | awk '{ print $1 }')"
               val="$(echo "${key_value_pair}" | awk '{ print $2 }')"
               context["${key%?}"]="${val}"
           fi
        done
    fi
}

declare -r _curl_="$(resolve curl)"

function curl() {
   debug "${_curl_} $@" 
   ${_curl_} -w "\n" "$@"
}

function normalize() {
    if ! dir="$(unset CDPATH && cd "${!1}" > /dev/null 2>&1 && pwd)" ; then
        fail "Variable '$1' is not set to an existing directory! Exiting."
    fi
    eval "$1=$dir"
}

function check_file_exists() {
    [[ ! -f "$1" ]] && fail "File '$1' not found! Exiting."
}

function check_dir_exists() {
    [[ ! -d "$1" ]] && fail "Directory '$1' not found! Exiting."
}

function check_server_connection() {
    local -r _server_="$1"

    [[ -z "${_server_}" ]] && fail "No server URL in config file"

    local -r _conn_status_=$( \
        ${_curl_} -o /dev/null \
          --silent \
          --speed-limit 5 \
          --speed-time 5 \
          --head \
          --write-out \
          '%{http_code}\n' \
          "${_server_}" \
    )

    if (( ${_conn_status_} >= 400 )); then
        local -r _error_msg_="Connection to ${_server_} failed with status ${_conn_status_}"
        create_junit_report "${_error_msg_}"
        fail "${_error_msg_}"
    fi

    info "Connection with server: '${_server_}' verified SUCCESSFULLY!"
}

function clean_reports() {
    info "Deleting old reports..."
    rm -rf "${giza_home}/rspec_html_reports"
    rm -rf "${giza_home}"/tmp/*.har
    mkdir -p "${giza_home}/rspec_html_reports"

    rm -rf "${workspace}/reports"
    mkdir -p "${workspace}/reports/screenshots"
    rm -rf "${workspace}/rspec_html_reports"
    rm -rf "${workspace}/rspec_html_reports_build"
    rm -rf "${workspace}/rspec_html_reports_run"
}

function get_properties_file_path() {
    local -r _path_to_properties_=$(dirname "$1")
    echo "${_path_to_properties_/spec/data}/properties.yml"
}

function create_junit_report() {
    mkdir -p "${workspace}/reports"
    echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <testsuite name=\"Setup failed\" tests=\"1\">
        <testcase name=\"Error message\">
          <!--failure message=\"$1\" type=\"failed\"/-->
        </testcase>
      </testsuite>" > "${workspace}/reports/report.xml"
}

function setup_begin() {
    create_junit_report "Unknown reason"
}

