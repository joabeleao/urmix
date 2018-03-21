#!/bin/bash
#  Home Sweet Home Backup
#
#  Author: Joabe Nonis Leão - joabe.leao1 at gmail.com
#  Based on: Willy Romao G. Franca (willyr.goncalves at gmail.com)
#  Filename: phoenix_down.sh
#
#  Make backups daily, weekly and monthly of way simple and of easy customization.
#


#
# GLOBAL VARIABLES
#
BKPDIR="/STORAGE"
BKPDST="/ANOTHERMACHINE ANOTHERMACHINEIP ANOTHERMACHINEPORT"
BKPFILES="/etc /boot/loader.conf"
IGNOREDFILES="/root/bkp /dev /home/joabeleao/Downloads /home/joabeleao/Images /home/joabeleao/Documents /home/joabeleao/OwnCloud"
LOG="/var/log/backup.log"
MAILFILE="/tmp/mail.txt"
MAIL="joabe.leao1@gmail.com"
SOCKET_EXCLUDE="/tmp/sockets-to-exclude"
TIMESTYLE="$(date +'%Y-%m-%d %H:%M:%S')"


#
# VERSION AND FILE CONTROL
#
# Base working directory
BASEDIR=$(dirname $0)
CONF="${BASEDIR}/backup.conf"

# Check directory and files
[[ -f ${MAILFILE} ]] && rm -f ${MAILFILE}
[[ -d ${BKPDIR} ]] || mkdir -p ${BKPDIR}

# Tools used
WHICH="/usr/bin/which"
RSYNC="$(${WHICH} rsync)"
GZIP="$(${WHICH} gzip)"
FIND="$(${WHICH} find)"
SSH="$(${WHICH} ssh)"
AWK="$(${WHICH} awk)"
CURL="$(${WHICH} curl)"

# Tools options
SSH_OPTIONS=" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
RSYNC_OPTIONS="-Cravzp"


#
# TIMESTAMPPED LOGS
#
# log_it execution
# I'll use the log example from willy; After, a function from my tag-cli
function log_it() {

  echo "${TIMESTYLE}" ${@} >> ${LOG}

}


#
# SEND MAIL AFTER BACKUP	
#
function mail_it() {

  local type_backup="$1"
  log_it "mail_it: The backup $type_backup was not completed successfully, please check."

  # create file of send mail
  grep $(date +'%Y-%m-%d') $LOG >> $MAILFILE
  echo -e "\nSent by $0 in $(date +'%Y-%m-%d %H:%M:%S')" >> $MAILFILE

  # send mail
  mail -s "[$(hostname)] ERRO: Backup $type_backup" $MAIL < $MAILFILE
}



#
# SEND BACKUP FILE AFTER BACKUP PROCESS
#
function send_it() {

  local files=("$@")
  for ((i=0; i<${#HOST_BKP[@]}; i++)); do
    ${RSYNC} ${RSYNC_OPTIONS} -e "${SSH} -p${PORT_BKP[$i]} ${SSH_OPTIONS}" ${files[@]} ${USER_BKP[$i]}@${HOST_BKP[$i]}:${DIR_DEST_BKP[$i]} ||
      log_it "send_it: Could not send ${files[@]} for ${HOST_BKP[$i]} in port ${PORT_BKP[$i]}"
  done
}



#
# EXCLUDE THINGS
#
# Soeckets and directory exclusion
function exclude_it() {

  # Search sockets to exclude from backup and also ignore folders in ${IGNORE}
  ${FIND} /var/ /run/ /dev/ -type s -print > $SOCKET_EXCLUDE 2>> /dev/null
  IGNORE="/root/bkp/ ${IGNORE}"

  # Exclude selected directories and files
  for f in ${IGNORE}; do echo ${f} >> ${SOCKET_EXCLUDE}; done
}



#
# DAILY OPTION
#
function daily_it() {

  local file="$BKPDIR/$(hostname)-$(date '+%d-%m-%Y')-d.tar.gz"

  # create ${SOCKET_EXCLUDE}
  exclude_it

  # compact and compress list of file and directories
  tar -cpzf ${file} ${TAR_OPTIONS} -X ${SOCKET_EXCLUDE} $(cat "${BKPFILES}") 

  # wait end of the tar
  sleep 10

  # Check compression size to guarantee integrity
  tsize=$(du ${DU_OPTIONS} $(cat $BKPFILES) | grep total | awk '{print $1}')
  fsize=$(du ${DU_OPTIONS} $file | grep total | awk '{print $1}')
  min_size=$(echo "$tsize*$PERCENTUAL_MIN_SIZE" | bc | cut -f1 -d'.')

  # Create the MD5 file of the backup
  _Create_MD5_Backup ${file}

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

