#!/bin/bash

set -euo pipefail

if ! command -v jq &> /dev/null; then
  echo "Erreur : 'jq' est requis mais non installé."
  exit 1
fi

versions_json=$(npm view create-nx-workspace versions --json)
versions=()

while IFS= read -r version; do
  if [[ "$version" =~ (canary|beta|pr|rc|alpha) ]]; then
    echo "Ignored prerelease version : $version"
    continue
  fi
  versions+=("$version")
done < <(echo "$versions_json" | jq -r '.[]')

lastVersion="20.0.0"
rebaseNeeded=false

for version in "${versions[@]}"; do

  if [ `git branch --list ${version}` ] || [ `git branch --list --remote origin/${version}` ]
  then
    echo "${version} already generated."
    git checkout ${version}
    if [ ${rebaseNeeded} = true ]
    then
      git rebase --onto ${lastVersion} HEAD~ ${version} -X theirs
      diffStat=`git --no-pager diff HEAD~ --shortstat`
      git push origin ${version} -f
      diffUrl="[${lastVersion}...${version}](https://github.com/danymarques/nx-cli-diff/compare/${lastVersion}...${version})"
      git checkout main
      # rewrite stats in README after rebase
      sed -i.bak -e "/^${version}|/ d" README.md && rm README.md.bak
      sed -i.bak -e 's/----|----|----/----|----|----\
NEWLINE/g' README.md && rm README.md.bak
      sed -i.bak -e "s@NEWLINE@${version}|${diffUrl}|${diffStat}@" README.md && rm README.md.bak
      git commit -a --amend --no-edit
      git checkout ${version}
    fi
    lastVersion=${version}
    continue
  fi

  echo "Generate ${version}"
  rebaseNeeded=true
  git checkout -b ${version}
  rm -rf org
  npx npx create-nx-workspace@${version} --name org --preset angular --workspaceType integrated --appName frontend --bundler esbuild --style scss --ssr no --e2eTestRunner playwright --ci skip --nxCloud no
  npx nx g @nx/angular:library --directory=libs/my-lib --publishable=true --importPath=@org/my-lib --no-interactive
  npx nx add @nx/nest
  npx nx g @nx/nest:app apps/backend --frontendProject frontend
  git add org
  git commit -am "chore: version ${version}"
  diffStat=`git --no-pager diff HEAD~ --shortstat`
  git push origin ${version} -f
  git checkout main
  diffUrl="[${lastVersion}...${version}](https://github.com/cexbrayat/angular-cli-diff/compare/${lastVersion}...${version})"
  # insert a row in the version table of the README
  sed -i.bak "/^${version}|/ d" README.md && rm README.md.bak
  sed -i.bak 's/----|----|----/----|----|----\
NEWLINE/g' README.md && rm README.md.bak
  sed -i.bak "s@NEWLINE@${version}|${diffUrl}|${diffStat}@" README.md && rm README.md.bak
  # commit
  git commit -a --amend --no-edit
  git checkout ${version}
  lastVersion=${version}

done

git checkout main
git push origin main -f