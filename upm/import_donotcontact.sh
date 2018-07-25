#!/usr/bin/env bash

IFS=,

if [ -z "$1" ]
then
    echo "error: Please provide a csv file" >&2
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "error: File not found!" >&2
fi

cat <<-EOF | mysql -u${DB_USER} -p${DB_PASSWD} -h${DB_HOST} -P${DB_PORT} ${DB_NAME}
DROP TABLE IF EXISTS temporary_dnc;
CREATE TABLE temporary_dnc (
    email VARCHAR(255) NOT NULL,
    lead_id INT(11) NULL
);
select * from temporary_dnc;
EOF

while read email
      do
        echo "INSERT INTO temporary_dnc (email) VALUES ('$email');"

done < "$1" | mysql -u${DB_USER} -p${DB_PASSWD} -h${DB_HOST} -P${DB_PORT} ${DB_NAME};

cat <<-EOF | mysql -u${DB_USER} -p${DB_PASSWD} -h${DB_HOST} -P${DB_PORT} ${DB_NAME}
update temporary_dnc set email = TRIM(REPLACE(REPLACE(email, CHAR(10), ''), CHAR(13), ''));
update temporary_dnc t inner join leads l on t.email = l.email set t.lead_id = l.id;
EOF

count=$(mysql -u${DB_USER} -p${DB_PASSWD} -h${DB_HOST} -P${DB_PORT} -sN ${DB_NAME} -e "select count(*) from temporary_dnc where lead_id is not NULL;")

echo "Found ${count} leads that matches the imported file";

cat <<-EOF | mysql -u${DB_USER} -p${DB_PASSWD} -h${DB_HOST} -P${DB_PORT} ${DB_NAME}
insert into lead_donotcontact (lead_id, date_added, reason, channel, channel_id, comments)
    select lead_id, NOW(), 1, 'email', NULL, 'Please do not contact, import_donotcontact.sh'
    from temporary_dnc
    where lead_id is not NULL;
DROP table temporary_dnc;
EOF
