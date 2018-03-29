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

# Debug checks
CRITICALMSG=0
WARNINGMSG=0

#
# VERSION AND FILE CONTROL
#
# -------------------------------------------
# DIRECTORY SETTINGS
# -------------------------------------------
BASEDIR=$(dirname $0)
CONF="${BASEDIR}/backup.conf"
BKPDIR="/PHOENIXDOWN"
# -------------------------------------------
# REMOTE STORAGE SETTINGS
# -------------------------------------------
SEND=0
BKPDST="/ANOTHERMACHINE ANOTHERMACHINEIP ANOTHERMACHINEPORT ANOTHERMACHINEUSER"
# -------------------------------------------
# FILE SETTINGS
# -------------------------------------------
BKPFILES="/etc /home /boot/grub"
IGNOREDFILES="/root/bkp /dev /home/*/Downloads /home/*/OwnCloud"
SOCKET_EXCLUDE="/tmp/sockets-to-exclude"
# -------------------------------------------
# LOG SETTINGS
# -------------------------------------------
LOG="/var/log/backup.log"
TIMESTYLE="$(date +'%Y-%m-%d %H:%M:%S')"
DEBUGLEVEL="3"
# -------------------------------------------
# MAIL SETTINGS
# -------------------------------------------
# File that will hold the alert message
MAILFILE="/tmp/mail.txt"
# Your mail
MAILFROM="joabe.leao1@gmail.com"
# Destination mail who'll receive alerts
MAILTO=(joabe.leao1@gmail.com mail@provider)
# Your smtp provider
SMTP=smtp.provedor.com.br
# Your mail password
PASS=suasenha


# Check directory and files
[[ -f ${MAILFILE} ]] && rm -f ${MAILFILE}
[[ -d ${BKPDIR} ]] || mkdir -p ${BKPDIR}


#
# TIMESTAMPPED LOGS
#
# log_it execution
# I'll use the log example from willy's; After, a function from my tag-cli
function log_it() {

  local TYPE="$1"
  local DETAILS="$2"

  printf '%s\n' "${TIMESTYLE} ${TYPE} ${DETAILS}" >> ${LOG}

}


#
# INFORMATION MAILS
#
# mail execution
function mail_it() {
  
  # sendmail syntax: sendemail -f "SENDER" -t "RECIPIENT" -u "SUBJECT" -m "MESSAGE"  -xu "USER" -xp "PASS" -s "SMTPADDRESS:PORT" -o tls="YESorNO"
  # Defining backup type
  local type="$1"
  local details="$(grep -E "${TIMESTYLE MENOS A HORA}${type}" ${LOG})"
  local send_mail=$(sendmail -f "${MAILFROM}" -t "${m}" -u "PHOENIXDOWN - ${type}" -m "${TIMESTYLE} ${LOGMSG} ${details}"  -xu "${MAILFROM}" -xp "${PASS}" -s "${SMTP}:587" -o tls="no")
  
  # For each mail, 
  # In order to put a timestamp in the beginning of each line on log, it was not possible to let the timestamp inside message variable
  # First, the message is inserted on log, after, its details. Both with timestamp on the beginning. This is why 2 lines for each logs  
  [[ "${type}" == "INFORMATION" ]] && LOGMSG="[${TYPE}] [$(hostname)] The backup was completed sucessfull."
  [[ "${type}" == "WARNING" ]] && LOGMSG="[${TYPE}] [$(hostname)] Although the backup was completed sucessfull, some errors ocourred. Please check."
  [[ "${type}" == "CRITICAL" ]] && LOGMSG="[${TYPE}] [$(hostname)] The backup was not completed sucessfull, please check."

  for m in ${MAILTO[@]}; do ${send_mail}; done

}       



#
# EXCLUDE THINGS
#
# Soeckets and directory exclusion
function exclude_it() {

  # Search sockets to exclude from backup and also ignore folders in ${IGNORE}
  ${FIND} /var/ /run/ /dev/ -type s -print > $SOCKET_EXCLUDE 2> /dev/null
  IGNORE="${IGNORE}"

  # Exclude selected directories and files
  for f in ${IGNORE}; do 
    echo ${f} >> ${SOCKET_EXCLUDE} 
    [[ ${DEBUGLEVEL} -eq 3 ]] && log_it "INFORMATION" "Excluded Socket: ${f}"  
  done
  
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
# SEND OPTION
#
function send_it() {

  local files=("$@")
  for ((i=0; i<${#HOST_BKP[@]}; i++)); do
    ${RSYNC} ${RSYNC_OPTIONS} -e "${SSH} -p${PORT_BKP[$i]} ${SSH_OPTIONS}" ${files[@]} ${USER_BKP[$i]}@${HOST_BKP[$i]}:${DIR_DEST_BKP[$i]}
    SENDSTATUS=$(echo $?)
      # AJUSTAR DE UM JEITO Q N ENVIA MAIL, APENAS MARCA ALERTA NO LOG E ENTÃO NO FIM DE TD ENVIA UM E-MAIL C TODOS ERROS
      if [[ ${DEBUGLEVEL} -eq 3 ]]; do
        log_it "INFORMATION" "Send info: ssh options are ${SSH_OPTIONS} in port ${PORT_BKP[$i]} with destination ${DIR_DEST_BKP[$i]}"
        log_it "INFORMATION" "Send info: files are ${files[@]} for ${HOST_BKP[$i]}"
      done
    [[ ${SENDSTATUS} -ne 0 ]] && mail_it "WARNING" "Something wrong is not right, plz check ${files[@]} for ${HOST_BKP[$i]} in port ${PORT_BKP[$i]}"
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
  [[ $fsize -le $min_size ]] && log_it "WARNING" "The tar size is below expected"
  
}


#
# BACKUP ROTATION
#
# Clearing up backup files older then a specific time.
function clear_it() {

  # Search and remove files of daily backup
  ${FIND} ${BKPDIR} -iname "*d.tar.gz" -mtime +15 -exec rm -f {} +

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
