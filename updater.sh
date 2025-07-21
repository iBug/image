#!/bin/bash

if [ "$1" = cleanup ]; then
  rm -rf .github .gitignore .nojekyll *.sh CNAME
  exit 0
fi

set -e

REMOTE=iBug/image
BRANCH=master

REMOTE2=iBugOne/image
BRANCH2=master

ecode=0

export SSH_AUTH_SOCK=none
mkdir -p ~/.ssh

# Prepare SSH stuff
if [ -z "$SSH_KEY_E" ]; then
  echo "SSH key not found!" >&2
  ecode=1
elif git log -1 --pretty=format:%s | grep -qiF '[squash]'; then
  base64 -d <<< "$SSH_KEY_E" | gunzip -c > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519
  export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519"

  git clone --depth=1 --branch="$BRANCH" "git@github.com:$REMOTE.git" work
  cd work
  shopt -s nullglob
  git checkout --orphan temp
  git add -A
  git -c user.name=GitHub -c user.email=noreply@github.com \
    commit -m "Auto squash from GitHub Actions [ci skip]"
  git branch -M "$BRANCH"
  git push origin +HEAD:"$BRANCH"
fi

if [ -z "$SSH_KEY_E2" ]; then
  echo "Alternate SSH key not found!" >&2
  ecode=1
else
  base64 -d <<< "$SSH_KEY_E2" | gunzip -c > ~/.ssh/id_ed25519
  chmod 600 ~/.ssh/id_ed25519
  export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519"

  rm -rf .github .gitignore *.sh CNAME
  git checkout --orphan temp
  git add -A
  git -c user.name=GitHub -c user.email=noreply@github.com \
    commit -m "Auto squash from GitHub Actions [ci skip]"
  git remote add origin2 "git@github.com:$REMOTE2.git"
  git push origin2 +HEAD:"$BRANCH2"
fi

if [ -z "$NETLIFY_AUTH_TOKEN" -o -z "$NETLIFY_SITE_ID" ]; then
  echo "No Netlify credentials found, skipping Netlify." >&2
else
  rsync -vr --delete --exclude={.*,CNAME,node_modules,package.json,*.sh} ./ _temp/
  mkdir -p _temp
  sudo npm install --global netlify-cli
  npx netlify deploy --dir=_temp --prod
fi

exit $ecode
