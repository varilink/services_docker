# ------------------------------------------------------------------------------
# build/hosts/docker-entrypoint.sh
# ------------------------------------------------------------------------------

# This is the entrypoint script for the Docker Compose "hosts" service. It
# generates the Docker Compose commands to bring up the Docker Compose services
# that simulate the hosts for an environment. It will limit those hosts to those
# required by a list of composite services if such a list is passed to it.

# ------------------------------------------------------------------------------

# /usr/src/services.sh is mapped to the services.sh provided for the current
# environment, which is one of "live", "to-be" or "distributed". It sets MYENV
# to the name of the current environment and provides the services function -
# see the next comment.
source /usr/src/services-to-hosts.sh

# Run the services function provided by /usr/src/services.sh, passing it the
# list of required composite services. An empty list translates to all composite
# service. This function sets the services variable to the list of Docker
# Compose services that the composite services map to in this environment.
services-to-hosts $@

# Teardown first, so stop and remove containers and remove volumes that are
# within the scope of the required composite services.

cat << EOF
docker-compose --env-file envs/$MYENV/.env stop $hosts
docker-compose --env-file envs/$MYENV/.env rm --force $hosts
EOF

if [ $# -eq 0 ] || [ `echo "$@" | tr ' ' '\n' | grep backup` ]
then

  # The backup composite services is included with the scope.

  if [[ $MYENV == 'live' || $MYENV == 'to-be' ]]
  then

    # The backup_director and backup_storage roles share the same host and
    # thus the same bacula-home volume.

    echo 'docker volume rm services_bacula-home'

  elif [[ $MYENV == 'distributed' ]]
  then

    # The backup_director and backup_storage roles are on separate hosts, each
    # with its own volume mapped to the bacula home directory.
    echo 'docker volume rm services_dir-bacula-home services_sd-bacula-home'

  else

    exit 1

  fi

fi

# Bring up the service containers for this environment and the required Docker
# Compose services.
echo "docker-compose --env-file envs/$MYENV/.env up $hosts"