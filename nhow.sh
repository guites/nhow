minha_matricula="1234"
minha_senha="minhasenha"
codigo_empresa="abc123"

Help() {
   # Display Help
   echo "Este script vai te mostrar o horário no qual você bateu os pontos hoje."
   echo
   echo "sintaxe: nhow.sh [-j|p|h]"
   echo "opções:"
   echo "j     Gera um novo jwt para autenticação no sistema."
   echo "p     Imprime os horários nos quais você bateu o ponto hoje."
   echo "h     Imprime este diálogo de ajuda."
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
        --data-raw "empresa=$codigo_empresa&origin=portal&matricula=$minha_matricula&senha=$minha_senha" \
        --compressed)

    my_jwt=$(echo $login_response | jq .jwt | sed 's/"//g')
    echo $my_jwt > .nhow.jwt
}

get_todays_ponto() {
    my_jwt=$(cat .nhow.jwt 2>/dev/null)
    [ $? == 1 ] && echo "You need to generate a new jwt. Run <./nhow -j>" && exit 1
    today=$(date -I)
    curl https://www.nhow.com.br/api-espelho/apuracao/ -H "Authorization: Bearer $my_jwt" | jq ".dias[] | select(.referencia==\"$today\")".batidas
}

# handle script options
while getopts ":jp" option; do
   case $option in
      j) # get a new jwt and save to file
        get_jwt
        exit;;
      p) # print daily pontos
        get_todays_ponto
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
