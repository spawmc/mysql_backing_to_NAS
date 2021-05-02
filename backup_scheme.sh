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
MAIL_DEST="spawnmcsqrt@gmail.com"
CNF_FILE=/etc/mysql/my.cnf
CNF_BACKUP_NAME=my.cnf.${DATE}.backup
MAIL_MSG="El backup se ha generado con éxito y se encuentra actualmente en el recurso compartido"
TELEGRAM_MSG=""

green="\e[0;32m\033[1m"
resetc="\033[0m\e[0m"
red="\e[0;31m\033[1m"
blue="\e[0;34m\033[1m"
yellow="\e[0;33m\033[1m"
purple="\e[0;35m\033[1m"
turquoise="\e[0;36m\033[1m"
gray="\e[0;37m\033[1m"

generate_schema_backup(){
    echo "Generando backup del esquema"
    FILE_NAME=Esquema${DB_NAME}${DATE}.sql
    mysqldump --defaults-file=$DB_MY_CNF -u $DB_USER $DB_NAME --no-data --skip-comments --routines > $FILE_NAME
    TELEGRAM_MSG="Se ha guardado el archivo de respaldo ${FILE_NAME} que contiene el esquema de la base de datos llamada ${DB_NAME} dentro del recurso compartido en el folder ${SMB_FOLDER} del host ${SMB_IP}"
}

generate_full_backup(){
    echo "Generando backup completo"
    cp $CNF_FILE $CNF_BACKUP_NAME
    FILE_NAME=FullBackup${DATE}.sql
    mysqldump --defaults-file=$DB_MY_CNF -u $DB_USER --all-databases > $FILE_NAME
    TELEGRAM_MSG="Se ha guardado el archivo de respaldo ${FILE_NAME} con información de todas las bases de datos y el archivo de configuración ${CNF_BACKUP_NAME} dentro del recurso compartido en el folder ${SMB_FOLDER} del host ${SMB_IP}"
}

copy_cnf_to_shared_resource(){
    if cp $CNF_BACKUP_NAME $SHARE_MOUNT_DIR -f ; then
        rm $CNF_BACKUP_NAME
    fi
}

generate_data_backup(){
    echo "Generando backup de datos"
    FILE_NAME="FullBackup${DATE}.sql"
    mysqldump --defaults-file=$DB_MY_CNF -u $DB_USER --all-databases | gzip > $FILE_NAME.gz
    TELEGRAM_MSG="Se ha guardado el archivo de respaldo ${FILE_NAME}.gz con información de todas las bases de datos dentro del recurso compartido en el folder ${SMB_FOLDER} del host ${SMB_IP}"
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

usage(){
   echo -e "Usage: $0 [options] [--]
    Options:
    -h|help       Display this message
    -s|scheme     Genera backup solo del esquema
    -d|data       Genera backup de datos de toda las bases de datos
    -f|full       Genera un backup comleto de todas las bases de datos y archivos de configuración
    "
}

mysql_status(){
    mysql -u root $>/dev/null
    if [[ $? -eq 1 ]] ; then
        echo -e "\n${red}[-]${resetc} MySql not runnig"
        exit 1;
    else
        echo -e "\n${green}[+]${resetc} MySql runnig"
    fi
}

send_telegram_alert(){
    USERID="-100"
    KEY=""
    TIMEOUT="10"
    URL="https://api.telegram.org/bot$KEY/sendMessage"
    LOG="envio_telegram_${DATE}.log"
    SONIDO=0
    FECHA_EJEC="$(date "+%d %b %H:%M:%S")"
    if [[ $2 -eq 1 ]] ; then
	    SONIDO=1
    fi
    TEXTO="<b>$FECHA_EJEC:</b>\n<pre>$1</pre>\n${TELEGRAM_MSG}"
    curl -s --max-time $TIMEOUT -d "parse_mode=HTML&disable_notification=$SONIDO&chat_id=$USERID&disable_web_page_preview=1&text=`echo -e "$TEXTO"`" $URL >> $LOG 2>&1
    "echo" >> $LOG
}


    while getopts ":h:s:f:d" opt ; do
        case ${opt} in
            h|help)
                usage; exit 0
                ;;
            s|scheme)
                #mysql_status
                generate_schema_backup
                make_dir
                mount_shared_resource
                copy_to_shared_resource
                send_mail
                send_telegram_alert "Backup de esquema de la tabla ${DB_NAME} terminado" 0
                ;;
            f|full)
                #mysql_status
                generate_full_backup
                make_dir
                mount_shared_resource
                copy_to_shared_resource
                copy_cnf_to_shared_resource
                send_mail
                send_telegram_alert "Backup completo terminado" 0
                ;;
            d|data)
                #mysql_status
                generate_data_backup
                make_dir
                mount_shared_resource
                FILE_NAME=${FILE_NAME}.gz
                copy_to_shared_resource
                send_mail
                send_telegram_alert "Backup de datos completado" 0
        esac
    done

    shift $(($OPTIND-1))

