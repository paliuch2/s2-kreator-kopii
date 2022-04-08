#!/bin/bash

# Author           : Kamil Paluszewski (s180194@student.pg.edu.pl)
# Created On       : 08.05.2020
# Last Modified By : Kamil Paluszewski (s180194@student.pg.edu.pl)
# Last Modified On : 24.05.2020
# Version          : v. 1.0
#
#
# Description      :
# Skrypt umozliwia uzytkownikowi wykonanie kopii zapasowej plikow.
# Uzytkownik wybiera, jakie pliki i katalogi chce umiecic w swojej kopii zapasowej.
# Przechowywanych jest 20 kopii zapasowych. W przypadku przekroczenia tej liczby, najstarsza jest usuwana.
# Najnowsza kopia jest przechowywana w stanie wolnym. Starsze pakowane sa do archiwum (uzytkownik wybiera rodzaj archiwum)

set -euo pipefail

ARCHIVING_DIRECTORY="$HOME/KreatorKopiiZapasowej"
TARGET_DIRECTORY="$ARCHIVING_DIRECTORY/backups" # TODO
ZEN_H=800
ZEN_W=1200
LICZBA_KOPII=20

if [ "${1:-}" = '-v' ]; then
  cat <<VERSION_INFO
KREATOR KOPII ZAPASOWEJ
wersja:   0.2
autor:    Kamil Paluszewski
kontakt:  s180194@student.pg.edu.pl
VERSION_INFO
  exit
fi

if [ "${1:-}" = '-h' ]; then
  cat <<HELP
KREATOR KOPII ZAPASOWEJ - POMOC
-v : informacje o wersji i autorze
-h : pomoc
Opcje wywolania beda uzupelniane w pozniejszym czasie
HELP
  exit
fi

SELECTED_FILES=()
SELECTED_DIRECTORIES=()
EXCLUDED_EXTENSIONS=()
SELECTED_ARCHIVING=""
IMPORT_FILE=""

function choose_files() {
  set +e
  SELECTED_FILES+=("$(zenity --file-selection --title "Wybierz pliki")")
  exitcode=$?
  set -e
  if [ $exitcode = 1 ]; then
    return
  fi
}

function choose_directories() {
  set +e
  SELECTED_DIRECTORIES+=("$(zenity --file-selection --title "Wybierz katalogi" --directory)")
  exitcode=$?
  set -e
  if [ $exitcode = 1 ]; then
    return
  fi

}

function filter_extensions() {
  read_extension=''

  while true; do
    set +e
    read_extension="$(zenity --entry --title "Podaj rozszerzenie plikow, ktore chcesz wykluczyc (jedno na raz)")"
    exitcode=$?
    set -e
    if [ $exitcode = 1 ]; then
      return
    fi
    if [[ ! "$read_extension" =~ ^\.[a-zA-Z.0-9]+$ ]]; then
      zenity --error --title "Niepoprawne rozszerzenie" --text "Niepoprawne rozszerzenie. Podaj nazwe rozszerzenia z kropka na poczatku (np. .sh)" --height 100 --width 500
    else
      break
    fi
  done
  EXCLUDED_EXTENSIONS+=("$read_extension")
}

function archive() {

  type1="Archiwuj z kompresja programem gzip"
  type2="Archiwuj z kompresja programem bzip2"
  type3="Archiwuj z kompresja programem xz"
  ARCH_MENU=("$type1" "$type2" "$type3")
  set +e
  display=$(zenity --list --column=ARCH_MENU "${ARCH_MENU[@]}" --height $ZEN_H --width $ZEN_W)
  exitcode=$?
  set -e
  if [ $exitcode = 1 ]; then
    return
  fi

  if [ "$display" = "$type1" ]; then
    SELECTED_ARCHIVING="-z"
  fi
  if [ "$display" = "$type2" ]; then
    SELECTED_ARCHIVING="-j"
  fi
  if [ "$display" = "$type3" ]; then
    SELECTED_ARCHIVING="-J"
  fi

}

function export() {
  echo '' >config.sc
  for FILE in "${SELECTED_FILES[@]}"; do
    echo "SELECTED_FILES+=('$FILE')" >>config.sc
  done

  for DIR in "${SELECTED_DIRECTORIES[@]}"; do
    echo "SELECTED_DIRECTORIES+=('$DIR')" >>config.sc
  done

  for EXT in "${EXCLUDED_EXTENSIONS[@]}"; do
    echo "EXCLUDED_EXTENSIONS+=('$EXT')" >>config.sc
  done
  echo 'SELECTED_ARCHIVING='"$SELECTED_ARCHIVING" >>config.sc
}

function import() {
  #CZYSZCZENIE TABLIC PRZED IMPORTEM
  SELECTED_FILES=()
  SELECTED_DIRECTORIES=()
  EXCLUDED_EXTENSIONS=()
  SELECTED_ARCHIVING=""

  IMPORT_FILE="$(zenity --file-selection --title "Otworz plik")"
  # shellcheck disable=SC1090
  . "$IMPORT_FILE"

}

function see_files() {
  INFO=""
  for FILE in "${SELECTED_FILES[@]}"; do
    INFO+="$FILE\n"
  done
  zenity --info --title "WYBRANE PLIKI" --width 500 --height 300 --text "$INFO"
}

function see_dirs() {
  INFO=""
  for DIR in "${SELECTED_DIRECTORIES[@]}"; do
    INFO+="$DIR\n"
  done
  zenity --info --title "WYBRANE KATALOGI" --width 500 --height 300 --text "$INFO"
}

function run_copy() {

  if [ -z $SELECTED_ARCHIVING ]; then
    zenity --error --title "Brak archiwizacji" --text "Wybierz typ archiwizacji poprzedniej kopii!" --height 100 --width 150
    return
  fi

  set +e
  zenity --question --title "Potwierdzenie" --text "Czy na pewno chcesz stworzyc kopie z wybranych plikow?" --height 100 --width 150
  exitcode=$?
  set -e
  if [ $exitcode = 1 ]; then
    return
  fi

  if [[ -e "$ARCHIVING_DIRECTORY/$LICZBA_KOPII.tar.gz" || -e "$ARCHIVING_DIRECTORY/$LICZBA_KOPII.tar.xz" || -e "$ARCHIVING_DIRECTORY/$LICZBA_KOPII.tar.bz2" ]]; then
    rm -fr "$ARCHIVING_DIRECTORY/$LICZBA_KOPII.tar."*
  fi

  NUMER=$((LICZBA_KOPII - 1))
  while [ $NUMER -ge 1 ]; do
    NEXT=$((NUMER + 1))
    if [ -e "$ARCHIVING_DIRECTORY/$NUMER.tar.gz" ]; then
      mv "$ARCHIVING_DIRECTORY/$NUMER.tar.gz" "$ARCHIVING_DIRECTORY/$NEXT.tar.gz"
    elif [ -e "$ARCHIVING_DIRECTORY/$NUMER.tar.xz" ]; then
      mv "$ARCHIVING_DIRECTORY/$NUMER.tar.xz" "$ARCHIVING_DIRECTORY/$NEXT.tar.xz"
    elif [ -e "$ARCHIVING_DIRECTORY/$NUMER.tar.bz2" ]; then
      mv "$ARCHIVING_DIRECTORY/$NUMER.tar.bz2" "$ARCHIVING_DIRECTORY/$NEXT.tar.bz2"
    fi
    NUMER=$((NUMER - 1))
  done

  if [[ -e $TARGET_DIRECTORY ]]; then
    if [ $SELECTED_ARCHIVING = "-z" ]; then
      tar -zcf "$ARCHIVING_DIRECTORY/1.tar.gz" "$TARGET_DIRECTORY"
    fi
    if [ $SELECTED_ARCHIVING = "-j" ]; then
      tar -jcf "$ARCHIVING_DIRECTORY/1.tar.bz2" "$TARGET_DIRECTORY"
    fi
    if [ $SELECTED_ARCHIVING = "-J" ]; then
      tar -Jcf "$ARCHIVING_DIRECTORY/1.tar.xz" "$TARGET_DIRECTORY"
    fi
    rm -fr "$TARGET_DIRECTORY"
  fi

  REWRITE=()
  for EXT in "${EXCLUDED_EXTENSIONS[@]}"; do
    REWRITE+=("--exclude" "*$EXT")
  done

  for FILE in "${SELECTED_FILES[@]}"; do
    mkdir -p "$(dirname "$TARGET_DIRECTORY/$FILE")"
    rsync --archive --recursive "$FILE" "$TARGET_DIRECTORY/$FILE" "${REWRITE[@]}"
  done

  for DIRECTORY in "${SELECTED_DIRECTORIES[@]}"; do
    mkdir -p "$(dirname "$TARGET_DIRECTORY/$DIRECTORY")"
    rsync --archive --recursive "$DIRECTORY/" "$TARGET_DIRECTORY/$DIRECTORY/" "${REWRITE[@]}"
  done

}

while true; do
  opt1="1. Wybierz pliki do archiwizacji "
  opt2="2. Wybierz katalogi do archiwizacji"
  opt3="3. Wybierz rozszerzenia do odfiltrowania ${EXCLUDED_EXTENSIONS[*]}"
  opt4="4. Wybierz rodzaj archiwizacji poprzedniej kopii $SELECTED_ARCHIVING"
  opt5="5. Eksportuj ustawienia do pliku "
  opt6="6. Importuj ustawienia z pliku "
  files="7. Zobacz wybrane pliki "
  dirs="8. Zobacz wybrane katalogi"

  run="Stworz kopie zapasowa "

  zakoncz="Zamknij"

  MENU=("$opt1" "$opt2" "$opt3" "$opt4" "$opt5" "$opt6" "$files" "$dirs" "$run" "$zakoncz")
  option=$(zenity --list --column=MENU "${MENU[@]}" --height $ZEN_H --width $ZEN_W)

  case "$option" in

  $opt1)
    choose_files
    ;;
  $opt2)
    choose_directories
    ;;
  $opt3)
    filter_extensions
    ;;
  $opt4)
    archive
    ;;
  $opt5)
    export
    ;;
  $opt6)
    import
    ;;
  $files)
    see_files
    ;;
  $dirs)
    see_dirs
    ;;
  $run)
    run_copy
    ;;
  $zakoncz) exit ;;
  esac

done
