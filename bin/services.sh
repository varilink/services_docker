# Provides the function services that translates composite services into Docker
# Compose services. This function can be passed zero or more composite services
# from this list:
# - backup
# - calendar
# - dns
# - dynamic_dns
# - mail
# - web
# It sets a variable "services" to a sorted list of either all the Docker
# Compose services (if no composite services were passed) or all the Docker
# Compose services associated with the passed composite services.

function services {

  # Docker Compose services that combine to deliver the backup composite
  # service.
  backup='backup-director database-internal dns-external dns-internal'
  # Docker Compose services that combine to deliver the calendar composite
  # service.
  calendar='caldav dns-external dns-internal'
  # Docker Compose services that combine to deliver the dns composite service.
  dns='dns-external dns-internal'
  # Docker Compose services that combine to deliver the dynamic_dns composite
  # service.
  dynamic_dns='dns-external dns-internal dynamic-dns mail-internal'
  # Docker Compose services that combine to deliver the mail composite service.
  mail='dns-external dns-internal'
  mail="$mail mail-certificates mail-external mail-internal mail-other"
  # Docker Compose services that combine to deliver the web composite service.
  web='database-external reverse-proxy-external wordpress-external'
  web="$web wordpress-stack dns-external dns-internal"

  if [[ $# -eq 0 ]]
  then

    # No parameters were provided so return ALL Docker Compose services.
    services="$backup $calendar $dns $dynamic_dns $mail $web"

  else

    # One or more composite services were provided so loop through them.
    for service in $@
    do

      if [[ 'backup calendar dns dynamic_dns mail web' =~ ( |^)$service( |$) ]]
      then

        # The composite service is one of backup, calendar, dns, dynamic_dns,
        # mail or web. Append the multiple Docker Compose services that combine
        # to deliver that composite service to the output.
        services="$services ${!service}"

      else

        # We were passed a composite service name that we do not recognise, so
        # exit with an error response.
        exit 1

      fi

    done

  fi

  # Remove any duplicates from the list of Docker Compose services and sort them
  # alphabetically.
  services=`echo $services | xargs -n1 | sort | uniq`

}
