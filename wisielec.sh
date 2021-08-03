# Author           : Bartosz Leśniewski ( s184783@student.pg.edu.pl )
# Created On       : 01.05.2021
# Last Modified By : Bartosz Leśniewski ( s184783@student.pg.edu.pl )
# Last Modified On : 24.05.2021 
# Version          : 3.0
#
# Description      : Gra "Wisielec" polegająca na odgadywaniu wylosowanego hasła, które ukryte jest
# Opis				 pod znakami podkreślenia (_). Do interakcji z użytkownikiem wykorzystuje program YAD.
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details
# or contact # the Free Software Foundation for a copy)

#!/bin/bash

declare -A BASE
IMG_SRC="./images/0.png"
RANKING_FILE="RANKING.txt"
BASE_FILE="BAZA.txt"
ROUND=1

# wczytuje hasła z bazy do tablicy asocjacyjnej
load_base()
{	
	while IFS="|" read KEY VALUE; do # read -r
		BASE[$KEY]=$VALUE
	done < "$BASE_FILE"
}

# wyświetla menu główne z odpowiednimi opcjami do wyboru
show_menu()
{
	`yad --text="<span font='24'>Menu</span>" --text-align="center" --width="500" --height="150" --title="Wisielec" --center \
	--button="Nowa gra:1" \
	--button="Ranking:2" \
	--button="Wyjście!gtk-quit:3" \
	--buttons-layout="spread" \
	--borders="20"`

	CHOICE=$?

	case $CHOICE in
	"1")
		login
		;;
	"2") 
		show_ranking
		;;
	"3") 
		;;
	esac
}

# wczytuje login od użytkownika i sprawdza, czy jest on prawidłowy, tzn. nie jest pusty i składa się z ciągu połączonych znaków (bez spacji)
login()
{
	LOGIN=$(yad --entry --text="Podaj swój login" --title="Login" --width="300" --center --button="Dalej!gtk-apply:0")
	local STATUS=$?
	LOGIN=`echo $LOGIN | sed 's/ *$//g'`

	if [[ ( -z $LOGIN || ! $LOGIN =~ ^[a-zA-Z0-9_]+$ ) && $STATUS == "0" ]]; then
		while [[ ( -z $LOGIN || ! $LOGIN =~ ^[a-zA-Z0-9_]+$ ) && $STATUS == "0" ]]; do
			if [[ -z $LOGIN ]]; then
				error "Login nie może być pusty"
			else
				error "Login może zawierać jedynie ciąg liter/cyfr oraz znaki podkreślenia _"
			fi

			LOGIN=$(yad --entry --text="Podaj swój login" --title="Login" --width="300" --center --button="Dalej!gtk-apply:0")
			STATUS=$?
			LOGIN=`echo $LOGIN | sed 's/ *$//g'`
		done
	fi

	if [[ -n $LOGIN ]]; then
		start_game
	else
		show_menu
	fi
}

# wyświetla ranking najlepszych graczy, który jest przechowywany w pliku
show_ranking()
{
	COUNTER=1
	while IFS=" " read NICK PKT; do
		echo $COUNTER
		echo $NICK
		echo $PKT
		COUNTER=$((COUNTER+1))
	done < "$RANKING_FILE" | yad --list --title="Ranking" --text="<span font='24'>TOP 5 graczy</span>" --center --width="400" --height="300" --column="L.p." --column="Login" --column="Liczba zdobytych punktów" --no-click --no-selection --button="Wróć do menu!gtk-refresh:2" --text-align="center"

	CHOICE=$?
	show_menu
}

# wyświetla okno z informacją o błędzie, która jest podana jako parametr wywołania
error()
{
	`yad --image="gtk-dialog-error" --title "Błąd" --text "$1" --text-align="center" --center --width="320" --borders="10" --button="Powrót!gtk-refresh:1"`
}

# wyświetla okno z zapytaniem o potwierdzenie zamknięcia programu
quit_window()
{
	`yad --image="gtk-dialog-question" --title "Wyjście" --text "Czy na pewno chcesz opuścić grę?" --text-align="center" --center --width="320" --borders="10" --button="Tak!gtk-ok:0" --button="Nie!gtk-no:1"`

	STATUS=$?

	if [[ $STATUS == "1" ]]; then
		$1
	fi
}

# ustawia początkowe wartości zmiennych na starcie gry 
start_game()
{
	IMG_SRC="./images/0.png"
	USED_LETTERS=()
	LIFES=9
	SECRET=""
	draw_word
	generate_secret
	gameplay
}

# losuje słowo z bazy
draw_word()
{
	WORDS=()

	if [[ ${#BASE[@]} -eq 0 ]]; then
		load_base
	fi

	i=0
	for key in "${!BASE[@]}"; do
		WORDS[$i]=$key
		i=$((i+1))
	done

	local RANDOM_POSITION=$[$RANDOM % ${#WORDS[*]}]
	WORD=${WORDS[$RANDOM_POSITION]}
	CATEGORY=${BASE[$WORD]}

	#echo "Wylosowane słowo to: $WORD"
}

# generuje postać zaszyfrowaną wylosowanego słowa
generate_secret()
{
	for (( i=0 ; i < ${#WORD} ; i++ )); do
		if [[ ${WORD:i:1} != " " ]]; then
			SECRET+="_"
	    else
	    	SECRET+=" "
	    fi
	done
}

# wyświetla słowo w postaci zaszyfrowanej
show_secret()
{
	for (( i=0 ; i < ${#SECRET} ; i++ )); do
		echo -n "${SECRET:i:1} "
	done
}

# obsługuje rozgrywkę
gameplay()
{
	local STATUS=0

	# rozgrywka trwa dopóki użytkownik nie wciśnie przycisku wyjścia, nie utraci wszystkić żyć i nie odgadnie całego hasła
	while [[ $STATUS == "0" && $LIFES -gt 0 && $SECRET != $WORD ]]; do
		LETTER=$(yad --form --title="Wisielec (Runda: $ROUND)" --center --separator="" --align="center" --field="<span font='16'>Kategoria: $CATEGORY</span>":LBL --image="$IMG_SRC" --image-on-top --field="<span font='18'>$(show_secret)</span>":LBL --field="Podaj literę":CE --button="Zatwierdź!gtk-apply:0" --buttons-layout="spread")

		STATUS=$?

		if [[ $STATUS == "0" ]]; then
			LETTER=${LETTER^}
			LETTER=`echo $LETTER | sed 's/ *$//g'`

			# obsługa błędnego podania litery
			if [[ ${#LETTER} -gt 1 ]]; then
				error "Podałeś za dużo liter."
			elif [[ ${#LETTER} -eq 0 ]]; then
				error "Podałeś za mało liter."
			elif [[ ! $LETTER =~ ^[A-Z|a-z|ĄąĆćĘęŁłŃńÓóŚśŹźŻź]$ ]]; then
				error "Nieprawidłowy znak. Dozwolone są tylko małe i wielkie litery."
			elif [[ $(check_if_used $LETTER) == "true" ]]; then
				error "Ta litera została już wykorzystana. Spróbuj wybrać inną."
			else
				USED_LETTERS+=("$LETTER")
				check
			fi
		fi
	done

	# jeśli po wyjściu z pętli jest status 0, tzn., że użytkownik odgadł hasło lub skończyły się życia
	if [[ $STATUS == "0" ]]; then
		end_of_round
	elif [[ $STATUS == "252" ]]; then # status 252 wystąpi, gdy użytkownik wciśnie przycisk zamknięcia okna (X)
		quit_window "gameplay"
	fi
}

# sprawdza, czy podana przez gracza litera wystąpiła w słowie
check()
{
	# jeśli litera występuje w słowie, to należy wstawić ją w miejsce odpowiedniego znaku _
	local TMP_SECRET
	OCCURED=false
	for (( i=0 ; i < ${#WORD} ; i++ )); do
		if [[ $LETTER = ${WORD:i:1} ]]; then
			OCCURED=true
			TMP_SECRET+="$LETTER"
		else
			TMP_SECRET+="${SECRET:i:1}"
		fi
	done

	SECRET=$TMP_SECRET

	# w przeciwnym razie gracz traci życie i wyświetlany jest kolejny element szubienicy
	if [[ $OCCURED == false ]]; then
		OLD_NUMBER=${IMG_SRC:9:1}
		NEW_NUMBER=$((OLD_NUMBER + 1))
		IMG_SRC=${IMG_SRC/$OLD_NUMBER/$NEW_NUMBER}
		LIFES=$((LIFES-1))
	fi
}

# sprawdza, czy podana przez gracza litera była już wcześniej wykorzystana
check_if_used()
{
	local FOUND="false"

	for w in ${USED_LETTERS[*]}; do
		if [[ $w == $1 ]]; then
			FOUND="true"
			break
		fi
	done

	echo $FOUND
}

# obsługa końca gry
end_of_round()
{
	# punkty zwiększają się zgodnie z pozostałą liczbą żyć w danej rundzie
	POINTS=$((POINTS+LIFES))
	update_ranking "$LOGIN" "$POINTS"

	# jeśli zaszyfrowane słowo jest równe temu w postaci normalnej tzn., że gracz odgadł hasło
	if [[ $SECRET == $WORD ]]; then
		`yad --form --title="Wygrana" --center --separator="" --align="center" --field="<span font='16'><span foreground='green'>Wygrałeś!</span> Prawidłowe hasło to: </span>":LBL --image="$IMG_SRC" --image-on-top --field="<span font='18'>$WORD</span>":LBL --button="Kontynuuj grę!gtk-go-forward-ltr:0" --button="Zakończ!gtk-quit:1" --buttons-layout="spread"`

	# jeśli liczba żyć wynosi 0 tzn., że gracz przegrał
	elif [[ $LIFES == "0" ]]; then
		`yad --form --title="Przegrana" --center --separator="" --align="center" --field="<span font='16'><span foreground='red'>Przegrałeś :(</span> Prawidłowe hasło to: </span>":LBL --image="$IMG_SRC" --image-on-top --field="<span font='18'>$WORD</span>":LBL --button="Wróć do menu!gtk-refresh:2" --button="Zakończ!gtk-quit:1" --buttons-layout="spread"`
	fi

	CHOICE=$?

	# po zakończeniu rundy wylosowane słowo jest usuwane z tablicy, aby nie mogło być wylosowane ponownie
	unset BASE["$WORD"]

	case $CHOICE in
	"0")
		ROUND=$((ROUND+1))
		start_game
		;;
	"2")
		POINTS=0
		show_menu
		;;
	*)
		;;
	esac
}

# aktualizuje ranking
update_ranking()
{
	declare -A RESULTS

	while IFS=" " read NICK PKT; do
		RESULTS[$NICK]=$PKT
	done < "$RANKING_FILE"

	# jeśli gracz o danym loginie występuje już w rankingu i liczba uzyskanych punktów jest większa od aktualnie posiadanej, to należy ją zaktualizować na nową wartość
	# jesli gracz o danym loginie nie występuje w rankingu, to dodawany jest nowy element do tablicy
	if [[ ( -v RESULTS["$1"] && "$2" -gt RESULTS["$1"] ) || ( ! -v RESULTS["$1"] ) ]]; then
		RESULTS[$1]=$2
	fi

	TMP_RANKING=`mktemp`
	for key in "${!RESULTS[@]}"
	do
	    echo "$key ${RESULTS[$key]}" >> $TMP_RANKING
	done 

	sort -rn -k2 -o "$TMP_RANKING" "$TMP_RANKING"

	head -n 5 "$TMP_RANKING" > "$RANKING_FILE"

	rm "$TMP_RANKING"
}

help()
{
	echo "Pomoc"

	echo -e "\nOpcje wywołania:"
	echo -e "-v \t\t wyświetla informacje o autorze oraz wersji programu"
	echo -e "-h \t\t wyświetla pomoc"
	echo -e "-f nazwa_pliku \t wczytuje baze haseł zapisanych w pliku podanym jako parametr."
	echo -e "\t\tUWAGA: hasła muszą być zapisane w osobnych liniach w postaci SŁOWO|KATEGORIA"

	echo -e "\nObsługa menu:"
	echo -e "Nowa gra \t\t wyświetla zapytanie o login, a następnie uruchamia grę"
	echo -e "Ranking \t\t wyświetla ranking TOP 5 najlepszych użytkowników"
	echo -e "Wyjście \t\t powoduje zamknięcie programu"

	echo -e "\nRozgrywka:"
	echo "Zadaniem gracza jest odgadnięcie zaszyfrowanego hasło poprzez wpisywanie jego pojedynczych liter. Należy podać tylko jedną literę i zatwierdzić swój wybór przyciskiem 'Zatwierdź' lub klawiszem enter. Wielkość liter nie jest rozróżniana."

}

version()
{
	echo "Autor: Bartosz Leśniewski (184783)"
	echo "Wersja: 3.0"
}

if [[ $# -eq 0 ]]; then
	load_base
	show_menu
else
	while getopts hvf: OPT; do
		case "$OPT" in 
			"h")
				help
				;;
			"v")
				version
				;;
			"f")
				BASE_FILE=$OPTARG
				load_base
				show_menu
				;;
			*)
				echo "Nieznana opcja. Wywołaj program z opcją -h, aby uzyskać więcej informacji."
		esac
	done
fi

#load_base
#show_menu