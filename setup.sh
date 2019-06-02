#!/usr/bin/env bash

# compile and move to executable folder
make macpaste
mkdir -p $HOME/bin && cp macpaste $HOME/bin/

# create launcher agent
mkdir -p $HOME/Library/LaunchAgents && cat local.macpaste.plist | sed 's@$HOME@'"$HOME"'@' | sed 's@$ARG@'"$1"'@'> $HOME/Library/LaunchAgents/local.macpaste.plist

echo ""
echo "    Go to System Preferences -> Security & Privacy -> Privacy:"
echo "    Add $HOME/bin/macpaste"
echo ""
echo "    Log out & Log in. Enjoy!"
echo ""
