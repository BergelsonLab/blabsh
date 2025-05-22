#!/usr/bin/env bash

# get four sides of a merge
extract_merge_files() {
    local commit=$1
    local path=$2
    git show $(git merge-base $commit^1 $commit^2):$path > $path.BASE
    git show $commit^1:$path > $path.OURS
    git show $commit^2:$path > $path.THEIRS
    git show $commit:$path > $path.MERGED
}

# get three sides of a merge conflict
extract_conflict_files() {
   local path=$1
   git show $(git merge-base HEAD MERGE_HEAD):$path > $path.BASE
   git show HEAD:$path > $path.OURS
   git show MERGE_HEAD:$path > $path.THEIRS
}
