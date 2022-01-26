#!/usr/bin/env bash
#shopt -s extdebug     # or --debugging
set +H +o history     # disable history features (helps avoid errors from "!" in strings)
shopt -u cmdhist      # would be enabled and have no effect otherwise
shopt -s execfail     # ensure interactive and non-interactive runtime are similar
shopt -s extglob      # enable extended pattern matching (https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html)
set -euET -o pipefail # put bash into strict mode & have it give descriptive errors
umask 055             # change all generated file perms from 755 to 700
export LC_ALL=C       # force byte-wise sorting and default langauge output

CACHE=$(mktemp -d)
readonly CACHE
trap 'rm -rf "$CACHE"' EXIT || exit 1

# params: download utility, url
download_list() {
    case "$1" in
    CURL) curl --proto '=https' --tlsv1.3 -H 'Accept: application/vnd.github.v3+json' -sSf "$2" ;;
    LYNX) lynx -dump -listonly -nonumbers "$2" ;;
    *)
        echo '[ERROR] Undesignated download utility!'
        exit 1
        ;;
    esac
}

# params: filter
apply_filter() {
    case "$1" in
    ENERGIZED) jq -r '.sources[].url' ;;
    STEVENBLACK) jq -r 'to_entries[] | .value.sourcesdata[].url' ;;
    OISD) cat -s ;;
    1HOSTS) cat -s ;;
    *)
        echo '[ERROR] No filter given!'
        ;;
    esac |
        parsort -u -S 100% --parallel=48 -T "$CACHE" |
        sponge "imports/${1,,}.txt"
}

main() {
    mkdir -p imports

    jq -r '.[] | "\(.downloader)#\(.url)#\(.filter)"' data/lists.json |
        while IFS='#' read -r downloader url filter; do
            download_list "$downloader" "$url" | apply_filter "$filter"
        done
}

main

# reset the locale after processing
unset LC_ALL
