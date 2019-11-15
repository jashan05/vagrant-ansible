# Username to access the PostgreSQL server e.g. dbuser
USERNAME=awx

# Password
# create a file $HOME/.pgpass containing a line like this
#   hostname:*:*:dbuser:dbpass
# replace hostname with the value of DBHOST and postgres with
# the value of USERNAME

# Host name (or IP address) of PostgreSQL server e.g localhost
DBHOST=localhost

# List of DBNAMES for Daily/Weekly Backup e.g. "DB1 DB2 DB3"
DBNAMES="all"

# Backup directory location e.g /backups
BACKUPDIR="/var/lib/pgsql/9.6/backups/"

# Mail setup
# What would you like to be mailed to you?
# - log   : send only log file
# - files : send log file and sql files as attachments (see docs)
# - stdout : will simply output the log to the screen if run manually.
#MAILCONTENT="log"

# Set the maximum allowed email size in k. (4000 = approx 5MB email [see docs])
MAXATTSIZE="4000"

# Email Address to send mail to? (user@domain.com)
MAILADDR="jashandeep.sidhu05@gmail.com"

# List of DBBNAMES for Monthly Backups.
MDBNAMES="template1 $DBNAMES"

# List of DBNAMES to EXLUCDE if DBNAMES are set to all (must be in " quotes)
DBEXCLUDE=""

# Include CREATE DATABASE in backup?
CREATE_DATABASE=yes

# Separate backup directory and file for each DB? (yes or no)
SEPDIR=yes

# Which day do you want weekly backups? (1 to 7 where 1 is Monday)
DOWEEKLY=6

# Choose Compression type. (gzip or bzip2)
COMP=gzip

# Command to run before backups (uncomment to use)
#PREBACKUP="/etc/pgsql-backup-pre"

# Command run after backups (uncomment to use)
#POSTBACKUP="bash /home/backups/scripts/ftp_pgsql



#########################################################
########### Script Starts from here #####################
#########################################################

PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/postgres/bin:/usr/local/pgsql/bin
DATE=`date +%Y-%m-%d`				# Datestamp e.g 2002-09-21
DOW=`date +%A`					# Day of the week e.g. Monday
DNOW=`date +%u`					# Day number of the week 1 to 7 where 1 represents Monday
DOM=`date +%d`					# Date of the Month e.g. 27
M=`date +%B`					# Month e.g January
W=`date +%V`					# Week Number e.g 37
VER=1.0						# Version Number
LOGFILE=$BACKUPDIR/$DBHOST-`date +%N`.log	# Logfile Name
OPT=""						# OPT string for use with mysqldump ( see man mysqldump )
BACKUPFILES=""					# thh: added for later mailing

# Create required directories
if [ ! -e "$BACKUPDIR" ]		# Check Backup Directory exists.
	then
	mkdir -p "$BACKUPDIR"
fi

if [ ! -e "$BACKUPDIR/daily" ]		# Check Daily Directory exists.
	then
	mkdir -p "$BACKUPDIR/daily"
fi

if [ ! -e "$BACKUPDIR/weekly" ]		# Check Weekly Directory exists.
	then
	mkdir -p "$BACKUPDIR/weekly"
fi

if [ ! -e "$BACKUPDIR/monthly" ]	# Check Monthly Directory exists.
	then
	mkdir -p "$BACKUPDIR/monthly"
fi


# IO redirection for logging.
touch $LOGFILE
exec 6>&1           # Link file descriptor #6 with stdout.
                    # Saves stdout.
exec > $LOGFILE     # stdout replaced with file $LOGFILE.


# Functions

# Database dump function
dbdump () {
pg_dumpall --username=$USERNAME $HOST $OPT $1 > $2
return 0
}

# Compression function
SUFFIX=""
compression () {
if [ "$COMP" = "gzip" ]; then
	gzip -f "$1"
	echo
	echo Backup Information for "$1"
	gzip -l "$1.gz"
	SUFFIX=".gz"
elif [ "$COMP" = "bzip2" ]; then
	echo Compression information for "$1.bz2"
	bzip2 -f -v $1 2>&1
	SUFFIX=".bz2"
else
	echo "No compression option set, check advanced settings"
fi
return 0
}


# Run command before we begin
if [ "$PREBACKUP" ]
	then
	echo ======================================================================
	echo "Prebackup command output."
	echo
	eval $PREBACKUP
	echo
	echo ======================================================================
	echo
fi


if [ "$SEPDIR" = "yes" ]; then # Check if CREATE DATABSE should be included in Dump
	if [ "$CREATE_DATABASE" = "no" ]; then
		OPT="$OPT"
	else
		OPT="$OPT --create"
	fi
else
	OPT="$OPT"
fi

# Hostname for LOG information
if [ "$DBHOST" = "localhost" ]; then
	DBHOST="`hostname -f`"
	HOST=""
else
	HOST="-h $DBHOST"
fi

# If backing up all DBs on the server
if [ "$DBNAMES" = "all" ]; then
	DBNAMES="`psql -U $USERNAME $HOST -l -A -F: | sed -ne "/:/ { /Name:Owner/d; /template0/d; s/:.*$//; p }"`"

	# If DBs are excluded
	for exclude in $DBEXCLUDE
	do
		DBNAMES=`echo $DBNAMES | sed "s/\b$exclude\b//g"`
	done

        MDBNAMES=$DBNAMES
fi

echo ======================================================================
echo AutoPostgreSQLBackup VER $VER
echo
echo Backup of Database Server - $DBHOST
echo ======================================================================

# Test is seperate DB backups are required
if [ "$SEPDIR" = "yes" ]; then
echo Backup Start Time `date`
echo ======================================================================
	# Monthly Full Backup of all Databases
	if [ $DOM = "01" ]; then
		for MDB in $MDBNAMES
		do

			 # Prepare $DB for using
		        MDB="`echo $MDB | sed 's/%/ /g'`"

			if [ ! -e "$BACKUPDIR/monthly/$MDB" ]		# Check Monthly DB Directory exists.
			then
				mkdir -p "$BACKUPDIR/monthly/$MDB"
			fi
			echo Monthly Backup of $MDB...
				dbdump "$MDB" "$BACKUPDIR/monthly/$MDB/${MDB}_$DATE.$M.$MDB.sql"
				compression "$BACKUPDIR/monthly/$MDB/${MDB}_$DATE.$M.$MDB.sql"
				BACKUPFILES="$BACKUPFILES $BACKUPDIR/monthly/$MDB/${MDB}_$DATE.$M.$MDB.sql$SUFFIX"
			echo ----------------------------------------------------------------------
		done
	fi

	for DB in $DBNAMES
	do
	# Prepare $DB for using
	DB="`echo $DB | sed 's/%/ /g'`"

	# Create Separate directory for each DB
	if [ ! -e "$BACKUPDIR/daily/$DB" ]		# Check Daily DB Directory exists.
		then
		mkdir -p "$BACKUPDIR/daily/$DB"
	fi

	if [ ! -e "$BACKUPDIR/weekly/$DB" ]		# Check Weekly DB Directory exists.
		then
		mkdir -p "$BACKUPDIR/weekly/$DB"
	fi

	# Weekly Backup
	if [ $DNOW = $DOWEEKLY ]; then
		echo Weekly Backup of Database \( $DB \)
		echo Rotating 5 weeks Backups...
			if [ "$W" -le 05 ];then
				REMW=`expr 48 + $W`
			elif [ "$W" -lt 15 ];then
				REMW=0`expr $W - 5`
			else
				REMW=`expr $W - 5`
			fi
		eval rm -fv "$BACKUPDIR/weekly/$DB/week.$REMW.*"
		echo
			dbdump "$DB" "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$DATE.sql"
			compression "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$DATE.sql"
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/weekly/$DB/${DB}_week.$W.$DATE.sql$SUFFIX"
		echo ----------------------------------------------------------------------

	# Daily Backup
	else
		echo Daily Backup of Database \( $DB \)
		echo Rotating last weeks Backup...
		eval rm -fv "$BACKUPDIR/daily/$DB/*.$DOW.sql.*"
		echo
			dbdump "$DB" "$BACKUPDIR/daily/$DB/${DB}_$DATE.$DOW.sql"
			compression "$BACKUPDIR/daily/$DB/${DB}_$DATE.$DOW.sql"
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/$DB/${DB}_$DATE.$DOW.sql$SUFFIX"
		echo ----------------------------------------------------------------------
	fi
	done
echo Backup End `date`
echo ======================================================================


else # One backup file for all DBs
echo Backup Start `date`
echo ======================================================================
	# Monthly Full Backup of all Databases
	if [ $DOM = "01" ]; then
		echo Monthly full Backup of \( $MDBNAMES \)...
			dbdump "$MDBNAMES" "$BACKUPDIR/monthly/$DATE.$M.all-databases.sql"
			compression "$BACKUPDIR/monthly/$DATE.$M.all-databases.sql"
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/monthly/$DATE.$M.all-databases.sql$SUFFIX"
		echo ----------------------------------------------------------------------
	fi

	# Weekly Backup
	if [ $DNOW = $DOWEEKLY ]; then
		echo Weekly Backup of Databases \( $DBNAMES \)
		echo
		echo Rotating 5 weeks Backups...
			if [ "$W" -le 05 ];then
				REMW=`expr 48 + $W`
			elif [ "$W" -lt 15 ];then
				REMW=0`expr $W - 5`
			else
				REMW=`expr $W - 5`
			fi
		eval rm -fv "$BACKUPDIR/weekly/week.$REMW.*"
		echo
			dbdump "$DBNAMES" "$BACKUPDIR/weekly/week.$W.$DATE.sql"
			compression "$BACKUPDIR/weekly/week.$W.$DATE.sql"
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/weekly/week.$W.$DATE.sql$SUFFIX"
		echo ----------------------------------------------------------------------

	# Daily Backup
	else
		echo Daily Backup of Databases \( $DBNAMES \)
		echo
		echo Rotating last weeks Backup...
		eval rm -fv "$BACKUPDIR/daily/*.$DOW.sql.*"
		echo
			dbdump "$DBNAMES" "$BACKUPDIR/daily/$DATE.$DOW.sql"
			compression "$BACKUPDIR/daily/$DATE.$DOW.sql"
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/$DATE.$DOW.sql$SUFFIX"
		echo ----------------------------------------------------------------------
	fi
echo Backup End Time `date`
echo ======================================================================
fi
echo Total disk space used for backup storage..
echo Size - Location
echo `du -hs "$BACKUPDIR"`
echo


# Run command when we're done
if [ "$POSTBACKUP" ]
	then
	echo ======================================================================
	echo "Postbackup command output."
	echo
	eval $POSTBACKUP
	echo
	echo ======================================================================
fi

#Clean up IO redirection
exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.

if [ "$MAILCONTENT" = "files" ]
then
	#Get backup size
	ATTSIZE=`du -c $BACKUPFILES | grep "[[:digit:][:space:]]total$" |sed s/\s*total//`
	if [ $MAXATTSIZE -ge $ATTSIZE ]
	then
		BACKUPFILES=`echo "$BACKUPFILES" | sed -e "s# # -a #g"`	#enable multiple attachments
		mutt -s "PostgreSQL Backup Log and SQL Files for $DBHOST - $DATE" $BACKUPFILES $MAILADDR < $LOGFILE		#send via mutt
	else
		cat "$LOGFILE" | mail -s "WARNING! - PostgreSQL Backup exceeds set maximum attachment size on $HOST - $DATE" $MAILADDR
	fi
elif [ "$MAILCONTENT" = "log" ]
then
	cat "$LOGFILE" | mail -s "PostgreSQL Backup Log for $DBHOST - $DATE" $MAILADDR
else
	cat "$LOGFILE"
fi

# Clean up Logfile
eval rm -f "$LOGFILE"

exit 0
