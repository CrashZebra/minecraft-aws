#!/bin/sh
# MINECRAFT Autobackup By Justin Smith
#   http://www.minecraftforum.net/viewtopic.php?f=10&t=36066
# Modified by Max Malm to support save-on / save-off while doing backup and auto-scp to remote host
#	https://github.com/benjick/Minecraft-Autobackup

#Variables

# DateTime stamp format that is used in the tar file names.
STAMP=`date +%Y-%m-%d_%H%M%S`

# The screen session name, this is so the script knows where to send the save-all command (for autosave)
SCREENNAME="minecraft"

# Whether the script should tell your server to save before backup (requires the server to be running in a screen $
AUTOSAVE=1

# Notify the server when a backup is completed.
NOTIFY=1

# Backups DIR name (NOT FILE PATH)
BACKUPDIR="backups"

# MineCraft server properties file name
PROPFILE="server.properties"

# Enable SCP to remote host
SCP=0

# SCP username
SCPUSERNAME="username"

# SCP hostname
SCPHOST="example.com"

# SCP port
SCPPORT=22

# SCP path (create this dir at the remote path)
SCPPATH="/home/username/backup/minecraft"

# Enable/Disable Logging (This will just echo each stage the script reaches, for debugging purposes)
LOGIT=1

# *-------------------------* SCRIPT *-------------------------*
# Set todays backup dir

if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Starting Justins AutoBackup Script.."
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Working in directory: $PWD."
fi

if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Checking if backup folders exist, if not then create them."
fi

if [ -d $BACKUPDIR ]
then
   echo -n < /dev/null
else
   mkdir "$BACKUPDIR"

   if [ $LOGIT -eq 1 ]
   then
      echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Created Folder: $BACKUPDIR"
   fi

fi

# --Check for dependencies--

#Is this system Linux?
#LOL just kidding, at least it better be...

#Get level-name
if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Fetching Level Name.."
fi

while read line
do
   VARI=`echo $line | cut -d= -f1`
   if [ "$VARI" == "level-name" ]
   then
      WORLD=`echo $line | cut -d= -f2`
   fi
done < "$PROPFILE"

if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Level-Name is $WORLD"
fi

BFILE="$WORLD.$STAMP.tar.gz"
CMD="tar -czf $BACKUPDIR/$BFILE $WORLD"

if [ $LOGIT -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Packing and compressing folder: $WORLD to tar file: $BACKUPDIR/$BFILE"
fi

if [ $NOTIFY -eq 1 ]
then
   echo "say Backing up world: \'$WORLD\'" | /usr/local/bin/rcon-cli --host $RCON_HOST --port $RCON_PORT --password $RCON_PASSWORD
fi


echo "save-off" | /usr/local/bin/rcon-cli --host $RCON_HOST --port $RCON_PORT --password $RCON_PASSWORD

#Create timedated backup and create the backup directory if need.
if [ $AUTOSAVE -eq 1 ]
then
   if [ $NOTIFY -eq 1 ]
   then
      echo "say Forcing save..." | /usr/local/bin/rcon-cli --host $RCON_HOST --port $RCON_PORT --password $RCON_PASSWORD
   fi
   #Send save-all to the console
   echo "save-all" | /usr/local/bin/rcon-cli --host $RCON_HOST --port $RCON_PORT --password $RCON_PASSWORD
   sleep 2
fi

if [ $NOTIFY -eq 1 ]
then
   echo "say Packing and compressing world..." | /usr/local/bin/rcon-cli --host $RCON_HOST --port $RCON_PORT --password $RCON_PASSWORD
fi

# Run backup command
$CMD
echo "save-on" | /usr/local/bin/rcon-cli --host $RCON_HOST --port $RCON_PORT --password $RCON_PASSWORD

# Transfer files via SCP to remote host
if [ $SCP -eq 1 ]
then
   echo "$(date +"%G-%m-%d %H:%M:%S") [LOG] Sending files to remote host via SCP"
   scp -P $SCPPORT $BACKUPDIR/$BFILE $SCPUSERNAME@$SCPHOST:$SCPPATH
fi

if [ $NOTIFY -eq 1 ]
then
   # Tell server the backup was completed.
   echo "say Backup completed." | /usr/local/bin/rcon-cli --host $RCON_HOST --port $RCON_PORT --password $RCON_PASSWORD
fi

# Rotate backups
/usr/bin/rotate-backups -H 24 -d 7 -w 8 -m 12 -y always $BACKUPDIR
