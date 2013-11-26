#!/bin/bash

# Database
db_user=
db_password=
db_database=

if [ -z "$1" -o -z "$2" ]; then
    echo "import / export [products] OR backup [filename]"
else
    io_dir=$PWD
    io_type="$1"
    io_import="$2"
    io_files="$io_dir""/files/"
    io_backups="$io_dir""/backups/"
    io_export="$io_dir""/export"

    if [ "$io_type" = "import" ]; then
        bu_datetime=$(date +%Y%d%m%H%M%S)
        bu_tables=$(echo | awk -vORS=" " -F ":" '/# backup/ {print $2}' "$io_files""$io_type""_""$io_import"".sql")

        # Create backups directory if not exists
        if [ ! -d "$io_backups" ]; then
            $(mkdir "$io_backups")
        fi

        # Execute Backup
        $(mysqldump -u "$db_user" -p"$db_password" "$db_database" $bu_tables > "$io_backups""$io_import""_""$bu_datetime"".sql")

        echo 'Backup for '"$io_import"' was completed'

        # Execute Import
        $(mysql -u "$db_user" -p"$db_password" "$db_database" < "$io_files""$io_type""_""$io_import"".sql")

        echo 'Data for '"$io_import"' was imported'

        # Reindex
        php -f "$io_dir"/../shell/indexer.php reindexall
    fi

    if [ "$io_type" = "backup" ]; then
        # Execute backup
        $(mysql -u "$db_user" -p"$db_password" "$db_database" < "$io_backups""$io_import")

        echo 'Backup was restored'

        # Reindex
        php -f "$io_dir"/../shell/indexer.php reindexall
    fi

fi
