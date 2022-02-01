#!/bin/bash
# e is for exiting the script automatically if a command fails, u is for exiting if a variable is not set
# x would be for showing the commands before they are executed
set -eu
shopt -s globstar

# FUNCTIONS
# Function for setting up git env in the docker container (copied from https://github.com/stefanzweifel/git-auto-commit-action/blob/master/entrypoint.sh)
_git_setup ( ) {
    cat <<- EOF > $HOME/.netrc
      machine github.com
      login $GITHUB_ACTOR
      password $INPUT_GITHUB_TOKEN
      machine api.github.com
      login $GITHUB_ACTOR
      password $INPUT_GITHUB_TOKEN
EOF
    chmod 600 $HOME/.netrc

    git config --global user.email "actions@github.com"
    git config --global user.name "GitHub Action"
}

# Checks if any files are changed
_git_changed() {
    [[ -n "$(git status -s)" ]]
}

_git_changes() {
    git diff
}

(
# PROGRAM
# Changing to the directory
cd "$GITHUB_ACTION_PATH"

echo "Installing prettier..."

case $INPUT_WORKING_DIRECTORY in
    false)
        ;;
    *)
        cd $INPUT_WORKING_DIRECTORY
        ;;
esac

case $INPUT_PRETTIER_VERSION in
    false)
        npm install --silent prettier
        ;;
    *)
        npm install --silent prettier@$INPUT_PRETTIER_VERSION
        ;;
esac

# Install plugins
if [ -n "$INPUT_PRETTIER_PLUGINS" ]; then
    for plugin in $INPUT_PRETTIER_PLUGINS; do
        echo "Checking plugin: $plugin"
        # check regex against @prettier/xyz
        if ! echo "$plugin" | grep -Eq '(@prettier\/plugin-|(@[a-z\-]+\/)?prettier-plugin-){1}([a-z\-]+)'; then
            echo "$plugin does not seem to be a valid @prettier/plugin-x plugin. Exiting."
            exit 1
        fi
    done
    npm install --silent $INPUT_PRETTIER_PLUGINS
fi
)

echo Setting git up
_git_setup
echo Finished Git setup
MERGE_HEAD=$(git merge-base origin/master HEAD)
echo MERGE_HEAD=${MERGE_HEAD}
changed_files=$(git --no-pager diff --name-only --diff-filter=d ${MERGE_HEAD}..HEAD)
echo "Files:"

if [[ -z ${changed_files} ]]; then
	echo "no files were changed"
	exit 0
fi

for i in ${changed_files}; do
	echo - $i
done

echo "done"

# Filter files to be with svelte only
filtered_changed_files=$(git --no-pager diff --name-only --diff-filter=d ${MERGE_HEAD}..HEAD | grep -E '\.js$|\.svelte$')
echo "Filtered Files:"
if [[ -z ${filtered_changed_files} ]]; then
	echo "no filtered files were changed"
	exit 0
fi

for i in ${filtered_changed_files}; do
	echo - $i
done


PRETTIER_RESULT=0
echo "Prettifying files..."
prettier --check ${filtered_changed_files}
  || { PRETTIER_RESULT=$?; echo "Problem running prettier with $INPUT_PRETTIER_OPTIONS"; exit 1; }
