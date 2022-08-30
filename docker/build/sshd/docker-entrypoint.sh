#!/usr/bin/env bash

# Docker entrypoint script that is common to all the Docker Compose services (as
# opposed to the clients) used in this repository, whether they are brought up
# in "for deploy" or "for test" mode.

set -e # return immediately on a non-zero status

if [[ $# -eq 0 ]]
then

  # No command line parameter was provided. This is the case when the containers
  # are brought up "for deploy" mode. The only service we need within the
  # containers at this point is SSH, so bring that up in the foreground.

  exec /usr/sbin/sshd -D

else

  # A command line parameter was provided. This is the case when the containers
  # are brought up in "for test" mode. The command line parameter that is
  # provided dictates the service specific startup that is required for the
  # container.

  # Run the bacula file daemon in the background for all services, since all
  # service hosts are backed up. Since we're in a container environment, systemd
  # will not have created /run/bacula so we must create that first. Note that
  # the bacula file daemon is cofigured to send its messages via the bacula
  # director.
  /etc/init.d/bacula-fd start

  # Run the SSH daemon in the background so that Anisible can still connect.
  /etc/init.d/ssh start

  # Run the process/processes within the container that are required according
  # to the command that has been passed.
  if [[ $1 == "backup" ]]
  then

    # This container must combine the bacula director and bacula storage daemon
    # since the Dropbox integration dictates that they must be co-hosted:
    # https://github.com/varilink/libraries-ansible/issues/2
    # Note that the bacula director and the bacula storage daemon both rely on
    # /run/bacula having been created above.

    # Run the bacula storage daemon in the background. Note that it's configured
    # to send its messages via the bacula director.
    /etc/init.d/bacula-sd start

    # Make the MySQL tables for the bacula catalogue
    /usr/share/bacula-director/make_mysql_tables                               \
      --host=database-internal                                                 \
      --user=bacula                                                            \
      --password=bacula                                                        \
      bacula

    # Replace the current shell process with the bacula director in the
    # foreground.
    exec gosu bacula bacula-dir -f

  elif [[ $1 == "caldav" ]]
  then

    # Replace the current shell process with radicale in the foreground.
    exec radicale -f

  elif [[ $1 == "database" ]]
  then

    # Replace the current shell process with mysqld_safe in the foreground.
    exec mysqld_safe

  elif [[ $1 == "dns" ]]
  then

    # Replace the current shell process with dnsmasq in the foreground.
    exec dnsmasq --no-daemon

  elif [[ $1 == "dynamic-dns" ]]
  then

    # The Dynamic DNS script uses both the cron and rsyslogd daemons, so we run
    # both those daemons in the background and follow the syslog as the means to
    # associate meaningful sysout with the container.

    /etc/init.d/rsyslog start # start the syslog daemon
    /etc/init.d/cron start # start the cron daemon
    exec tail -f /var/log/syslog # tail syslog to the Docker sysout

  elif [[ $1 == "mail-certificates" ]]
  then

    touch /var/log/rsync # Make sure that /var/log/rsync exists
    exec tail -f /var/log/rsync # tail rsync log to the Docker sysout

  elif [[ $1 == "mail-external" ]]
  then

    # Start rsyslog so that Dovecot log output can be written to syslog
    /etc/init.d/rsyslog start
    /etc/init.d/dovecot start
    exec exim4 -bd -d

  elif [[ $1 == 'mail-internal' ]]
  then

    #mkdir --mode=0700 /var/run/fetchmail
    #chown fetchmail:nogroup /var/run/fetchmail
    /etc/init.d/dovecot start
    /etc/init.d/fetchmail start
    exec exim4 -bd -v

  elif [[ $1 == 'mail-other' ]]
  then

    exec exim4 -bd -v

  elif [[ $1 == "reverse-proxy" ]]
  then

    # We only need a single, nginx worker process for client testing
    sed -i 's/worker_processes auto;/worker_processes 1;/' /etc/nginx/nginx.conf
    # Replace the shell with nginx in the foreground
    exec nginx -g "daemon off;"

  elif [[ $1 == "wordpress" ]]
  then

    # TODO: Limit the number of apache2 processes
    source /etc/apache2/envvars
    # Repace the shell with apache2 in the foreground
    exec apache2 -D FOREGROUND

  elif [[ $1 == "wordpress-stack" ]]
  then

    /etc/init.d/mysql start
    # TODO: Limit the number of apache2 processes
    /etc/init.d/apache2 start
    sed -i 's/worker_processes auto;/worker_processes 1;/' /etc/nginx/nginx.conf
    # Run nginx in the background as a daemon
    /etc/init.d/nginx start
    exec tail -f /var/log/mysql/* /var/log/apache2/* /var/log/nginx/*
  fi

fi
