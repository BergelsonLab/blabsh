#!/usr/bin/env bash

# get four sides of a merge
git_extract-merge-files() {
    local commit=$1
    local path=$2
    git show $(git merge-base $commit^1 $commit^2):$path > $path.BASE
    git show $commit^1:$path > $path.OURS
    git show $commit^2:$path > $path.THEIRS
    git show $commit:$path > $path.MERGED
}

# get three sides of a merge conflict
git_extract-conflict-files() {
   local path=$1
   git show $(git merge-base HEAD MERGE_HEAD):$path > $path.BASE
   git show HEAD:$path > $path.OURS
   git show MERGE_HEAD:$path > $path.THEIRS
}

git_recreate-merge() {
   local commit=$1
   local path=$2
   git branch $path.OURS $commit^1
   git branch $path.THEIRS $commit^2
   git switch $path.OURS
   git merge $path.THEIRS -m "temp: merge troubleshooting"
}
