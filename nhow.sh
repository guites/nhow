#!/bin/bash
config_file="$HOME/.nhow.env"
jwt_file="$HOME/.nhow.jwt"
declare -a config_vars=("identity" "codigo_empresa" "numero_matricula" "senha" "longitude" "latitude")

# reads values from config file
# $1 is variable name in .env
read_var_config()
{
    sed -nr "s/^$1=(.*)$/\1/p" "$config_file"
}

urlencode() {
  local LC_ALL=C
  local string="$*"
  local length="${#string}"
  local char

  for (( i = 0; i < length; i++ )); do
    char="${string:i:1}"
    if [[ "$char" == [a-zA-Z0-9.~_-] ]]; then
      printf "$char"
    else
      printf '%%%02X' "'$char"
    fi
  done
}


write_var_config() {
    echo -e "\033[1m$1\033[0m: "
    read -r received_var
    if [ -z "$received_var" ]; then
        echo -e "Por favor, forneça o valor de \033[1m$1\033[0m."
        write_var_config "$1"
    fi
    echo "$1=$received_var" >> "$config_file"
}


check_env_vars() {
    if [ ! -f "$config_file" ]; then
        if ! touch "$config_file"; then
            echo "Não foi possível criar o arquivo de configurações em config_file: $config_file ."
            echo "Verifique que você possui permissão de escrita no caminho acima e tente novamente."
            exit 1
        fi
    fi
    for i in "${config_vars[@]}"; do
        var=$(read_var_config "$i")
        if [ -z "$var" ]; then
            echo -e "Forneça o valor de \033[1m* $i *\033[0m utilizado nas requisições do portal."
            write_var_config "$i"
        fi
    done
}


check_env_vars

# set global configuration variables
identity=$(read_var_config identity)
codigo_empresa=$(read_var_config codigo_empresa)
numero_matricula=$(read_var_config numero_matricula)
senha=$(read_var_config senha)
urlencoded_senha=$(urlencode "$senha")
long=$(read_var_config longitude)
lat=$(read_var_config latitude)


Help() {
   # Display Help
   echo "Este script vai te mostrar os horários nos quais você bateu o ponto hoje."
   echo
   echo "sintaxe: nhow.sh [-j|e|p|h]"
   echo "opções:"
   echo "j     (jwt) Gera um novo jwt para autenticação no sistema."
   echo "e     (espelho) Imprime os horários nos quais você bateu o ponto no dia atual."
   echo "                Aceita um parâmetro adicional definindo o dia do espelho, no formato do comando \"date --date\" (ex. yesterday, last week, 2 days ago)."
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
    my_jwt=$(echo "$login_response" | jq .jwt | sed 's/"//g')
    echo "$my_jwt" > "$jwt_file"
}


get_ponto_of_given_day() {
    # $@ handles arguments as array, $* concatenates all arguments as string
    target_day=$([ "$*" == "" ] && echo "today" || echo "$@")
    date_of_pontos=$(date -I --date="$target_day")
    if [ ! "$date_of_pontos" ]; then
        echo "Invalid date argument."
        echo "Please check https://www.gnu.org/software/tar/manual/html_chapter/Date-input-formats.html#Relative-items-in-date-strings";
        exit 1
    fi
    my_jwt=$(cat "$jwt_file" 2>/dev/null)
    [ $? == 1 ] && echo "You need to generate a new jwt. Run <./nhow.sh -j>" && exit 1
    res="$(curl https://www.nhow.com.br/api-espelho/apuracao/ -H "Authorization: Bearer ${my_jwt}")"
    if [ "$res" == "" ]; then
        echo "Could not connect to the API. Please run this additional request for debugging purposes:"
        echo "curl -I https://www.nhow.com.br/api-espelho/apuracao/ -H \"Authorization: Bearer ${my_jwt}\""
        echo "or try generating a new JWT via <./nhow.sh -j>"
        exit 1
    fi
    has_error=$(echo "$res" | jq 'has("error")')
    if [ "$has_error" == "true" ]; then
        http_status=$(echo "$res" | jq .code)
        details=$(echo "$res" | jq .message)
        echo "Error while requesting to the API. HTTP Status $http_status"
        echo "Details: $details"
        echo "Try generating a new JWT via <./nhow.sh -j>"
        exit 1
    fi
    echo "$res" | jq ".dias[] | select(.referencia==\"$date_of_pontos\")".batidas
}


hit_ponto() {
    timestamp=$(date +%s%N | cut -b1-13)
    echo "Bater ponto? [s|N]"
    read -r should_proceed
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
            get_ponto_of_given_day "${@:2}"
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
if [ -z "$1" ]; then
    Help
    exit
fi
