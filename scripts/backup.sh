#!/bin/bash

##############################################################################
# An rclone backup script by Jared Males (jaredmales@gmail.com)
# 
# Copyright (C) 2018 Jared Males <jaredmales@gmail.com>
#
# This script is licensed under the terms of the MIT license.
# https://opensource.org/licenses/MIT
#
# Runs the 'rclone sync' command.  Designed to be used as a cron job.
#
# 1) Backup Source
#    Edit the SRC variable below to point to the directory you want to backup.
#
# 2) Backup Destination
#    Edit the DEST variable to point to the remote and location (see rclone docs).
# 
# 3) Excluding files and directories
#    Edit the EXCLUDEFILE variable below to point to a file listing files and directories to exclude.
#    See the rclone docs for the format.
#
#    Also, any directory can be excluded by adding an '.rclone-ignore' file to it without editing the exclude file.
#    This file can be empty.  You can edit the name of this file with EXIFPRESENT below.
# 
# 4) You can change the bandwidth limits by editing BWLIMT, which includes a timetable facility.  
#    See rclone docs for more info.
#
# 5) Logs:
#    -- The output of rclone is written to the location specified by LOGFILE.  This is rotated with savelog. 
#       The details of synclog can be edited. 
#    -- The log rotation, and start and stop times of this script, are written to the location specified by CRONLOG.
#       This isn't yet rotated, probably should be based on size.
#   
##############################################################################

#### rclone sync options

SRC=/docker/

#---- Edit this to the desired destination
DESTENCRYPT=DropEncrypt:docker-backup
DEST=backbox:backup
#---- This is the path to a file with a list of exclude rules
#EXCLUDEFILE=$SRC/.rclone/excludes 

#---- Name of exclude file
# NOTE: you need "v1.39-036-g2030dc13β" or later for this to work.
EXIFPRESENT=.rclone-ignore

#---- The bandwidth time table
BWLIMIT="08:00,512 00:00,off"

#---- Don't sync brand new stuff, possible partials, etc.
MINAGE=10m

#---- [B2 Specific] number of transfers to do in parallel.  rclone docs say 32 is recommended for B2.
TRANSFERS=32

#---- Location of sync log [will be rotated with savelog]
LOGFILE=/tmp/.rclone/rclone-sync.log
LOGS='-vv --log-file='$LOGFILE

#---- Location of cron log
CRONLOG=/tmp/.rclone/rclone-cron.log

#---- Location of cron log
CONFIG=/docker/scripts/rclone.conf

###################################################
## Locking Boilerplate from https://gist.github.com/przemoc/571091
## Included under MIT License:
###################################################

## Copyright (C) 2009 Przemyslaw Pawelczyk <przemoc@gmail.com>
##
## This script is licensed under the terms of the MIT license.
## https://opensource.org/licenses/MIT
#
# Lockable script boilerplate

### HEADER ###

LOCKFILE="/tmp/`basename $0`"
LOCKFD=99

# PRIVATE
_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }

# ON START
_prepare_locking

# PUBLIC
exlock_now()        { _lock xn; }  # obtain an exclusive lock immediately or fail
exlock()            { _lock x; }   # obtain an exclusive lock
shlock()            { _lock s; }   # obtain a shared lock
unlock()            { _lock u; }   # drop a lock

###################################################
# End of locking code from Pawelczyk
###################################################


#make a log entry if we exit because locked
exit_on_lock()      { echo $(date -u)' | backup already running.' >> $CRONLOG; exit 1; }


#Now check for lock
exlock_now || exit_on_lock
#We now have the lock.

#Rotate logs.
savelog -n -c 7 $LOGFILE >> $CRONLOG

#Log startup
echo $(date -u)' | starting backup . . .' >> $CRONLOG

#Now do the sync!
echo $(date -u)' | Crating Tar.gz . . .'
tar -zcf /tmp/backup.tar.gz /docker > /dev/null 2>&1 && gpg --yes --pinentry-mode=loopback --passphrase "Vijay@29oct" -c  -o /backup.tar.gz.gpg /tmp/backup.tar.gz
echo $(date -u)' | Uploading to Dropbox . . .'
rclone sync /backup.tar.gz.gpg $DEST --config=$CONFIG --transfers $TRANSFERS --delete-excluded $LOGS --checksum -L
#rclone sync $SRC $DESTENCRYPT --config=$CONFIG --transfers $TRANSFERS --bwlimit "$BWLIMIT" --min-age $MINAGE --delete-excluded $LOGS --checksum -L --create-empty-src-dirs -P

#log success
echo $(date -u)' | completed backup.' >> $CRONLOG

#release the lock
unlock


#exit
