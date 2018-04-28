#!/bin/sh -e

if [ -z "$HOMEBREW_PREFIX" ] ; then
	while [ ! -d "${HOMEBREW_PREFIX-/dev/null}" ] ; do HOMEBREW_PREFIX="$(dirname "$0")" ; done
	    # Library/VirtualBrew/shims
	HOMEBREW_PREFIX=$(cd "$HOMEBREW_PREFIX/../../.." ; pwd)
fi

if [ -r "$HOMEBREW_PREFIX/environment" ] ; then
	MACOSX_DEPLOYMENT_TARGET=$( . "$HOMEBREW_PREFIX/environment" 2>&1 >/dev/null ; echo "$MACOSX_DEPLOYMENT_TARGET" )
fi

if [ -z "$MACOSX_DEPLOYMENT_TARGET" ] ; then
	SDKROOT=$(/usr/bin/readlink "$HOMEBREW_PREFIX/Library/VirtualBrew/MacOSX.sdk" || true)
	if [ -d "$SDKROOT" ] ; then
		MACOSX_DEPLOYMENT_TARGET=${SDKROOT##*/MacOSX}
		MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET%%.sdk}
	fi
fi

sdkver_for_product() {
	sdkver="$1"
	[ -n "$sdkver" ] || sdkver="$(sw_vers -productVersion)"
	sdkver=( $(echo "$sdkver" | tr . ' ' ) )
	echo "${sdkver[0]}.${sdkver[1]}"
}

DEVELOPER_DIR=$(/usr/bin/readlink "$HOMEBREW_PREFIX/Library/VirtualBrew/CommandLineTools" || true)
if [ ! -d "$DEVELOPER_DIR" ] ; then
	DEVELOPER_DIR="/Library/Developer/CommandLineTools"
	if [ ! -d  "$DEVELOPER_DIR" ] ; then
		DEVELOPER_DIR=$( unset DEVELOPER_DIR ; unset SDKROOT ; xcode-select -p 2>/dev/null || true )
	fi
	if [ -z "$DEVELOPER_DIR" -o ! -d "$DEVELOPER_DIR" ] ; then
		echo "Error: Can not find Command Line Tools or Xcode." >&2
		exit 1
	fi
fi

sdkver="$MACOSX_DEPLOYMENT_TARGET"
[ -n "$sdkver" ] || sdkver=$(sw_vers -productVersion)
sdkver=( $(echo "$sdkver" | tr . ' ') )
for _sdkver in "${sdkver[0]}.${sdkver[1]}.${sdkver[2]}" "${sdkver[0]}.${sdkver[1]}" "${sdkver[0]}" ; do
    case $DEVELOPER_DIR in
	*/CommandLineTools)
		SDKROOT="$DEVELOPER_DIR/SDKs/MacOSX${_sdkver}.sdk"
		;;
	*/Developer)
		SDKROOT="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${_sdkver}.sdk"
		;;
    esac
    [ ! -d "$SDKROOT" ] || break
done
if [ -z "$SDKROOT" -o ! -d "$SDKROOT" ] ; then
  	echo "Can not find SDK for MacOSX/macOS $MACOSX_DEPLOYMENT_TARGET (MACOSX_DEPLOYMENT_TARGET)."
  	exit 1
fi

PATH=/usr/bin:/bin:/usr/sbin:/sbin

if [ -r "$HOMEBREW_PREFIX/environment" ] ; then
	. "$HOMEBREW_PREFIX/environment" 2>&1 >/dev/null
else
	echo "Error: failed to read file 'environment' from HOMEBREW_PREFIX='$HOMEBREW_PREFIX'." >&2
	exit 1
fi

if [ -x "$DEVELOPER_DIR/usr/bin/clang" ] ; then
  PATH="$PATH:$DEVELOPER_DIR/usr/bin"
else
  PATH="$PATH:$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin"
  PATH="$PATH:$DEVELOPER_DIR/usr/bin"
fi

if [ -x "$HOMEBREW_PREFIX/opt/m4/bin/m4" ] ; then
    PATH="$PATH:$HOMEBREW_PREFIX/opt/m4/bin/m4"
fi

PATH="$HOMEBREW_PREFIX/Library/VirtualBrew/shims:$HOMEBREW_PREFIX/bin:$PATH:${SDKROOT}/usr/bin"

export DEVELOPER_DIR SDKROOT MACOSX_DEPLOYMENT_TARGET PATH


# Phew. Finished re-loading the environment
# -----------------------------------------

repl() {
    #printf "%q\n" "$(sed "s/$2/$3/g" "$*")"
    echo "$1" | sed "s/$2/$3/g"
}

# export HOMEBREW_PREFER_CLT_PROXIES=1

SHIM_SHELL="$HOMEBREW_PREFIX/Library/VirtualBrew/shims/sh"

CFLAGS=$(repl "$CFLAGS" "-march=native" "-march=core2")
CXXFLAGS=$(repl "$CXXFLAGS" "-march=native" "-march=core2")


arg1="$1" ; shift

# set +x
# echo =========================================================
# VARS=( MACOSX_DEPLOYMENT_TARGET SDKROOT DEVELOPER_DIR \
#     HOMEBREW_PREFER_CLT_PROXIES PATH HOMEBREW_RUBY_PATH \
#     CPPFLAGS CFLAGS CXXFLAGS LDFLAGS CPP CC CXXCPP CXX LTCC LTCFLAGS )
# for VAR in "${VARS[@]}" ; do
#     dumpvar $VAR
# done
# echo export "${VARS[@]}"
# for VAR in "${VARS[@]}" ; do
#     echo echo "$VAR=\$$VAR"
# done
# echo =========================================================
# set -x

vbrew_conf_no_dep_track="--disable-dependency-tracking"

args=()
for argval in "$@" ; do
	case $argval in
		"-march=native") args[${#args[@]}]="-march=core2" ;;
		"--disable-dependency-tracking") args[${#args[@]}]="--disable-dependency-tracking" ; vbrew_conf_no_dep_track="" ;;
		*) args[${#args[@]}]="$argval" ;;
	esac
done

# Quirks
#vbrew_make_args=$(printf "%q %q\n" "CC=$CC -arch i386 -arch x86_64" "CXX=$CXX -arch i386 -arch x86_64")

case $arg1 in
	*/configure)
		export CPP CXXCPP CC CXX CPPFLAGS CXXCPPFLAGS CFLAGS CXXFLAGS LDFLAGS LTCC LTCFLAGS
		export CONFIG_SHELL="$SHIM_SHELL"
		grep -q disable-dependency-tracking configure || vbrew_conf_no_dep_track=""
		exec "$arg1" $vbrew_conf_no_dep_track "${args[@]}"
	;;
	"./bootstrap.sh")
		# --with-libraries=filesystem,program_options,system,thread
		if [ -n "$BOOST_LIBS" ] ; then
			f=()
			for argval in "${args[@]}" ; do
				case $argval in
					"--without-"*) f[${#f[@]}]="--with-libraries=$BOOST_LIBS" ;;
					*) f[${#f[@]}]="$argval" ;;
				esac
			done
			exec ./bootstrap.sh --with-toolset=clang "${f[@]}"
		fi
		exec ./bootstrap.sh --with-toolset=clang "${args[@]}"
		;;
	"./b2")
		exec ./b2 --toolset=clang \
		    cxxflags="$CXXFLAGS -std=c++11 -stdlib=libc++ -w" \
		    linkflags="$LDFLAGS -stdlib=libc++" "${args[@]}"
		;;
	*/make|make)
		if [ -n "$ARCH" -a -e libtool ] ; then
			CC="$CC $ARCH"
			CXX="$CXX $ARCH"
		fi
		export CPP CXXCPP CC CXX CPPFLAGS CXXCPPFLAGS CFLAGS CXXFLAGS LDFLAGS LTCC LTCFLAGS
		vbrew_make_e=""
		[ x${args[0]} == x-e ] || vbrew_make_e="-e $vbrew_make_e"
		exec "$arg1" $vbrew_make_e $vbrew_make_args "${argvals[@]}" "${args[@]}"
		;;
esac

[ -x "$arg1" ] || exec /bin/sh "$arg1" "${args[@]}"
exec "$arg1" "${args[@]}"
