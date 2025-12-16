repo=$(git rev-parse --absolute-git-dir)
name=${repo##*/}

rebuild=0
defref=$(git symbolic-ref HEAD)

while read -r _ _ remote_ref _; do
	if [ "${remote_ref}" = "${defref}" ]; then
		rebuild=1
		break
	fi
done

# Only rebuild if the default ref was pushed
[ ${rebuild} -eq 1 ] || exit 0

# Use full paths to executables or ensure they're in PATH
depp -u "git://repos.aether.ip/${name}" \
 -d "/var/www/repos.aether.ip/${name}" .
