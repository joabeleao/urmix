#!/bin/bash
#
#  Home Sweet Home Backup
#
#  Author: Joabe Nonis Leão - joabe.leao1 at gmail.com
#  Based on: Willy Romao G. Franca (willyr.goncalves at gmail.com)
#  Filename: phoenix_down.sh
#
#  Make backups daily, weekly and monthly of way simple and of easy customization.
#


#
# TOOLS SETTINGS
#
# Tools paths for compatibility
WHICH="/usr/bin/which"
RSYNC="$(${WHICH} rsync)"
GZIP="$(${WHICH} gzip)"
FIND="$(${WHICH} find)"
SSH="$(${WHICH} ssh)"
AWK="$(${WHICH} awk)"

# Tools options
SSH_OPTIONS=" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
RSYNC_OPTIONS="-Cravzp"
TAR_OPTIONS="--warning=no-file-changed --warning=no-file-removed --ignore-failed-read"
DU_OPTIONS="--max-depth=0 -c"
# Minimum percentual for validate size of tar backup
PERCENTUAL_MIN_SIZE="0.09"

#
# VERSION AND FILE CONTROL
#
# Directory settings
BASEDIR=$(dirname $0)
CONF="${BASEDIR}/backup.conf"
BKPDIR="/PHOENIXDOWN"
# Remote storage
SEND=0
BKPDST="/ANOTHERMACHINE ANOTHERMACHINEIP ANOTHERMACHINEPORT ANOTHERMACHINEUSER"
# File settings
BKPFILES="/etc /home /boot/grub"
IGNOREDFILES="/root/bkp /dev /home/*/Downloads /home/*/OwnCloud"
SOCKET_EXCLUDE="/tmp/sockets-to-exclude"
# Log settings
LOG="/var/log/backup.log"
TIMESTYLE="$(date +'%Y-%m-%d %H:%M:%S')"
# Mail settings
MAILFILE="/tmp/mail.txt"
MAIL="joabe.leao1@gmail.com"

# Check directory and files
[[ -f ${MAILFILE} ]] && rm -f ${MAILFILE}
[[ -d ${BKPDIR} ]] || mkdir -p ${BKPDIR}



#
# TIMESTAMPPED LOGS
#
# log_it execution
# I'll use the log example from willy's; After, a function from my tag-cli
function log_it() {

  echo "${TIMESTYLE}" ${@} >> ${LOG}

}



#
# EXCLUDE THINGS
#
# Soeckets and directory exclusion
function exclude_it() {

  # Search sockets to exclude from backup and also ignore folders in ${IGNORE}
  ${FIND} /var/ /run/ /dev/ -type s -print > $SOCKET_EXCLUDE 2>> /dev/null
  IGNORE="${IGNORE}"

  # Exclude selected directories and files
  for f in ${IGNORE}; do echo ${f} >> ${SOCKET_EXCLUDE}; done
  
}



#
# HELP OPTION
#
function help_it() {

echo -e "
Usage: $0 [OPTION]
Example: $0 -s -d 

OPTIONS:
  -d \t\t Make backup daily
  -s \t\t Send backup -Must be used before OPTIONS (-d)
  -c \t\t Clear backups older than 15 days
"
}


#
# MAIL OPTION	
#
function mail_it() {

  log_it "mail_it: The backup was not completed successfully, please check."

  # create file to send mail
  grep $(date +'%Y-%m-%d') ${LOG} >> ${MAILFILE}
  echo -e "\nSent by $0 in $(date +'%Y-%m-%d %H:%M:%S')" >> ${MAILFILE}

  # send mail
  mail -s "[$(hostname)] ERROR: Backup ${MAIL} < ${MAILFILE}"
  
}



#
# SEND OPTION
#
function send_it() {

  local files=("$@")
  for ((i=0; i<${#HOST_BKP[@]}; i++)); do
    ${RSYNC} ${RSYNC_OPTIONS} -e "${SSH} -p${PORT_BKP[$i]} ${SSH_OPTIONS}" ${files[@]} ${USER_BKP[$i]}@${HOST_BKP[$i]}:${DIR_DEST_BKP[$i]}
    [[ $? -ne 0 ]] && log_it "send_it: Something wrong is not right, plz check ${files[@]} for ${HOST_BKP[$i]} in port ${PORT_BKP[$i]}"
  done
  
}



#
# DAILY OPTION
#
function daily_it() {

  local file="$BKPDIR/$(hostname)-$(date '+%d-%m-%Y')-d.tar.gz"

  # create ${SOCKET_EXCLUDE}
  exclude_it

  # compact and compress list of file and directories
  tar -cpzf ${file} ${TAR_OPTIONS} -X ${SOCKET_EXCLUDE} $(echo "${BKPFILES}") 

  # wait end of the tar
  sleep 10

  # Check compression size to guarantee integrity
  tsize=$(du ${DU_OPTIONS} $(cat $BKPFILES) | grep total | awk '{print $1}')
  fsize=$(du ${DU_OPTIONS} $file | grep total | awk '{print $1}')
  min_size=$(echo "$tsize*$PERCENTUAL_MIN_SIZE" | bc | cut -f1 -d'.')

  # Create the MD5 file of the backup
  md5sum ${file} > ${file}.md5 

  # If applicable, send files to a storage
  [[ ${SEND} -eq 1 ]] && send_it "${file}*"

  # if error, send mail
  [[ $fsize -le $min_size ]] && mail_it "Daily"
  
}


#
# BACKUP ROTATION
#
# Clearing up backup files older then a specific time.
function clear_it() {

  # Search and remove files of daily backup
  ${FIND} $BKPDIR -iname "*d.tar.gz" -mtime +15 -exec rm -f {} +

}


#
# BACKUP EXECUTION
# 
while getopts "sdchS" OPT; do
  case "$OPT" in
    "s")  SEND=1       ;;
    "d")  daily_it    ;;
    "c")  clear_it    ;;
    "S")  check_it    ;;
    "h")  help_it     ;;
    "?")  help_it     ;;
  esac
done
