
# reads values from config file
# $1 is variable name in .env
read_var_config()
{
    config_file=.env
    sed -nr 's/^'$1'=(.*)$/\1/p' $config_file
}

# set global configuration variables
identity=$(read_var_config identity)
codigo_empresa=$(read_var_config codigo_empresa)
numero_matricula=$(read_var_config numero_matricula)
senha=$(read_var_config senha)
urlencoded_senha=$(bash urlencode.sh "$senha")
long=$(read_var_config longitude)
lat=$(read_var_config latitude)

Help() {
   # Display Help
   echo "Este script vai te mostrar os horários nos quais você bateu o ponto hoje."
   echo
   echo "sintaxe: nhow.sh [-j|e|p|h]"
   echo "opções:"
   echo "j     (jwt) Gera um novo jwt para autenticação no sistema."
   echo "e     (espelho) Imprime os horários nos quais você bateu o ponto hoje."
   echo "p     (ponto) Bate o ponto no horário atual."
   echo "h     (help) Imprime este diálogo de ajuda."
   echo
}

get_jwt() {
    login_response=$(curl 'https://www.nhow.com.br/externo/login'  \
        -H 'authority: www.nhow.com.br' \
        -H 'accept: */*'  \
        -H 'accept-language: en-US,en;q=0.9,pt-BR;q=0.8,pt;q=0.7'  \
        -H 'cache-control: no-cache'  \
        -H 'content-type: application/x-www-form-urlencoded; charset=UTF-8'  \
        -H 'origin: https://www.nhow.com.br'  \
        -H 'pragma: no-cache'  \
        -H "referer: https://www.nhow.com.br/externo/index/$codigo_empresa"  \
        -H 'sec-ch-ua: "Chromium";v="104", " Not A;Brand";v="99", "Google Chrome";v="104"' \
        -H 'sec-ch-ua-mobile: ?0' \
        -H 'sec-ch-ua-platform: "Linux"'  \
        -H 'sec-fetch-dest: empty' \
        -H 'sec-fetch-mode: cors' \
        -H 'sec-fetch-site: same-origin' \
        --data-raw "empresa=$codigo_empresa&origin=portal&matricula=$numero_matricula&senha=$urlencoded_senha" \
        --compressed)
    my_jwt=$(echo $login_response | jq .jwt | sed 's/"//g')
    echo $my_jwt > .nhow.jwt
}

get_todays_ponto() {
    my_jwt=$(cat .nhow.jwt 2>/dev/null)
    [ $? == 1 ] && echo "You need to generate a new jwt. Run <./nhow.sh -j>" && exit 1
    today=$(date -I)
    curl https://www.nhow.com.br/api-espelho/apuracao/ -H "Authorization: Bearer $my_jwt" | jq ".dias[] | select(.referencia==\"$today\")".batidas
}

hit_ponto() {
    timestamp=$(date +%s%N | cut -b1-13)
    echo "Bater ponto? [s|N]"
    read should_proceed
    [[ $should_proceed != 's' ]] && echo "Finalizando programa sem bater o ponto..." && exit 0

    curl 'https://www.nhow.com.br/batidaonline/verifyIdentification' \
      -H 'authority: www.nhow.com.br' \
      -H 'accept: application/json;charset=UTF-8' \
      -H 'cache-control: no-cache' \
      -H 'content-type: text/plain;charset=UTF-8' \
      --data-raw '{"identity":"'"$identity"'","account":"'"$numero_matricula"'","password":"'"$senha"'","login":false,"offline":true,"timestamp":'"$timestamp"',"origin":"chr","version":"1.0.25","identification_type":"matricula_senha","longitude":'"$long"',"latitude":'"$lat"',"accuracy":14.813,"provider":"network/wifi"}' \
      --compressed
}

# handle script options
while getopts ":jeph" option; do
    case $option in
        j) # get a new jwt and save to file
            get_jwt
            exit;;
        e) # print daily pontos
            get_todays_ponto
            exit;;
        p) # hits ponto with current timestamp
            hit_ponto
            exit;;
        h) # print help
            Help
            exit;;
        \?) # invalid option
            echo "Invalid option"
            Help
            exit;;
   esac
done


# shows help when script is called without params
if [ -z $1 ]; then
    Help
    exit
fi
