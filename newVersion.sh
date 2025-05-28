#!/bin/bash

set -euo pipefail

# Check that jq is installed
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' is required but not installed."
  exit 1
fi

# Check that Node.js and npx are installed
if ! command -v npx &> /dev/null; then
  echo "Error: 'npx' is required but not installed."
  exit 1
fi

# Get and filter versions from npm using jq
versions_json=$(npm view create-nx-workspace versions --json)
filtered_versions=$(echo "$versions_json" | jq -r '
  .[]
  | select(
      test("(canary|beta|pr|rc|alpha)") == false and
      . != "0.0.1" and
      . != "0.0.2" and
      (
        (split(".") | map(tonumber)) as $v |
        ($v[0] > 20) or
        ($v[0] == 20 and $v[1] >= 0)
      )
    )
')

# Store valid versions in array
versions=()
while IFS= read -r version; do
  versions+=("$version")
done <<< "$filtered_versions"

lastVersion="7.6.2"
rebaseNeeded=false

for version in "${versions[@]}"; do

  if [ -n "$(git branch --list "${version}")" ] || [ -n "$(git branch --list --remote "origin/${version}")" ];
  then
    echo "${version} already generated."
    git checkout "${version}"
    if [ ${rebaseNeeded} = true ]
    then
      git rebase --onto "${lastVersion}" HEAD~ "${version}" -X theirs
      diffStat=$(git --no-pager diff HEAD~ --shortstat)
      git push origin "${version}" -f
      diffUrl="[${lastVersion}...${version}](https://github.com/danymarques/nx-cli-diff/compare/${lastVersion}...${version})"
      git checkout main
      sed -i.bak -e "/^${version}|/ d" README.md && rm README.md.bak
      sed -i.bak -e 's/----|----|----/----|----|----\
NEWLINE/g' README.md && rm README.md.bak
      sed -i.bak -e "s@NEWLINE@${version}|${diffUrl}|${diffStat}@" README.md && rm README.md.bak
      git commit -a --amend --no-edit
      git checkout "${version}"
    fi
    lastVersion=${version}
    continue
  fi

  echo "Generate ${version}"
  rebaseNeeded=true
  git checkout -b "${version}"
  rm -rf org
  npx --yes create-nx-workspace@20.0.0 --name=org --preset=angular-monorepo --appName=frontend --bundler=esbuild --style=scss --no-ssr --e2eTestRunner=playwright --nxCloud=skip
  npx nx g @nx/angular:library --directory=libs/my-lib --publishable=true --importPath=@org/my-lib --no-interactive
  npx nx add @nx/nest
  npx nx g @nx/nest:app apps/backend --frontendProject frontend
  git add org
  git commit -am "chore: version ${version}"
  diffStat=$(git --no-pager diff HEAD~ --shortstat)
  git push origin "${version}" -f
  git checkout main
  diffUrl="[${lastVersion}...${version}](https://github.com/cexbrayat/angular-cli-diff/compare/${lastVersion}...${version})"
  # insert a row in the version table of the README
  sed -i.bak "/^${version}|/ d" README.md && rm README.md.bak
  sed -i.bak 's/----|----|----/----|----|----\
NEWLINE/g' README.md && rm README.md.bak
  sed -i.bak "s@NEWLINE@${version}|${diffUrl}|${diffStat}@" README.md && rm README.md.bak
  # commit
  git commit -a --amend --no-edit
  git checkout "${version}"
  lastVersion=${version}

done

git checkout main
git push origin main -f
