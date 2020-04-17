#!/bin/sh
# Created by Jacob Hrbek <kreyren@rixotstudio.cz> under GPLv3 license <https://www.gnu.org/licenses/gpl-3.0.en.html> in 17/04/2020 05:57

###! Perform a speedtest on hard-coded and available mirror and use the fastest and most reliable (assuming enough tries performed)
###! Additional info:
###! - ENVIRONMENT: This is expected to be invoked in docker build environment -> Reasoning to use capped vars this way
###! - Use `netselect-apt --nonfree --sources stable |& grep -A 1 "Of the hosts tested we choose the fastest valid for HTTP:" | grep -o "http://.*"` to get the fastest mirror -> Configure /etc/apt/sources.list with it
###! Code-quality:
###! - We are expecting shellcheck[>=0.7.0] ideally latest

# FIXME: Add translations
# FIXME: Support other distributions

# Skip this whole script if disabled is used (including sourcing below which is the reason for this here)
[ "$SPEEDTEST_TRIES" = disabled ] && exit 0

efixme() { printf 'FIXME: %s\n' "$1" ;}
eerror() { printf 'ERROR: %s\n' "$1" ;}
einfo() { printf 'INFO: %s\n' "$1" ;}
edebug() { [ "$IGNORE_FIXME" != 1 ] && printf 'DEBUG: %s\n' "$1" ;}
die() {
	case "$1" in
		2) printf 'SYNERR: %s\n' "Argument '$2' was not recognized" ;;
		*) printf 'FATAL: %s\n' "$2" ;;
	esac

	exit "$1"
}

# MAINTAINERS: Change this in case script name changes
myName="apt-mirror-benchmark"

# In case we want to change the location (supported by apt)
targetList="/etc/apt/sources.list"

# Do not perform tests if explicitedly disabled
case "$SPEEDTEST_TRIES" in
	[0-9]|[0-9][0-9]|[0-9][0-9][0-9]) true ;;
	# This expects SPEEDTEST_TRIES to terminate the script with exit code 0 at the top of the script
	disabled) die 1 "Angry Kreyren: WHO DARED TO REMOVE MY SPEEDTEST_TRIES TRAP?! Those are here for a reason u know.. -_-\"" ;;
	*) die 2 "Unexpected value '$SPEEDTEST_TRIES' of variable SPEEDTEST_TRIES has been parsed, expected variables are only integers"
esac

[ -z "$APT_MIRROR" ] && die 1 "Script $myName expects variable APT_MIRROR set on preffered mirror"

[ ! -f /etc/os-release ] && die 1 "Script $myName expects file /etc/os-release"
# FIXME: Check if SPEEDTEST_TRIES is numerical
[ -z "$SPEEDTEST_TRIES" ] && die 1 "Script $myName requires variable SPEEDTEST_TRIES set on number of expected speedtests"

DISTRO="$(grep -o "^ID=.*" /etc/os-release)"

# Make sure that none is running this on unsupported distro
case "${DISTRO##ID=}" in
	debian)
		if ! command -v apt >/dev/null; then die 1 "This debian does not have expected apt, runtime is not adapted to handle this situation"; fi
	;;
	*) die 1 "Distribution '$DISTRO' is not supported by $myName script"
esac

# Ensure that we have the required permission
if [ "$(id -u)" != 0 ]; then
	if command -v sudo; then
		export SUDO="sudo"
	elif ! command -v sudo; then
		die 1 "Unable to acquire root permission (sudo not available)"
	else
		die 255 "Unexpected happend while trying to acquire root using sudo"
	fi
elif [ "$(id -u)" = 0 ]; then
	unset SUDO # We don't need sudo on root
else
	die 255 "Unexpected happend while checking user with id '$(id -u)'"
fi

if ! command -v netselect-apt >/dev/null; then
	"$SUDO" apt install -y netselect-apt || die 1 "Unable to install package 'netselect-apt'"
	# Self-check
	if ! command -v netselect-apt >/dev/null; then die 1 "Self-check for availability of netselect-apt failed"; fi
elif command -v netselect-apt >/dev/null; then
	true
else
	die 255 "Unexpected happend while processing netselect-apt command"
fi

einfo "wtf"

# Declare fastest mirrors
# NOTICE: Command 'netselect-apt' requires root otherwise it returns exit code 1
einfo "Testing for fastest mirrors.."
# NOTICE: Do not quote SUDO, it breaks it..
# FIXME: Someone tell netselect-apt upstream to make it possible to output the fastest mirror..
APT_STABLE_MIRROR="$($SUDO netselect-apt --nonfree --sources stable 2>&1 | grep -A 1 "Of the hosts tested we choose the fastest valid for HTTP:" | grep -o "http://.*")"
APT_TESTING_MIRROR="$($SUDO netselect-apt --nonfree --sources testing 2>&1 | grep -A 1 "Of the hosts tested we choose the fastest valid for HTTP:" | grep -o "http://.*")"
APT_SID_MIRROR="$($SUDO netselect-apt --nonfree --sources sid 2>&1 | grep -A 1 "Of the hosts tested we choose the fastest valid for HTTP:" | grep -o "http://.*")"

# Self-check for mirrors
# NOTICE: netselect-apt may fail sometimes so we shoudn't be dieing here
[ -z "$APT_MIRROR_STABLE" ] && eerror "Script '$myName' failed to acquire fastest mirror for stable release" && APT_MIRROR_STABLE="$APT_MIRROR"
[ -z "$APT_TESTING_MIRROR" ] && eerror "Script '$myName' failed to acquire fastest mirror for testing release" && APT_TESTING_MIRROR="$APT_MIRROR"
[ -z "$APT_MIRROR_SID" ] && eerror "Script '$myName' failed to acquire fastest mirror for sid release" && APT_MIRROR_SID="$APT_MIRROR"

# Speedtest the found mirrors agains the one hardcoded in APT_MIRROR
tries=0
apt_mirror_speed=0
apt_mirror_stable_speed=0
apt_mirror_testing_speed=0
apt_mirror_sid_speed=0
while [ "$tries" != "$SPEEDTEST_TRIES" ]; do
	# Speedtest hard-coded mirror
	# shellcheck disable=SC1083 # Invalid - This } is literal. Check expression (missing ;/\n?) or quote it.
	apt_mirror_speed="$( printf '%s\n' "$apt_mirror_speed + $(curl --write-out %{speed_download} "$APT_MIRROR/debian/README" --output /dev/null 2>/dev/null)" | bc -q )"
	# Speedtest stable
	# shellcheck disable=SC1083 # Invalid - This } is literal. Check expression (missing ;/\n?) or quote it.
	apt_mirror_stable_speed="$( printf '%s\n' "$apt_mirror_speed + $(curl --write-out %{speed_download} "$APT_MIRROR_STABLE/debian/README" --output /dev/null 2>/dev/null)" | bc -q )"
	# Speedtest testing
	# shellcheck disable=SC1083 # Invalid - This } is literal. Check expression (missing ;/\n?) or quote it.
	apt_mirror_testing_speed="$( printf '%s\n' "$apt_mirror_testing_speed + $(curl --write-out %{speed_download} "$APT_MIRROR_STABLE/debian/README" --output /dev/null 2>/dev/null)" | bc -q )"
	# Speedtest sid
	# shellcheck disable=SC1083 # Invalid - This } is literal. Check expression (missing ;/\n?) or quote it.
	apt_mirror_sid_speed="$( printf '%s\n' "$apt_mirror_sid_speed + $(curl --write-out %{speed_download} "$APT_MIRROR_STABLE/debian/README" --output /dev/null 2>/dev/null)" | bc -q )"

	tries="$(( "$tries" + 1 ))"
done

# Get average of network speed
# NOTICE: Do not use '$(( ))', because that does not know how to process decimals
# NOTICE(Kreyren): We can implement the same logic for our own speedtest, but better outsource that on upstream of netselect-apt package
apt_mirror_speed=$(printf '%s\n' "$apt_mirror_speed / $SPEEDTEST_TRIES" | bc -q)
apt_mirror_stable_speed=$(printf '%s\n' "$apt_mirror_stable_speed / $SPEEDTEST_TRIES" | bc -q)
apt_mirror_testing_speed=$(printf '%s\n' "$apt_mirror_testing_speed / $SPEEDTEST_TRIES" | bc -q)
apt_mirror_sid_speed=$(printf '%s\n' "$apt_mirror_sid_speed / $SPEEDTEST_TRIES" | bc -q)

# Prefer hardcodded if faster
# NOTICE: In case gitpod implements their own mirror this should be adapted to report opt-in telemetry about used mirror (in case gitpod's mirror is slower which should never be the case)
# shellcheck disable=SC2034 # Used in heredoc below
[ "$apt_mirror_speed" -le "$apt_mirror_stable_speed" ] && APT_MIRROR_STABLE="$APT_MIRROR"
# shellcheck disable=SC2034 # Used in heredoc below
[ "$apt_mirror_speed" -le "$apt_mirror_testing_speed" ] && APT_MIRROR_TESTING="$APT_MIRROR"
# shellcheck disable=SC2034 # Used in heredoc below
[ "$apt_mirror_speed" -le "$apt_mirror_sid_speed" ] && APT_MIRROR_SID="$APT_MIRROR"

# CORE
# NOTICE: Do not double-quote SUDO, it breaks it..
$SUDO cat <<EOF > "$targetList"
	# Stable
	deb $APT_STABLE_MIRROR stable main non-free contrib
	deb-src $APT_STABLE_MIRROR stable main non-free contrib

	# Testing
	deb $APT_TESTING_MIRROR testing main non-free contrib
	deb-src $APT_TESTING_MIRROR testing main non-free contrib

	# SID
	deb $APT_SID_MIRROR testing main non-free contrib
	deb-src $APT_SID_MIRROR testing main non-free contrib
EOF

# Core self-check
[ ! -s /etc/apt/sources.list ] && die 1 "$myName's core self-check failed"