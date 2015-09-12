#! /bin/bash
#0   3  * * *    /root/scripte/Full_Backup.sh >> /var/log/backup_$SERVER.log 2>&1
#################################################################################
##                                                                             ##
##                                Backup Script                                ##
##                                 VII.IX.MMXV                                 ##
##                                                                             ##
#################################################################################
### Variablen
DIR=/home/backups                                                   # Verzwichnis, wo Backup abgelegt wird
CONF=/root/.my.cnf                                                  # MySQL Config-Datei, welche die Zugangsdaten enthält
IGNORE="information_schema|performance_schema|mysql"                # zu ignorierende Datenbanken
SERVER=changeme                                                     # Serverbeschreibung, zBsp Hostname
EMAIL="backup@domain.tld"                                           # Empfänger für die Mailbenachrichtigung
MESSAGE="/tmp/email.txt"                                            # temporäre Datei für den Mailtext
SUBJECT="Dein Backupreport vom `date +%d.%m.%Y`"                    # Betreff der Mailbenachrichtigung
LOGFILE=/var/log/backup_$SERVER.log                                 # Pfad zur Logdatei

YEAR=`date +%Y`                                                     #\
MONTH=`date +%m`                                                    # \
DAY=`date +%d`                                                      #  \
HOURS=`date +%H`                                                    #  -> im Script benutzte Zeit- und Datumsstempel
MINUTES=`date +%M`                                                  #  /
SEC=`date +%s`                                                      # /
WEEKDAY=`date +%a`                                                  #/

backup_file=$DIR/$YEAR-$MONTH-$DAY.$HOURS-$MINUTES.$SERVER.tar.bz2                                # Name des Ordnerbackup
backup_db=$DIR/$YEAR-$MONTH-$DAY.$HOURS-$MINUTES                                                  # Name der Datenbanksicherung(en)
DBS="$(/usr/bin/mysql --defaults-extra-file=$CONF -Bse 'show databases' | /bin/grep -Ev $IGNORE)" # Zu sichernde Datenbanken

### wöchentlich ein Vollbackup erstellen
if [ $WEEKDAY == "Sun" ] || [ $WEEKDAY == "Su" ] || [ $WEEKDAY == "So" ]; then
rm /home/meta
fi

### Backups, älter als 30 Tage, werden gelöscht
find $DIR/* -mtime +30 -exec rm {} \;

echo "------------- Backup am `date +%d.%m.%Y-%H:%M` gestartet ---------------"

### erstelle Datenbanksicherungen
for DB in $DBS; do
    /usr/bin/mysqldump --defaults-extra-file=$CONF --skip-extended-insert --skip-comments $DB | gzip > $backup_db.$DB.sql.gz
done

### -inkrementelle- Hauptsicherung erstellen (nutzt alle Prozessorkerne!)
tar --exclude /pfad/foo/bar -I pbzip2 -cp --listed-incremental=/home/meta /etc /root /usr /var -f $backup_file
echo Backupdauer: $(((`date +%s` - $SEC) / 60)) Minuten
echo ">>>>>>>> ----- Alle Daten erfolgreich gesichert ------ <<<<<<<<<"
echo "----------------- Backup vom `date +%d.%m.%Y` beendet -------------------"

### Email zusammenstellen und versenden
echo "Hallo Admin von $SERVER" > $MESSAGE                                                       # Begrüßung
echo "" >> $MESSAGE
echo "Zusammenfassung deines heutigen Backups:" >> $MESSAGE                                     # Einleitungstext
echo "" >> $MESSAGE
echo - Dauer: $(((`date +%s` - $SEC) / 60)) Minuten >> $MESSAGE                                 # Backupdauer
echo - Größe: `du -h $backup_file | cut -f1` >> $MESSAGE                                        # Größe des Ordnerbackups
echo - freier Speicher: >> $MESSAGE                                                             # freien Speicher zeigen
df -h > /tmp/diskspace.txt ; expand /tmp/diskspace.txt >> $MESSAGE                              # Ausgabe in Datei schreiben und Tabs entfernen (wegen Plaintext Mail)
echo "" >> $MESSAGE
echo Heutiger Ausschnitt aus dem Logfile: >> $MESSAGE                                           # aktuelle Einträge aus Logfile auslesen
sed -n '/'`date +%d.%m.%Y`'/,$p' /var/log/backup_$SERVER.log >> $MESSAGE                        # sucht nach dem Datum und gibt nachfolgende Zeilen aus
echo "" >> $MESSAGE
echo "Liebe Grüße und bis morgen" >> $MESSAGE                                                   # liebe Worte des Abschieds ^^
cat $MESSAGE | mail -a "Content-Type: text/plain; charset=UTF-8" -s "$SUBJECT" "$EMAIL"         # fertige Email verschicken

### aufräumen
rm $MESSAGE
rm /tmp/diskspace.txt
exit 0
