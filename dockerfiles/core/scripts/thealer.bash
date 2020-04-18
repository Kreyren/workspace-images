#!/bin/bash

###! This file is expected to process the required packages on the system and if either of them is not possible to be installed from disto -> Provide it manually

# FIXME-POSIX: This has to be converted in posix to support posix-based dockerfiles

efixme() { [ "$IGNORE_FIXME" != 1 ] && printf 'FIXME: %s\n' "$1" ;}
eerror() { printf 'ERROR: %s\n' "$1" ;}
einfo() { printf 'INFO: %s\n' "$1" ;}
edebug() { [ "$DEBUG" = 1 ] && printf 'DEBUG: %s\n' "$1" ;}
die() {
	case "$1" in
		2) printf 'SYNERR: Argument %s was not recognized\n' "$2" ;;
		23) printf 'SAFETY-TRAP: %s\n' "$2" ;;
		bug)
			printf "BUG: %s, please file a new issue in $UPSTREAM" "$2"
			exit 1 ;;
		[0-9]|[0-9][0-9]|[0-9][0-9][0-9]) printf 'FATAL: %s\n' "$2" ;;
		*)
			printf 'FATAL: %s\n' "$2"
			exit 1
		;;
	esac

	exit "$1"
}
ebench() {
	# Allow skipping benchmark
	case "$SKIP_BENCHMARK" in 
		1) return 0 ;;
		"") true ;;
		*) die 23 "Variable SKIP_BENCHMARK has unexpected value '$SKIP_BENCHMARK', expecting only '1' or blank"
	esac

	case "$1" in
		start)
			SECONDS=0
			return 0 ;;
		result)
			printf "BENCHMARK: Action %s took $SECONDS seconds\n" "$1"
			return 0 ;;
		*) die 2 "$1 TEST"
	esac

	die 23 "Logic in function 'ebench' escaped sanitization"
}

myName="installer"

# May not be needed
# # Check dependencies
# for cmd in git; do
# 	if command -v $cmd >/dev/null; then die 126 "$cmd"; fi
# done

# DO_NOT_MERGE
efixme "Generating package lists, this takes too much time and has to be resolved"

# Define list of available packages to be used in logic
# NOTICE: If the command is not found it complains about it -> Sent sterr in devnull
# FIXME: This should be defined in dockerfile so that it's not generating everytime myName is called
aptList="$(apt list 2>/dev/null)"
#paludisList="$(cave print-packages 2>/dev/null)"
# NOTICE: We may need to use EIX_LIMIT=0 here to output all packages
#portageList="$(eix --only-names 2>/dev/null)"
# FIXME: Implement prebuilt binaries for merge
#binaryList=""

einfo "List generated"

# DO_NOT_MERGE: Proper implementation needed
DISTRO="debian"
RELEASE="stable"

manuallInstall() {
	# In case we are able to merge in system using pre-compiled binary package
	if [ "$binaryList" = "$1" ]; then
		case "$1" in
			*) die bug "Package '$1' is not supported in binaryList which should never happend"
		esac
	fi

	# Linux From Source time
	# FIXME: Make sure that /usr/src/ is available to us (based on FSH3_0 it's optional directory which may not be present)
	case "$1" in
		nim)
			ebench start
			eerror "Script $myName was unable to process package $1 using upstream management, using manuall export"
			git clone https://github.com/nim-lang/Nim.git /usr/src/nim || exit 1
			cd /usr/src/nim || exit 1
			build_all.sh || die bug "upstream of package '$1' failed to provide working manuall management"
			ebench result "installing package '$1' LFS-style on '$DISTRO' with release '$RELEASE'"
		;;
		*) die fixme "Package '$1' is not supported for manuall installation assuming that it's not supported by upstream of $DISTRO/$RELEASE"
	esac
}

downMan() {
	# Convertion of expected packages (This may be different per distro)
	case "$1" in
		emacs|app-editors/emacs)
			aptPackage="emacs"
			exherboPackage="app-editors/emacs"
			gentooPackage="app-editors/emacs" ;;
		nim|dev-lang/nim)
			aptPackage="nim/$RELEASE"
			exherboPackage="dev-lang/nim"
			gentooPackage="dev-lang/nim" ;;
		golang-go|dev-lang/go)
			aptPackage="golang-go"
			exherboPackage="dev-lang/go" 
			gentooPackage="dev-lang/go" ;;
		*)
			eerror "Package '$1' does not have a known convertion, trying default"
			aptPackage="$1"
			exherboPackage="$1"
			gentooPackage="$1" ;;
	esac

	# CORE
	case "$DISTRO/$RELEASE" in
		"debian/stable"|"debian/testing"|"ubuntu/eoan")
			# Check if package is available
			# shellcheck disable=SC2154 # DO_NOT_MERGE: Check if this is still required
			if printf '%s\n' "$aptList" | grep -m 1 -q "^$aptPackage"; then
				apt-get install -y "$aptPackage" || manuallInstall "$aptPackage"
				ebench result "installing package '$1' on $DISTRO with release $RELEASE using distro's downstream"
			elif ! printf '%s\n' "$aptList" | grep -m 1 -q "^$aptPackage"; then
				manuallInstall "$aptPackage"
			else
				die 255 "Processing $aptPackage in $DISTRO/$RELEASE"
			fi
		;;
		exherbo/*)
			# Check if package is available
			if printf '%s\n' "$paludisList" | grep -m 1 -q "^$exherboPackage\$"; then
				if ! cave print-ids -m '*/*::/' | grep -m 1 -q "^$exherboPackage-.*:.*::installed\$"; then
					cave resolve "$1" -x || eerror "Distribution '$DISTRO' with release '$RELEASE' failed to install package '$1', using manuall installation" && manuallInstall "$1"
					ebench result "installing package '$1' on '$DISTRO' with release '$RELEASE'"
				elif cave print-ids -m '*/*::/' | grep -m 1 -q "^$exherboPackage-.*:.*::installed\$"; then
					einfo "Package '$1' is already installed on distribution '$DISTRO' with release '$RELEASE', nothing else to do.."
				fi
			elif ! printf '%s\n' "$paludisList" | grep -m 1 -q "^$exherboPackage-.*:.*::installed"; then
				manuallInstall "$1"
			else
				die 255 "Processing '$1' in '$DISTRO/$RELEASE'"
			fi
		;;
		gentoo/*)
			# Check if package is available
			if printf '%s\n' "$portageList" | grep -m 1 -q "^$gentooPackage\$"; then
				if ! eix-installed -a | grep -m 1 -q "^$gentooPackage-.*\$"; then
					emerge -vuDNj "$gentooPackage" || manuallInstall "$1"
				elif eix-installed -a | grep -m 1 -q "^$gentooPackage-.*\$"; then
					einfo "Package '$1' is already installed on $DISTRO/$RELEASE, no need to do anything.."
				else
					die 255 
				fi
			elif ! printf '%s\n' "$portageList" | grep -m 1 -q "^$gentooPackage\$"; then
				manuallInstall "$1"
			else
				die 255 "Processing package '$1' in $DISTRO/$RELEASE"
			fi
		;;
		*) die 1 "Unexpected distro '$DISTRO' with release '$RELEASE' has been parsed in $myName wrapper"
	esac

	# Self-check
	# FIXME
}

ebench start # Start benchmark

# FIXME: Sanitize for package manager version used, i.e apt 2.0.0 changed how wildcards behave -> Simmilar change might break poor thealer

# Process packages from arguments
# NOTICE: -ge is used because '0' is shell
while [ "$#" -ge 1 ]; do case "$1" in
	# FIXME: Allow passing multiple arguments to install subcommand
	install)
		shift 1 # Shift 'install'
		while [ "$#" -ge 1 ]; do case "$1" in
			nim|git|nano|vim|emacs|htop|less|zip|unzip|tar|rustc|cargo|openbox|python|python3|pylint|golang|php|ruby|apache2|nginx|novnc|cppcheck|valgrind)
				downMan "$1"
				shift 1
			;;
			# APT specific
			apt-transport-https|build-essentials)
				case "$DISTRO/$RELEASE" in
					debian/*|ubuntu/*)
						apt install -y "$1" || die 1 "Unable to install package '$1'"
					;;
					*) edebug "Distribution '$DISTRO/$RELEASE' does not support apt specific package '$1'"
				esac
			shift 1
			;;
			# Shellcheck in debian stable is not usable, see https://github.com/gitpod-io/workspace-images/pull/204#issuecomment-614463958
			# FIXME: Implement a logic that checks if shellcheck 0.7.0 lended in stable
			shellcheck)
				case "$DISTRO/$RELEASE" in
					debian/stable)
						apt install -t testing -y "$1" || die 1 "Unable to install package '$1'"
					;;
					*)
						downMan "$1"
				esac
			shift 1
			;;
			# Portage specific
			gentoolkit|app-portage/gentoolkit)
				case "$DISTRO/$RELEASE" in
					gentoo/*)
						emerge -vuDNj "$2" || die 1 "Unable to install package '$2' on distribution '$DISTRO' with release '$RELEASE'"
					;;
					*) edebug "Distribution '$DISTRO/$RELEASE' does not support portage specific package '$2'"
				esac
				shift 1
			;;
			*) die fixme "Package '$2' is not yet supported on $DISTRO/$RELEASE"
			esac; done
	;;
	"") exit 0 ;;
	*) die 2 "$1"
esac; done