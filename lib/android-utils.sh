#!/bin/bash

#info "Loaded android utilities"

[[ -n "${ANDROID_HOME}" ]] && \
    PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${PATH}"

declare -r _adb_="$(resolve adb)"

function adb() {
    if [[ -n "${_adb_}" ]]; then
        debug "${_adb_} $@" 
        ${_adb_} "$@"
    else
        error "adb not available; ignoring adb $@"
    fi
}

declare -r _reconnect_="$(resolve reconnect)"

function reconnect() {
    if [[ -n "${_reconnect_}" ]]; then
        debug "${_reconnect_} $@" 
        ${_reconnect_} "$@"
    else
        error "reconnect not available; ignoring reconnect $@"
    fi
}

function remove_apps_from_device() {
    local -r _app_prefix_="$1"
    local -r _exit_message_="$2"
    adb shell 'pm list packages -f' | grep "${_app_prefix_}" | cut -f2- -d'=' | tr -d '\r' | \
    while read -r app_id ; do
        info "Uninstalling application '${app_id}' from device"
        adb uninstall "${app_id}"
    done
    info "${_exit_message_}"
}

function kill_appium() {
    local -r _appium_url_="$1"
    if [[ -n "${_appium_url_}"  && -x "${workspace}/jq" ]]; then
        local -a _sessions_=$( \
            curl --silent "${_appium_url_}/sessions" | \
            "${workspace}/jq" '.value[] | .sessionId' | tr -d '"' \
        )
        local _session_
        for _session_ in "${_sessions_[@]}"; do
            info "Deleting appium session ${_session_}"
            curl --silent --request DELETE "${_appium_url_}/session/${_session_}"
        done
    fi
    if ps aux | grep -q '[a]ppium'; then
        kill $(ps aux | grep '[a]ppium' | awk '{print $2}') > /dev/null 2>&1
    fi
}

function start_appium_if_needed() {
    local -r _appium_url_="$1"
    local -r _app_url_="$2"

    local _uri_="http://localhost:4723"
    local _host_="localhost"
    local _port_="4723"
    if [[ -n "${_appium_url_}" ]]; then
       local -a _comps_=($(parse_uri "${_appium_url_}" uri host port))
       debug "Parsed appium_url ${_comps_[@]}"
       _uri_="${_comps_[0]}"
       _host_="${_comps_[1]}"
       _port_="${_comps_[2]}"
    fi

    if [[ "${_host_}" == "localhost" || "${_host_}" =~ "127.0.0." ]]; then
        info "About to use local appium"
        adb kill-server
        reconnect
        sleep 2
        remove_apps_from_device "${APP_ID_PREFIX}" "Applications removed BEFORE test"

        local -a _appium_args_=( \
            "--port" "${_port_}" \
            "--app" "${_app_url_}" \
            "--log" "${workspace}/appium.log" \
            "--log-level" "warn:info" \
            "--log-timestamp" \
            "--local-timezone" \
            "--session-override" \
            "--full-reset" \
        )

        [[ -x "${chromedriver_executable}" ]] && \
          _appium_args_+=( \
              "--chromedriver-executable" "${chromedriver_executable}" \
          )

        info "Starting appium with options ${_appium_args_[@]}"
        require appium
        kill_appium  
        appium ${_appium_args_[@]} &
        onexit kill_appium "${_uri_}" 
        sleep 2
    fi

    info "Testing appium connectivity"
    curl --silent "${_uri_}/status"
}
