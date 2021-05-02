#!/usr/bin/env bash

NAME="Respaldo"
DB_NAME="Entidad_sanitaria"
DB_USER=spawn
DB_MY_CNF=/usr/bin/databases/.my.cnf
DATE=$(date +"%d%m%y%H%M")
FILE_NAME=${NAME}${DB_NAME}${DATE}.sql
SMB_IP=172.17.0.4
SMB_FOLDER="sambashare"
SMB_USER="spawnmc"
SMB_PASSWD="joshuan9819"
SHARE_MOUNT_DIR=/mnt/sambashare
MAIL_MSG="El backup se ha generado con éxito y se encuentra actualmente en el recurso compartido"
MAIL_DEST="spawnmcsqrt@gmail.com"

green="\e[0;32m\033[1m"
resetc="\033[0m\e[0m"
red="\e[0;31m\033[1m"
blue="\e[0;34m\033[1m"
yellow="\e[0;33m\033[1m"
purple="\e[0;35m\033[1m"
turquoise="\e[0;36m\033[1m"
gray="\e[0;37m\033[1m"

generete_backup(){
    echo "Generando backup..."
    mysqldump --defaults-file=$DB_MY_CNF -u $DB_USER $DB_NAME --no-data --skip-comments --routines > $FILE_NAME
}


make_dir(){
    if [[ -d $SHARE_MOUNT_DIR ]] ; then
        echo "Directorio para recursos compartidos existe."
    else
        sudo mkdir $SHARE_MOUNT_DIR
        echo "Directorio de recursos compartido creado."
    fi
}


mount_shared_resource(){
    if ! df | grep -i $SMB_IP &>/dev/null ; then
        echo "Montando recurso compartido..."
        sudo mount -t cifs -o username=${SMB_USER},password=${SMB_PASSWD} //${SMB_IP}/${SMB_FOLDER} ${SHARE_MOUNT_DIR}
    else
        echo "El recurso compartido ya se encuentra montado"
    fi
}

copy_to_shared_resource(){
    echo "Copiando backup a recurso compartido..."
    if cp $FILE_NAME $SHARE_MOUNT_DIR -f ; then
        rm  $FILE_NAME
    fi
}


send_mail(){
    if ping -c 2 www.google.com &>/dev/null ; then
        echo $MAIL_MSG | mail -s "Backup generado" $MAIL_DEST
        echo "Correo electronico enviado." 
    else
        echo "Sin acceso a internet"
        echo "Correo electronico no enviado"
    fi
}

usage (){
 
}
