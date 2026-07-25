#!/bin/sh
set -eu

package_dir="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
repository_root="$(CDPATH= cd -- "$package_dir/../.." && pwd)"
package_relative="${package_dir#"$repository_root"/}"

template="$package_dir/po/templates/ccsn-observability.pot"
translation="$package_dir/po/zh_Hans/ccsn-observability.po"
scanner="${LUCI_I18N_SCAN:-}"

if [ -z "$scanner" ]; then
	for candidate in \
		"$repository_root/feeds/luci/build/i18n-scan.pl" \
		"$repository_root/openwrt/feeds/luci/build/i18n-scan.pl"
	do
		if [ -f "$candidate" ]; then
			scanner="$candidate"
			break
		fi
	done
fi

if [ ! -f "$scanner" ]; then
	echo "LuCI i18n-scan.pl not found; set LUCI_I18N_SCAN to the official scanner path" >&2
	exit 1
fi

cd "$repository_root"
perl "$scanner" "$package_relative" > "$template"

msgmerge --update --backup=none --no-fuzzy-matching "$translation" "$template"
