#!/usr/bin/env bash

# after axil42's script to update the package on AUR
# https://github.com/axilleas/bin/blob/master/ff

# no guarantees!

pushd . >& /dev/null
cd /tmp

mozillas_ftp="ftp://ftp.mozilla.org/pub/firefox/releases"
latest_beta_bundle_asc="${mozillas_ftp}/latest-beta/source/firefox-*.bundle.asc"
latest_rel_bundle_asc="${mozillas_ftp}/latest/source/firefox-*.bundle.asc"

echo "Version checks ..."

rm -f firefox-*.bundle.asc

wget -q $latest_beta_bundle_asc

if [ -f firefox-*.bundle.asc ]; then 
    latest_beta_ver=$(ls -1 firefox-*.bundle.asc | sed 's/^firefox-\([[:digit:]]\+\.[[:digit:]]\+b[[:digit:]]\+\)\.bundle\.asc$/\1/')
    echo "Latest beta version: " $latest_beta_ver
    rm -f firefox-*.bundle.asc
fi

wget -q $latest_rel_bundle_asc
if [ -f firefox-*.bundle.asc ]; then 
    latest_rel_ver=$(ls -1 firefox-*.bundle.asc | sed 's/^firefox-\([[:digit:]]\+\.[[:digit:]]\)\.bundle\.asc$/\1/')
    echo "Latest released version: " $latest_rel_ver 
    rm -f firefox-*.bundle.asc
fi

if [[ "$latest_bet_ver" == "$latest_rel_ver" ||
	    "$latest_bet_ver" == "$latest_rel_ver"* ]]; then
    echo "Beta channel empty! Setting newpkgver to " $latest_rel_ver
    newpkgver=$latest_rel_ver
else
    echo "Setting newpkgver to " $latest_beta_ver
    newpkgver=$latest_beta_ver
fi

# Link of SHA1SUMS file

sha="${mozillas_ftp}/${newpkgver}/SHA1SUMS"

installed_ver=`pacman -Qi firefox-beta-bin | grep 'Version' | awk 'BEGIN { FS = " : " } ; { print $2 }' | sed 's/-[[:digit:]]\+$//'`
echo "Installed version: " $installed_ver

if [[ "$installed_ver" == "$newpkgver" ]]; then
    echo "It appears the latest available version is already installed [$newpkgver]!"
    # exit
fi

curr_ver=`cower -i firefox-beta-bin | grep Version | awk 'BEGIN { FS = " : " } ; { print $2 }'`
echo "Current AUR version: " $curr_ver

echo "Checking if new version exists @mozilla [by getting SHA1SUMS] ..."

if [ -f SHA1SUMS ]; then rm SHA1SUMS; fi
wget -q $sha

if [ -f SHA1SUMS ]; then
    echo "Version $newpkgver exists. Starting build process."

    echo "Dowloading firefox-beta-bin from AUR ..."

    cower -df firefox-beta-bin -t /tmp
    cd /tmp/firefox-beta-bin
    cp /tmp/SHA1SUMS .

    echo 'Stripping SHA1SUM from downloaded file ...'
    newsha64=`grep -w "linux-x86_64/en-US/firefox-$newpkgver.tar.bz2" SHA1SUMS | awk 'NR==1{print $1}'`
    newsha32=`grep -w "linux-i686/en-US/firefox-$newpkgver.tar.bz2" SHA1SUMS | awk 'NR==1{print $1}'`

    echo 'Get old SHA1SUMS into variables, from the PKGBUILD ...'
    oldsha64=`grep sha1sums PKGBUILD | head -n1 | cut -c 12-51`
    oldsha32=`grep sha1sums PKGBUILD | tail -n1 | cut -c 42-81`

    # Old package version, from PKGBUILD
    oldpkgver=`grep pkgver PKGBUILD | head -n1 | cut -c 8-13`

    echo "Changing pkgver..."
    echo "# old pkgver: $oldpkgver"
    echo "# new pkgver: $newpkgver "
    echo
    sed -i "s/$oldpkgver/$newpkgver/" PKGBUILD

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
    echo "Found no SHA1SUMS file in ${mozilla_ftp}/$newpkgver"
fi
