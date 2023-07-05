#! /bin/sh

script_home=$(dirname "$(realpath "$0")")
. "${script_home}/common.sh"

cmd="/usr/local/bin/relayer start -c /config/relayer.yaml"

if [ "x$curr_version" != "x" ] && [ "$long_version" != "$curr_version" ]; then
  set -e
  echo "updating to version $long_version from $curr_version"
  pre_update_file="$update_dir/$version/pre.sh"
  if [ -f "$pre_update_file" ]; then
    echo "running update pre-processor"
    ($pre_update_file)
  fi

  echo "starting relayer: [$cmd]"
  $cmd &

  post_update_file="$update_dir/$version/post.sh"
  if [ -f "$post_update_file" ]; then
    echo "running update post-processor"
    ($post_update_file)
  fi

  echo "successfully updated to $long_version"
  echo "$long_version $(date)" >> $version_log_file
  set +e
else
  echo "starting relayer: [$cmd]"
  $cmd &
fi

wait
