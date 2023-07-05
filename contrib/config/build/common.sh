version_file="/version"
version_log_file="/config/version.log"
update_dir="/update"

long_version=$(grep tag "$version_file" | cut -d " " -f2) # tag: v2.1.0-rc1 -> v2.1.0-rc1
version=$(echo "$long_version" | cut -d "-" -f1) # v2.1.0-rc1 -> v2.1.0

if [ "x$version" != "x" ]; then
  if [ -f $version_log_file ]; then
    curr_version=$(tail -1 $version_log_file | cut -d " " -f1)
  else
    curr_version="N/A"
  fi
fi