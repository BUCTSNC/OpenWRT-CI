#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

template="po/templates/ccsn-observability.pot"
translation="po/zh_Hans/ccsn-observability.po"

xgettext \
	--language=JavaScript \
	--from-code=UTF-8 \
	--keyword=_ \
	--package-name=luci-app-ccsn-observability \
	--output="$template" \
	htdocs/luci-static/resources/view/ccsn-observability/overview.js

msgmerge --update --backup=none --no-fuzzy-matching "$translation" "$template"
