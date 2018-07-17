#!/usr/bin/env bash
# Rebuild all assets in place to test composer changes and prep for release.
# Will not update the core composer.lock file (to do so delete it first).

BASEDIR=$(dirname "$BASH_SOURCE")
cd $BASEDIR/../
BASEDIR=$( pwd )

echo ; echo "Pulling mautic-eb"
git pull

echo ; echo "Cleaning up the build space."
rm -rf ./mautic ./bin ./vendor ./plugins ./mautic_custom
mkdir -p ./plugins
touch ./plugins/.gitkeep

echo ; echo "Setting composer.lock and composer.custom files from the dist coppies."
cp composer.lock.dist composer.lock
cp composer.custom.dist composer.custom

echo ; echo "Standard install."
composer install --no-interaction

bash ./scripts/core-patches.sh

echo ; echo "Forcing updates to custom plugins"
rm -rf ./mautic_custom
git clone -b master https://github.com/TheDMSGroup/mautic-eb-custom.git ./mautic_custom
rm -rf ~/.composer/cache/files/thedmsgroup/*
composer update "thedmsgroup/*" --no-interaction

echo ; echo "Compiling Mautic JS/CSS assets."
composer assets --no-interaction

echo ; echo "Checking assets."
if cat ./mautic/media/css/app.css | grep '#00b49c' > /dev/null 2>&1
then
    echo "Warning. Default bootstrap styles detected. Theme compilation must have failed."
    echo "Trying again..."
    composer assets
	if cat ./mautic/media/css/app.css | grep '#00b49c' > /dev/null 2>&1
	then
	    echo "No luck. Abort build!"
	else
	    echo "And they look good (on second try)."
	fi
    exit 1
else
    echo "And they look good."
fi

echo ; echo "Here's a diff of what this build changes."
git --no-pager diff --minimal

# Only needed if building for production:
# composer install --no-dev --no-interaction