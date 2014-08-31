#!/usr/bin/env bash

# after axil42's script to update the package on AUR
# https://github.com/axilleas/bin/blob/master/ff

# no guarantees!

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

pushd . >& /dev/null
cd /tmp

source_url_root="http:\/\/ftp.mozilla.org\/pub\/firefox"
mozillas_ftp="ftp://ftp.mozilla.org/pub/firefox/releases"

newpkgver=$( curl -s "${mozillas_ftp}/?C=M;O=D" | sed 's/ \+/\t/g' | cut -f 9 | awk -f <(cat - <<-'EOD'
# mozilla firefox version numbers

function v2num (v) {
    return v*1000000;
}

/^[[:digit:]]+\.[[:digit:]]+b[[:digit:]]+$/ {
    # beta versions
    split($0,parts,"b");
    print v2num(parts[1])+parts[2] "\t" $0;    
}

/^[[:digit:]]+\.[[:digit:]]+$/ {
    # releases
    print v2num($0)+1000 "\t" $0;
    
}

EOD
) | sort -n | cut -f 2 | tail -1 )

# if the latest version is a beta, then check for release candidates

if [[ $newpkgver =~ .*b[[:digit:]]+$ ]]; then
    relver=${newpkgver%b*}
    candidate_ftp="ftp://ftp.mozilla.org/pub/firefox/candidates/${relver}-candidates/?C=M;O=D"
    rcpkgver=$( curl -s "${candidate_ftp}" | sed 's/ \+/\t/g' | cut -f 9 | sort | grep 'build[[:digit:]]$' | tail -1 | sed 's/^build//' )
    if [[ "x"$rcpkgver"x" != "xx" ]]; then
	newpkgver=${relver}rc${rcpkgver}
	download_ftp="ftp://ftp.mozilla.org/pub/firefox/candidates/${relver}-candidates/build${rcpkgver}/"
	source_url="${source_url_root}\/candidates\/${relver}-candidates\/build${rcpkgver}\/linux-\${CARCH}\/en-US\/firefox-${relver}.tar.bz2"
    else
	download_ftp="ftp://ftp.mozilla.org/pub/firefox/releases/${newpkgver}"
	source_url="${source_url_root}\/releases\/\${pkgver}\/linux-\${CARCH}\/en-US\/firefox-\${pkgver}.tar.bz2"
    fi
fi

installed_ver=`pacman -Qi firefox-beta-bin | grep 'Version' | awk 'BEGIN { FS = " : " } ; { print $2 }' | sed 's/-[[:digit:]]\+$//'`
echo "Installed version: " $installed_ver

if [[ "$installed_ver" == "$newpkgver" ]]; then
    echo "It appears the latest available version is already installed [$newpkgver]!"
    exit
else
    echo "A new version [$newpkgver] is available, will try to update ..."
fi

curr_ver=`cower -i firefox-beta-bin | grep Version | awk 'BEGIN { FS = " : " } ; { print $2 }'`
echo "Current AUR version: " $curr_ver

echo "Checking if new version really exists @mozilla [by getting SHA1SUMS from ${download_ftp}] ..."

# Link of SHA1SUMS file

sha="${download_ftp}/SHA1SUMS"

if [ -f SHA1SUMS ]; then rm SHA1SUMS; fi
wget -q $sha

if [ -f SHA1SUMS ]; then
    echo "Version $newpkgver exists. Starting build process."

    echo "Dowloading firefox-beta-bin from AUR ..."

    cower -df firefox-beta-bin -t /tmp
    cd /tmp/firefox-beta-bin
    cp /tmp/SHA1SUMS .

    echo 'Stripping SHA1SUM from downloaded file ...'
    if [[ "x"$rcpkgver"x" != "xx" ]]; then
	sha1sumver=$relver
    else
	sha1sumver=$newpkgver
    fi
    newsha64=`grep -w "linux-x86_64/en-US/firefox-$sha1sumver.tar.bz2" SHA1SUMS | awk 'NR==1{print $1}'`
    newsha32=`grep -w "linux-i686/en-US/firefox-$sha1sumver.tar.bz2" SHA1SUMS | awk 'NR==1{print $1}'`

    echo 'Get old SHA1SUMS into variables, from the PKGBUILD ...'
    oldsha64=`grep sha1sums PKGBUILD | head -n1 | cut -c 12-51`
    oldsha32=`grep sha1sums PKGBUILD | tail -n1 | cut -c 42-81`

    # Old package version, from PKGBUILD
    oldpkgver=`grep pkgver PKGBUILD | head -n1 | awk -F= '{print $2;}'`

    echo "Changing pkgver..."
    echo "# old pkgver: $oldpkgver"
    echo "# new pkgver: $newpkgver "
    echo
    sed -i "s/^pkgver=$oldpkgver$/pkgver=$newpkgver/" PKGBUILD

    echo "Changing x86_64 sha1sums..."
    echo "# old sha1sum firefox-x86_64: $oldsha64 "
    echo "# new sha1sum firefox-x86_64: $newsha64 "
    echo
    sed -i "s/$oldsha64/$newsha64/" PKGBUILD

    echo "Changing i686 sha1sums..."
    echo "# old sha1sum firefox-i686: $oldsha32 "
    echo "# new sha1sum firefox-i686: $newsha32 "
    echo
    sed -i "s/$oldsha32/$newsha32/" PKGBUILD

    echo "Changing the download source"
    echo "# new source: ${source_url}"
    sed -i 's/^source=(\".*$/source=(\"'${source_url}'\"/' PKGBUILD
    
    #### edit below for your preferred installation 
    #### one of the following blocks ...

    #### makepkg and install

    makepkg
    carch=$(uname -m)
    pwd=$(pwd)
    source PKGBUILD
    echo "Now run 'pacman -U ${pwd}/${pkgname}-${newpkgver}-${pkgrel}-${carch}.pkg.tar.xz' or similar"

    #### or (simpler ...)
    
    # makepkg -i
    
    #### build for AUR upload (just the source)
    # echo "Making source package..."
    # makepkg -f --source
    # echo "Uploading ..."
    #     source PKGBUILD
    # burp $(echo ${pkgname}-${newpkgver}-${pkgrel}.src.pkg.tar.gz

    #### after switching in one of the blocks above, enable this to get rid of the /tmp folder
    # echo "Removing firefox-beta-bin folder"
    # rm -r /tmp/firefox-beta-bin

    popd >& /dev/null
else
    echo "Found no SHA1SUMS file in ${sha}"
fi
