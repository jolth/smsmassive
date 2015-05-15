#!/usr/bin/env bash
#
# --sms="Message SMS"
# --number="send to number"
#
# Usage: 
#       ./sendsms.sh file.csv 'message' --name=1 --device=2 --number=3 --vehicle=4
#
# MESAJES:
#       Apreciado $name, le informamos que su sistema de rastreo satelital para el vehiculo $placa esta para pago inmediato. Haga caso omiso si ya realizo su pago  
#      
# Dependencias:
#    - Gammu
#
#
# Author: Jolth
#

function usage {
    echo -e "Usage:\n
            ./sendsms.sh file.csv 'message' --name=1 --device=2 --number=3 --vehicle=4 \n\n"
    echo -e "fichero csv: \n
            ID,NAME,NUMBER
            DEV001,first_name last_name,31000000\n"
}

if [ ${#} -lt 1 ]; then
    echo -e "Error: debe especificar un fichero .csv\n"
    usage
    exit 0
fi

args=("$@")
ELEMENTS=${#args[@]} # get number of elements

# Create vars for the args
for ((i=2; i<$ELEMENTS;i++)); do
    eval $(echo ${args[i]}|awk -F'=' '{print $1"="$2}'|sed 's/-//g')
done

# Evaluate if arg --name existing 
if [ ! $name ]; then 
    echo "Error: arg --name is required"
    usage
    exit 1
fi 

# Evaluate if arg --number existing
if [ ! $number ]; then
    echo "Error: arg --number is required"
    usage
    exit 1
fi

if [ ! $placa ]; then
    echo "Error: arg --placa is required"
    usage
    exit 1
fi


function separate {
    COUNTER=20
    echo -n "["
    until [  $COUNTER -lt 10 ]; do
        echo -n "####"
        let COUNTER-=1
        sleep 1
    done
    echo -e "]\n"
}


## MAIN ###
CSVFILE=$1
SMSTEXT=$2
declare -a NAMES
declare -a PHONES
declare -a PLACAS

echo -e "\nMESSAGE:\n$SMSTEXT\n"
chr_counts=$(echo $SMSTEXT|wc -m)
if (( $chr_counts>155 )); then # Largo del SMS 160 caracteres. 160 - $name = 155
    echo "Error: el Texto del MENSAJE es muy largo: $chr_counts"
    echo "tamaño maximo 155 caracteres"
    exit 1
fi
echo -e "Character number from MESSAGE: $chr_counts"
#separate


function fname {
# devuelve el primer nombre de el cliente
#
    while read line; do
        first_name=$(eval $(echo "awk -F',' '{print \$$name}'")|sed '/^$/d'|cut -d " " -f1)
        #echo -e "$first_name\n"
        #NAMES[$count]=$(eval $(echo "awk -F',' '{print \$$name}'")|sed '/^$/d'|cut -d " " -f1)
    done < $CSVFILE

    count=0
    for i in $first_name
    do
        NAMES[$count]=$i
        count=$((count+1))
    done
} 

function pnumber {
# devuelve el numero telefonico de el cliente
#
    while read line; do
        phone_number=$(eval $(echo "awk -F',' '{print \$$number}'")|sed '/^$/d')
        #echo -e "$phone_number\n"
        #PHONES[$count]=$(eval $(echo "awk -F',' '{print \$$number}'")|sed '/^$/d')
    done < $CSVFILE

    count=0
    for i in $phone_number
    do
        PHONES[$count]=$i
        count=$((count+1))
    done
}

function lplaca {
# devuelve las placas de los vehiculos para los clientes
#
    while read line; do
        placas=$(eval $(echo "awk -F',' '{print \$$placa}'")|sed '/^$/d')
    done < $CSVFILE
#echo $placas
    count=0
    for i in $placas
    do
        PLACAS[$count]=$i
        count=$((count+1))
    done   
}

if [ -n "$device" ]; then
    echo "Read devices..."
fi

echo "Read names..."
fname $line
echo "Read phone numbers..."
pnumber $line
echo "Read placas...."
lplaca $line

if (( ${#NAMES[*]} == ${#PHONES[*]} && ${#NAMES[*]} == ${#PLACAS[*]} )); then
    echo -e "Procesando MESSAGE"
    separate
else
    echo "Error: un usuario no tiene número telefonico o no existe el usuario o faltan las placas."
    exit 1
fi

echo -e "Start To Sending\n"
echo "#####################################################"
count=1
for i in ${!NAMES[*]}
do
    name=${NAMES[$i]}
    placa=${PLACAS[$i]}
    sms=$(echo $SMSTEXT|sed 's/$name/'$name'/g') 
    sms=$(echo $sms|sed 's/$placa/'$placa'/g') 
    chart_count=$(echo $sms|wc -m)
    #printf "%4d [Chart Count: %s] - [%s]:\t" $i $chart_count ${PHONES[$i]}
    #echo $sms
    ## Descomentar para usar el modem:
    ##echo $sms|gammu sendsms TEXT ${PHONES[$i]}
    ##
    ##echo "RETURN GAMMU: $?"

    # Enviar a varios Celulares:
    for c in $(echo ${PHONES[$i]}|sed 's/|/\n/g'|cut -f1); do
        #printf "%4d [Chart Count: %s] - [%s]:\t" $i $chart_count $c
        printf "%4d [Chart Count: %s] - [%s]:\t" $count $chart_count $c
        echo $sms
        # Descomentar para usar el modem:
        echo $sms|gammu sendsms TEXT $c
        # Salida de Error: 
        if (( $?!=0 )); then
            echo "$placa,,$name,,$c,$(date +"%m-%d-%Y %T")," >> send_error.log
        fi
        echo -e "\n"
        count=$((count+1))
    done
done

exit 0
