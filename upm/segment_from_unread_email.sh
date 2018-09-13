#!/usr/bin/env bash

if [ -z "$1" ]
then
    echo "error: Please provide the email id" >&2
    exit 1
fi

re='^[0-9]+$'
if ! [[ "$1" =~ $re ]]
then
    echo "error: Provided email id is not an integer" >&2
    exit 1
fi

email_id=$(mysql -u${DB_USER} -p${DB_PASSWD} -h${DB_HOST} -P${DB_PORT} -sN ${DB_NAME} -e "select id from emails where id = $1")

if ((email_id > 0))
then
    echo "";
else
    echo "error: Provided email id does not exist" >&2
    exit 1
fi

mysql -u${DB_USER} -p${DB_PASSWD} -h${DB_HOST} -P${DB_PORT} ${DB_NAME} <<EOF

-- Variable
SET @email_id=${email_id};
SELECT @email_name := name, @email_subject := subject FROM emails where id = @email_id;
SET @segment_name=CONCAT("[RELANCE] ", @email_name);
SET @segment_alias=CONCAT("relance-email-", @email_id, '-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'));
SET @segment_description=CONCAT("Généré le ", DATE_FORMAT(NOW(), '%Y/%m/%d %H:%i:%s'), " sur email <b>#", @email_id, "</b>, « <i>", @email_subject, "</i> »");

-- Create segment, if missing, ignore duplicated ID
insert into lead_lists
  (is_published, date_added, created_by, created_by_user,
  date_modified, modified_by, modified_by_user, checked_out,
  checked_out_by, checked_out_by_user, name, description,
  alias, filters, is_global)
select
  1, NOW(), u.id,
  CONCAT(u.first_name, ' ', u.last_name), NOW(), u.id,
  CONCAT(u.first_name, ' ', u.last_name), NULL, NULL, NULL,
  @segment_name,
  @segment_description,
  @segment_alias, "a:0:{}", 1
from emails e
inner join users u on u.id = 1 and e.id = @email_id;

SET @segment_id=LAST_INSERT_ID();

-- Ajout des contacts
insert into lead_lists_leads
  (leadlist_id, lead_id, date_added, manually_removed,
  manually_added)
select
  s.id, e.lead_id, NOW(), 0, 1
from lead_lists s
inner join email_stats e on e.email_id = @email_id and e.is_read = 0
inner join leads l on l.id = e.lead_id
where s.id = @segment_id;

EOF

if [ $? -eq 0 ]; then
    echo "Segment added with success"
else
    echo "Failed to create segment"
fi