#!/bin/sh -e

if [ $# -lt 1 -o $# -gt 2 -o "$1" = "-h" -o "$1" = "--help" ]; then
	cat >&2 <<-END
	Usage: $(basename $0) <owner>/<repo>[@<tag>] [<asset-regex>]

	Download GitHub release assets from a private repo. Requires curl and jq.
	GITHUB_TOKEN must contain a valid personal access token.
	END
	exit 2
fi

case "$1" in
*@*)
	REPO="${1%%@*}"
	RELEASE="tags/${1#*@}";;
*)
	REPO="$1"
	RELEASE="latest";;
esac

REGEX="${2:--$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/amd64/')\.tar\.gz$}"

list_assets() {
	curl -fLSs -u $GITHUB_TOKEN: -H 'Accept: application/vnd.github.v3+json' \
		https://api.github.com/repos/$REPO/releases/$RELEASE | \
		jq --arg re "$REGEX" -r '.assets[] | select(.name | test($re)) | "\(.name)\t\(.url)"'
}

fetch() {
	local found
	while read name url; do
		found=1
		echo "Downloading $name"
		curl -LSs -u $GITHUB_TOKEN: -H 'Accept: application/octet-stream' \
			-o "$name" "$url"
		case "$name" in
		*.tar.gz)
			tar -xzf "$name" && rm "$name";;
		*.zip)
			unzip -oq "$name" && rm "$name";;
		esac
	done
	test "$found" || { echo "No asset matches for \"$REGEX\""; exit 1; }
}

list_assets | fetch
