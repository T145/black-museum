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
    CURL) curl --proto '=https' --tlsv1.3 -sSf "$2" ;;
    LYNX) lynx -dump -listonly -nonumbers "$2" ;;
    *) ;;
    esac
}

# params: filter
apply_filter() {
    case "$1" in
    ENERGIZED) jq -r '.sources[].url' ;;
    STEVENBLACK) jq -r 'to_entries[] | .value.sourcesdata[].url' ;;
    OISD) cat -s ;;
    1HOSTS) mawk '$0~/^http/' ;;
    *) ;;
    esac |
        parsort -u -S 100% --parallel=48 -T "$CACHE" |
        sponge "imports/${1,,}.txt"
}

# params: filter
compare_lists() {
    local partial_count
    local full_count
    local result

    partial_count=$(grep -Fxvf data/master.txt "imports/${1,,}.txt" | wc -l)
    full_count=$(wc -l <"imports/${1,,}.txt")
    result=$(echo "scale=2; r=$partial_count/$full_count; r*=100; r-=100; r*=-1; r" | bc)

    echo "${1,,}: ${result}%" >> exports/results.txt
}

main() {
    # "data/lists.json" is a mandatory requirement
    mkdir -p imports exports
    download_list 'CURL' 'https://raw.githubusercontent.com/T145/black-mirror/master/exports/sources.txt' > data/master.txt
    :> exports/results.txt

    jq -r '.[] | "\(.downloader) #\(.url)#\(.filter)"' data/lists.json |
    while IFS='#' read -r downloader url filter; do
        download_list "$downloader" "$url" | apply_filter "$filter"
        compare_lists "$filter"
    done
}

main

# reset the locale after processing
unset LC_ALL
