#!/bin/bash -e

# echo "AAAA '$0' '$2'" >&2
# [ "$1" != "-c" ] || exec /bin/sh "$@"

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
[ -n "$sdkver" ] || sdkver=$(/usr/bin/sw_vers -productVersion)
_sdkver="$sdkver"
while : ; do
    case $_sdkver in
        *.*)
            _sdkver="${_sdkver%.*}"
            sdkver="$sdkver $_sdkver"
            ;;
        *) break ;;
    esac
done
for _sdkver in $sdkver ; do
    case $DEVELOPER_DIR in
	*/CommandLineTools)
		SDKROOT="$DEVELOPER_DIR/SDKs/MacOSX${_sdkver}.sdk"
		;;
	*/Developer)
		SDKROOT="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${_sdkver}.sdk"
		;;
    esac
    [ ! -d "$SDKROOT/" ] || break
    SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX${_sdkver}.sdk"
    [ ! -d "$SDKROOT/" ] || break
	SDKROOT="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${_sdkver}.sdk"
    [ ! -d "$SDKROOT/" ] || break
done
if [ -z "$SDKROOT" -o ! -d "$SDKROOT" ] ; then
  	echo "Can not find SDK for MacOSX/macOS $MACOSX_DEPLOYMENT_TARGET (MACOSX_DEPLOYMENT_TARGET)."
  	exit 1
fi
unset _sdkver sdkver

PATH="/usr/bin:/bin:/usr/sbin:/sbin"
PATH="$HOMEBREW_PREFIX/Library/VirtualBrew/shims:$PATH"
PATH="$HOMEBREW_PREFIX/Library/Homebrew/shims/super:$PATH"
export PATH

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

PATH="$HOMEBREW_PREFIX/bin:$PATH:${SDKROOT}/usr/bin"

export DEVELOPER_DIR SDKROOT MACOSX_DEPLOYMENT_TARGET PATH

# Phew. Finished re-loading the environment
# -----------------------------------------

# _formlver=$(basename "$HOMEBREW_FORMULA_PREFIX")
FORMULANAME=$(basename "$(dirname "$HOMEBREW_FORMULA_PREFIX")")
# echo "FORMULANAME=$FORMULANAME " >&2
# echo "$versions" | sed '/-/!{s/$/_/}' | sort -V | sed 's/_$//'
case $FORMULANAME in
    -disabled--p11-kit)
        unset MACOSX_DEPLOYMENT_TARGET
        # exec "$@"
        ;;
    "python@2")
        # links in opt not here yet
        p=$(ls "$HOMEBREW_PREFIX/Cellar/sphinx-doc/"*/bin/sphinx-build | tail -n1)
        [ -z "$p" ] || p=$(dirname "$p")
        PATH="$p:$PATH"
        export PATH
        unset p
        ;;
    "gpgme")
        p=$(ls "$HOMEBREW_PREFIX/Cellar/gnupg/"*/bin/gpg-agent | tail -n1)
        [ -z "$p" ] || p=$(dirname "$p")
        PATH="$p:$PATH"
        export PATH
        unset p
        ;;
    "pep-adapter-enigmail")
        export LDFLAGS="-L'$HOME/../contrib/engine/asn.1'  $LDFLAGS"
        #export CFLAGS="-D_sqlite3_close_v2=_sqlite3_close $CFLAGS"
        ;;
esac

# p=$(ls "$HOMEBREW_PREFIX/Cellar/sphinx-doc/"*/bin/sphinx-build | tail -n1)
# PATH="$p:$PATH"
# export PATH

#case "$1 $2" in
#    "make html")
#        set
#        p=$(ls "$HOMEBREW_PREFIX/Cellar/sphinx-doc/"*/bin/sphinx-build | tail -n1)
#        export PATH="$p:$PATH"
#        unset p
#        ;;
#esac

# This is for swig, and is like -isystem, so to respond to include <Python.h> instead of incldue "Python.h"
C_INCLUDE_PATH="/Library/Frameworks/pEpDesktopAdapter.framework/Versions/A/Cellar/python@2/2.7.14_3/Frameworks/Python.framework/Versions/2.7/include/python2.7:$C_INCLUDE_PATH"
# CPLUS_INCLUDE_PATH="$CPLUS_INCLUDE_PATH"
export C_INCLUDE_PATH

# export HOMEBREW_PREFER_CLT_PROXIES=1

SHIM_SHELL="$HOMEBREW_PREFIX/Library/VirtualBrew/shims/sh"

repl() {
    #printf "%q\n" "$(sed "s/$2/$3/g" "$*")"
    echo "$1" | sed "s/$2/$3/g"
}

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
		"-march=native")
            args[${#args[@]}]="-march=core2" ;;
		"--disable-dependency-tracking")
            args[${#args[@]}]="--disable-dependency-tracking"
            vbrew_conf_no_dep_track=""
            ;;
		*)
            args[${#args[@]}]="$argval"
            ;;
	esac
done

# Quirks
#vbrew_make_args=$(printf "%q %q\n" "CC=$CC -arch i386 -arch x86_64" "CXX=$CXX -arch i386 -arch x86_64")

case $arg1 in
    -*)
		export CPP CXXCPP CC CXX CPPFLAGS CXXCPPFLAGS CFLAGS CXXFLAGS LDFLAGS LTCC LTCFLAGS
		# export CONFIG_SHELL="$SHIM_SHELL"
        export SHELL="$SHIM_SHELL"
        exec /bin/bash "$arg1" "${args[@]}"
        ;;
	*/configure)
		export CPP CXXCPP CC CXX CPPFLAGS CXXCPPFLAGS CFLAGS CXXFLAGS LDFLAGS LTCC LTCFLAGS
		export CONFIG_SHELL="$SHIM_SHELL"
		grep -q disable-dependency-tracking "$arg1" || vbrew_conf_no_dep_track=""
        # _machtype=$(clang --version | awk "/Target: / {print \$2}")
        # tgt="--host=$_machtype --build=x86_64-apple-darwin11.2"
		exec "$arg1" $tgt $vbrew_conf_no_dep_track "${args[@]}"
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
        echo "IN MAKE '$1'" >&2
        case "$FORMULANAME|$1" in
            "python@2|html")
                # This fails with syntax error even when passing PYTHON=python3 ...
                exit 0
                ;;
        esac
        case "$FORMULANAME" in
            "pep-adapter-enigmail")
            ( cd "$HOME/.." ; patch -p1 <<'EOF'
--- a/contrib/engine/src/pEpEngine.c	2018-05-01 00:00:12.000000000 +0200
+++ b/contrib/engine/src/pEpEngine.c	2018-05-01 00:00:39.000000000 +0200
@@ -1486,10 +1486,10 @@
                     NULL,
                     NULL
                 );
-                sqlite3_close_v2(session->db);
+                sqlite3_close(session->db);
             }
             if (session->system_db)
-                sqlite3_close_v2(session->system_db);
+                sqlite3_close(session->system_db);
         }

         release_transport_system(session, out_last);
EOF
            ) ;;
        esac
		if [ -n "$ARCH" -a -e libtool ] ; then
			CC="$CC $ARCH"
			CXX="$CXX $ARCH"
		fi
		export CPP CXXCPP CC CXX CPPFLAGS CXXCPPFLAGS CFLAGS CXXFLAGS LDFLAGS LTCC LTCFLAGS
		vbrew_make_e=""
		[ x${args[0]} == x-e ] || vbrew_make_e="-e $vbrew_make_e"
		# exec "$arg1" $vbrew_make_e $vbrew_make_args "${args[@]}"
        for KV in "$@" ; do
        case $KV in
            -*) echo "X $KV" ;;
            *=*)echo "Y $KV" ; eval export "$(printf '%q\n' "$KV")" ;;
        esac ; done
        export MAKE="${MAKE-make} -e"
        echo "MAKE=$MAKE"
		echo RUN exec "$arg1" $vbrew_make_e "${args[@]}" $vbrew_make_args "MAKE=make -e" >&2
        C_INCLUDE_PATH="/Library/Frameworks/pEpDesktopAdapter.framework/Versions/A/opt/asn1c/share/asn1c:$C_INCLUDE_PATH"
        # export CMAKE_LIBRARY_PATH="$HOME/contrib/engine/asn.1:$CMAKE_LIBRARY_PATH"
		exec "$arg1" $vbrew_make_e "${args[@]}" $vbrew_make_args \
            "C_INCLUDE_PATH=$C_INCLUDE_PATH" "MAKE=make -e"
            # "CMAKE_LIBRARY_PATH=$CMAKE_LIBRARY_PATH" "C_INCLUDE_PATH=$C_INCLUDE_PATH" "MAKE=make -e"
		;;
esac


export CPP CXXCPP CC CXX CPPFLAGS CXXCPPFLAGS CFLAGS CXXFLAGS LDFLAGS LTCC LTCFLAGS
export SHELL="$SHIM_SHELL"
if [ -x "$(which "$arg1")" ] ; then
    exec "$arg1" "${args[@]}"
fi
exec /bin/bash "$arg1" "${args[@]}"

