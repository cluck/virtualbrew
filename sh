#!/bin/sh -e

#exec 1<&-
#exec 1>/dev/stderr
#set -vx
#set

# This wraps every call from Homebrew, and establishes itself
# to be called from all called tools.

# The most robust way to establish itself is to change the standard shell
# from /bin/sh, pointing it to this script. Every time the environment
# information is loaded again from the environment file in the HOMEBREW_PREFIX.

# [ -z "$HOMEBREW_PREFIX" ] || echo "virtualbrew wrapper: $1"

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


# abspath() {
# 	( cd "$(dirname "$1")"; d=$(dirs -l +0); echo "${d%/}/${1##*/}" )
# }

# sdkver_for_product() {
# 	sdkver="$1"
# 	[ -n "$sdkver" ] || sdkver="$(sw_vers -productVersion)"
# 	sdkver=( $(echo "$sdkver" | tr . ' ' ) )
# 	echo "${sdkver[0]}.${sdkver[1]}"
# }

# image=$(abspath "$0")
# image_name=$(basename "$image")
# case $image in
# 	*/Library/VirtualBrew/shims/sh)
# 		HOMEBREW_PREFIX="${image%*/Library/VirtualBrew/shims/sh}"
# 		;;
# esac
# if [ -z "$HOMEBREW_PREFIX" -o ! -e "$HOMEBREW_PREFIX" ] ; then
# 	echo "Error: can not determine HOMEBREW_PREFIX."
# 	exit 1
# fi 

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

case $DEVELOPER_DIR in 
	*/CommandLineTools)
		SDKROOT="$DEVELOPER_DIR/SDKs/MacOSX${MACOSX_DEPLOYMENT_TARGET}.sdk"
		;;
	*/Developer)
		SDKROOT="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${MACOSX_DEPLOYMENT_TARGET}.sdk"
		;;
esac
if [ ! -d "$SDKROOT" ] ; then
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

# /usr/local/bin/pstree -p $$ >/dev/stderr

#case ${args[0]} in
#	-c)
#		exec /bin/sh "${args[@]}"
#		;;

# echo "RUN: " "$arg1" "${args[@]}"
exec /bin/sh "$arg1" "${args[@]}"















[ -z "$CC" ] || CC=$(which clang)
[ -z "$CXX" ] || CXX=$(which clang++)
#[ -z "$CPP" ] || CPP=$(which cpp)
#[ -z "$CXXCPP" ] || CXXCPP=$(which cpp
CPP=/Applications/Xcode.app/Contents//Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/cpp
[ -x "$CPP" ] | CPP=/Library/Developer//CommandLineTools/usr/bin/cpp
# CPP="DEVELOPER_DIR='$DEVELOPER_DIR' SDKROOT='$SDKROOT' $CPP"
CXXCPP=$CPP


repl() {
    #printf "%q\n" "$(sed "s/$2/$3/g" "$*")"
    echo "$1" | sed "s/$2/$3/g"
}

CFLAGS=$(repl "$CFLAGS" "-march=native" "-march=core2")
CXXFLAGS=$(repl "$CXXFLAGS" "-march=native" "-march=core2")

_orig_CC="$CC"

# first set some specials for libpath
LTCC="$CC $CC_ARGS -arch i386 -arch x86_64"
LTCFLAGS=""
export LTCC LTCFLAGS

# CPP="$CC"
CC="$CC -arch i386 -arch x86_64"
# CXXCPP="$CXX"
CXX="$CXX -arch i386 -arch x86_64"

export CFLAGS CXXFLAGS CPPFLAGS LDFLAGS SDKROOT DEVELOPER_DIR CPP CC CXXCPP CXX


# PATH=${SDKROOT}/usr/bin:$PATH
# if [ -x "$DEVELOPER_DIR/usr/bin/clang" ] ; then
#   PATH="$PATH:$DEVELOPER_DIR/usr/bin"
# else
#   PATH="$PATH:$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin"
#   PATH="$PATH:$DEVELOPER_DIR/usr/bin"
# fi
# export PATH

if [ -x "$HOMEBREW_PREFIX/opt/m4/bin/m4" ] ; then
    PATH="$PATH:$HOMEBREW_PREFIX/opt/m4/bin/m4"
fi

dumpvar() {
	eval echo "$1=\\\"\$$1\\\""
}

export DEVELOPER_DIR SDKROOT


# clang --version

export PATH

export SHELL="$HOMEBREW_PREFIX/Library/VirtualBrew/shims/sh"

set -x

# case $1 in
# 	-*) exec "$@" ;;
# esac

arg1="$1" ; shift

set +x
echo =========================================================
VARS=( MACOSX_DEPLOYMENT_TARGET SDKROOT DEVELOPER_DIR \
    HOMEBREW_PREFER_CLT_PROXIES PATH HOMEBREW_RUBY_PATH \
    CPPFLAGS CFLAGS CXXFLAGS LDFLAGS CPP CC CXXCPP CXX LTCC LTCFLAGS )
for VAR in "${VARS[@]}" ; do
    dumpvar $VAR
done
echo export "${VARS[@]}"
for VAR in "${VARS[@]}" ; do
    echo echo "$VAR=\$$VAR"
done
echo =========================================================
set -x

args=()
for argval in "$@" ; do
	case $argval in
		"-march=native") args[${#args[@]}]="-march=core2" ;;
		*) args[${#args[@]}]="$argval" ;;
	esac
done

argvals=()
_argvals() {
	argvals=()
	div=""
	for K in "$@" ; do
		eval "val=\$$K"
		[ -n "$val" ] || continue
		argvals[${#argvals[@]}]="$K=$val"
	done
}

case $arg1 in
	"./configure")
		#_argvals CPP CXXCPP CC CXX CPPFLAGS CXXCPPFLAGS CFLAGS CXXFLAGS LDFLAGS LTCC LTCFLAGS
		exec ./configure --disable-dependency-tracking \
			"DEVELOPER_DIR=$DEVELOPER_DIR" "SDKROOT=$SDKROOT" \
		    "${args[@]}" #\
			#"${argvals[@]}" "${args[@]}"
	;;
	"./bootstrap.sh")
		# --with-libraries=filesystem,program_options,system,thread
		f=()
		for argval in "${args[@]}" ; do
			case $argval in
				"--without-"*) f[${#f[@]}]="--with-libraries=filesystem,program_options,system,thread" ;;
				*) f[${#f[@]}]="$argval" ;;
			esac
		done
		exec ./bootstrap.sh --with-toolset=clang "${f[@]}"
		;;
	"./b2")
		# --buildid=clang
		exec ./b2 --toolset=clang \
		    cxxflags="$CXXFLAGS -std=c++11 -stdlib=libc++ -w" \
		    linkflags="$LDFLAGS -stdlib=libc++" "${args[@]}"
		;;
	"make")
		# _argvals CPP CXXCPP CC CXX CPPFLAGS CXXCPPFLAGS CFLAGS CXXFLAGS LDFLAGS LTCC LTCFLAGS
		_argvals CPP CC LTCC LTCFLAGS
		exec "$arg1" -e \
			"${argvals[@]}" "${args[@]}"
			# CPP="$CPP" CXXCPP="$CXXCPP" \
		 #    CC="$CC" CXX="$CXX" CPPFLAGS="$CPPFLAGS" CXXCPPFLAGS="$CXXCPPFLAGS" \
		 #    CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" "${args[@]}"
		;;
esac


exec "$arg1" "${args[@]}"


_SDK_CFLAGS="-m32 -m64 -arch i386 -arch x86_64 -isysroot $SDKROOT"
_SDK_LDFLAGS="-arch i386 -arch x86_64"
_SDK_CPPFLAGS="-isysroot $SDKROOT"
# CC=clan

CFLAGS="$_SDK_CFLAGS $CFLAGS"
CXXFLAGS="$_SDK_CFLAGS $CXXFLAGS"
CPPFLAGS="$_SDK_CPPFLAGS $CPPFLAGS"
LDFLAGS="$S_DK_LDFLAGS $LDFLAGS"


echo MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET

set
echo ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

exec "$@"











_SDK_CFLAGS="-m32 -m64 -arch i386 -arch x86_64 -isysroot $SDKROOT"
_SDK_LDFLAGS="-arch i386 -arch x86_64"
_SDK_CPPFLAGS="-isysroot $SDKROOT"
# CC=clan

CFLAGS="$_SDK_CFLAGS $CFLAGS"
CXXFLAGS="$_SDK_CFLAGS $CXXFLAGS"
CPPFLAGS="$_SDK_CPPFLAGS $CPPFLAGS"
LDFLAGS="$S_DK_LDFLAGS $LDFLAGS"

export CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
unset _SDK_CFLAGS _SDK_LDFLAGS _SDK_CPPFLAGS
#unset DEVELOPER_DIR
export SDKROOT
export DEVELOPER_DIR

echo MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET
echo SDKROOT=$SDKROOT
echo DEVELOPER_DIR=$DEVELOPER_DIR
echo PATH=$PATH
echo export MACOSX_DEPLOYMENT_TARGET SDK DEVELOPER_DIR PATH

# ----------------