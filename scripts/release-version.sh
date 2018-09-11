#!/bin/bash
#
# Checks to make sure that the version number is consistent across all
# files, then issues the git commands to tag the version.

# A simple function to ask the user if they want to continue.
function ask_keep_going {
    read -ep "Are you sure you want to continue? [y/N] " keep_going
    if [ "$keep_going" != "y" -a "$keep_going" != "Y" ]
    then
	echo "Aborting"
	exit 1
    fi
    echo
}

# Run in repo base directory
cd `dirname $0`/..

echo "Fetching origin..."
git fetch origin
echo

# Extract the version number from UseLATEX.cmake
version_line=`head -n 3 UseLATEX.cmake | tail -n 1`

version=`echo $version_line | sed -n 's/# Version: \([0-9]*\.[0-9]*\.[0-9]*\)/\1/p'`

if [ -z $version ]
then
    echo "Could not extract version number from UseLATEX.cmake."
    echo "The third line should be of the form '# Version: X.X.X'."
    exit 1
fi

echo "Found version $version in UseLATEX.cmake"
echo

echo -n "Checking for $version in UseLATEX.tex..."
if fgrep -q '\newcommand{\UseLATEXVersion}{'$version'}' UseLATEX.tex
then
    echo "OK"
else
    echo "FAIL"
    echo
    echo "Could not find $version in UseLATEX.tex."
    echo "There should be a line in UseLATEX.tex like the following:"
    echo '    \newcommand{\UseLATEXVersion}{'$version'}'
    echo "Add it."
    exit 1
fi

echo -n "Checking for $version in UseLATEX.pdf..."
if pdftotext UseLATEX.pdf - | grep -q 'Version *'$version
then
    echo "OK"
else
    echo "FAIL"
    echo
    echo "Could not find $version in UseLATEX.pdf (using pdftotext)."
    echo "Rebuild the pdf documentation and copy it to the working repo."
    exit 1
fi

git_version_tag="Version$version"
echo -n "Checking for git tag $git_version_tag..."
if git rev-list $git_version_tag.. > /dev/null 2>&1
then
    echo "FAIL"
    echo
    echo "Version tag $git_version_tag already exists in git repository."
    echo "Either change the version in UseLATEX.cmake or remove the version"
    echo "tag (with 'git tag -d $git_version_tag')."
    exit 1
else
    echo "OK"    
fi

echo -n "Checking that the working directory is clean..."
if [ -z "`git status --porcelain`" ]
then
    echo "OK"
else
    echo "FAIL"
    echo
    echo "There are uncommitted changes to your repository. Make sure that the"
    echo "working directory is clean before running this script."
    exit 1
fi

echo -n "Checking that we are on the master branch..."
if [ "`git rev-parse --abbrev-ref HEAD`" = "master" ]
then
    echo "OK"
else
    echo "FAIL"
    echo
    echo "Not currently on the master branch."
    ask_keep_going
fi

echo -n "Checking that we are up to date on master..."
if git merge-base --is-ancestor origin/master HEAD
then
    echo "OK"
else
    echo "FAIL"
    echo
    echo "The local repository does not have the latest version from the"
    echo "central repository. This is OK if you are retroactively tagging"
    echo "a version but might be in error if you are tagging new changes."
    ask_keep_going
fi

echo -n "Checking that master is up to date on origin..."
if git merge-base --is-ancestor HEAD origin/master
then
    echo "OK"
else
    echo "FAIL"
    echo
    echo "Your latest changes do not appear to be in the central repository."
    echo "It is recommended to update the remote repository before tagging"
    echo "a version."
    ask_keep_going
fi

# We are finished with all the checks. Do the tag.
echo -n "Tagging with $git_version_tag..."
if git tag $git_version_tag
then
    echo "OK"
else
    echo "FAIL"
    echo
    echo "Could not tag repository for some reason."
    exit 1
fi

echo
echo "Finished tagging to version $version."
echo "To push the tags to the remote repository, execute"
echo
echo "    git push --tags"
echo
