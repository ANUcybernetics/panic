#!/bin/bash
export LC_CTYPE=C
export LANG=C

# This will rename your project to whatever you like.
# *Warning*: if you plan to merge in future Petal Pro commits (eg if you're waiting for an upcoming feature), then perhaps hold off renaming as it makes merging harder.

# 0. If you don't have ack installed on Mac - run `brew install ack` in your terminal
# 1. Ensure you've checked your files into a git repo (`git init .`, `git add -A`, `git commit -m 'first'`)
# 2. Modify these two values to your new app name
NEW_NAME="Panic"
NEW_OTP="panic"
# 3. LINUX USERS ONLY - Scroll down and comment out lines 25/25 and uncomment lines 29/30
# 4. Execute the script in terminal: `sh rename_phoenix_project.sh`

set -e

if ! command -v ack &> /dev/null
then
    echo "\`ack\` could not be found. Please install it before continuing"
    exit 1
fi

CURRENT_NAME="PetalPro"
CURRENT_OTP="petal_pro"

# Mac users only
# ack -l $CURRENT_NAME --ignore-file=is:rename_phoenix_project.sh | xargs sed -i '' -e "s/$CURRENT_NAME/$NEW_NAME/g"
# ack -l $CURRENT_OTP --ignore-file=is:rename_phoenix_project.sh | xargs sed -i '' -e "s/$CURRENT_OTP/$NEW_OTP/g"

# Linux users only
# ack -l $CURRENT_NAME --ignore-file=is:rename_phoenix_project.sh | xargs sed -i -e "s/$CURRENT_NAME/$NEW_NAME/g"
# ack -l $CURRENT_OTP --ignore-file=is:rename_phoenix_project.sh | xargs sed -i -e "s/$CURRENT_OTP/$NEW_OTP/g"

git mv lib/$CURRENT_OTP lib/$NEW_OTP
git mv lib/$CURRENT_OTP.ex lib/$NEW_OTP.ex
git mv lib/${CURRENT_OTP}_web lib/${NEW_OTP}_web
git mv lib/${CURRENT_OTP}_web.ex lib/${NEW_OTP}_web.ex
git mv test/$CURRENT_OTP test/$NEW_OTP
git mv test/${CURRENT_OTP}_web test/${NEW_OTP}_web
