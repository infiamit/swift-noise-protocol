#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftNoise open source project
##
## Copyright (c) 2018-2019 Apple Inc. and the SwiftNoise project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of SwiftNoise project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -e

my_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
root_path="$my_path/.."
version=$(git describe --abbrev=0 --tags || echo "0.0.0")
modules=(SwiftNoise)

if [[ "$(uname -s)" == "Linux" ]]; then
  # build code if required
  if [[ ! -d "$root_path/.build/x86_64-unknown-linux" ]]; then
    swift build
  fi
  # setup source-kitten if required
  mkdir -p "$root_path/.build/sourcekitten"
  source_kitten_source_path="$root_path/.build/sourcekitten/source"
  if [[ ! -d "$source_kitten_source_path" ]]; then
    git clone https://github.com/jpsim/SourceKitten.git "$source_kitten_source_path"
  fi
  source_kitten_path="$source_kitten_source_path/.build/x86_64-unknown-linux/debug"
  if [[ ! -d "$source_kitten_path" ]]; then
    rm -rf "$source_kitten_source_path/.swift-version"
    cd "$source_kitten_source_path" && swift build && cd "$root_path"
  fi
  # generate
  for module in "${modules[@]}"; do
    if [[ ! -f "$root_path/.build/sourcekitten/$module.json" ]]; then
      "$source_kitten_path/sourcekitten" doc --spm-module $module > "$root_path/.build/sourcekitten/$module.json"
    fi
  done
fi

# prep index
tmp=`mktemp -d`
module_switcher="$tmp/README.md"
cat > "$module_switcher" <<"EOF"
# SwiftNoise Docs
SwiftNoise is a SwiftNoise package.
To get started with SwiftNoise, [`import SwiftNoise`](../SwiftNoise/index.html).
EOF

# run jazzy
if ! command -v jazzy > /dev/null; then
  sudo gem install jazzy
fi

jazzy_args=(--clean
            --author 'Samuel Tang'
            --readme "$module_switcher"
            --author_url https://github.com/samueltangz/swift-noise-protocol
            --github_url https://github.com/samueltangz/swift-noise-protocol
            --github-file-prefix https://github.com/samueltangz/swift-noise-protocol/tree/$version
            --theme fullwidth
            --swift-build-tool spm)

for module in "${modules[@]}"; do
  args=("${jazzy_args[@]}" --output "$tmp/docs/$version/$module" --docset-path "$tmp/docset/$version/$module" --module "$module")
  if [[ "$(uname -s)" == "Linux" ]]; then
    args+=(--sourcekitten-sourcefile "$root_path/.build/sourcekitten/$module.json")
  fi
  jazzy "${args[@]}"
done

# # push to github pages
# if [[ $CI == true ]]; then
#   BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
#   GIT_AUTHOR=$(git --no-pager show -s --format='%an <%ae>' HEAD)
#   git fetch origin +gh-pages:gh-pages
#   git checkout gh-pages
#   rm -rf "docs"
#   cp -r "$tmp/docs" .
#   cp -r "docs/$version" docs/current
#   git add --all docs
#   # echo '<html><head><meta http-equiv="refresh" content="0; url=docs/current/Crypto/index.html" /></head></html>' > index.html
#   git add index.html
#   touch .nojekyll
#   git add .nojekyll
#   changes=$(git diff-index --name-only HEAD)
#   if [[ -n "$changes" ]]; then
#     echo -e "changes detected\n$changes"
#     git commit --author="$GIT_AUTHOR" -m "publish $version docs"
#     git push origin gh-pages
#   else
#     echo "no changes detected"
#   fi
#   git checkout -f $BRANCH_NAME
# fi 