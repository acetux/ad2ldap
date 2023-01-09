#!/bin/bash
#
# https://github.com/acetux/ad2ldap
#
# Script to convert a Microsoft AD CSV export to a LDAP LDIF
#
# Version: 0.1.0

### USAGE AND INPUT

usage () {
  echo "Usage:"
  echo ""
  echo "$0 -i <input file> -o <output file>"
  echo ""
  echo "Note that the input file type must be \".csv\""
  echo ""
  exit 1
}

INPUTFILE=""
OUTPUTFILE=""
while getopts i:o: option; do
  case $option in
    i) INPUTFILE="$OPTARG" ;;
    o) OUTPUTFILE="$OPTARG" ;;
    *) usage ;;
  esac
done

if [[ -z "$INPUTFILE" ]]; then
  echo "Error: -i <input file> must be set"
fi
if [[ ! -r "$INPUTFILE" && ! -f "$INPUTFILE" ]]; then
  echo "$INPUTFILE isn't a readable file"
fi
if [[ $INPUTFILE != *.csv ]]; then
  echo "$INPUTFILE isn't a CSV file or the file name doesn't end in \".csv\""
fi

### FUNCTIONS

### LOGIC

echo "" > $OUTPUTFILE

# Create OUs for users and groups
PRINTOUUSERGROUP="dn: ou=users,dc=gertzenstein,dc=local
changetype: add
objectclass: top
objectclass: organizationalUnit
ou: users

dn: ou=groups,dc=gertzenstein,dc=local
changetype: add
objectclass: top
objectclass: organizationalUnit
ou: groups
"
echo "$PRINTOUUSERGROUP" && echo "$PRINTOUUSERGROUP" >> $OUTPUTFILE

# 1=DN,52=description,114=sn,115=givenName

# Create OUs
cat $INPUTFILE | iconv -f UTF-8 -t ASCII//TRANSLIT | awk -F '#' '{ print $1 "#" $114 }' | sort | while read LINE; do
  if ( echo $LINE | awk -F '#' '{ print $2 }' | grep -q . ); then #only create if a user is part of the OU
    OU=$( echo $LINE | awk -F ',' '{ printf $2 }' | cut -f 2 -d '=' ) #OU = content in column DN after the first "ou=" entry
    if ( cat $OUTPUTFILE | grep -q "ou=${OU}" ); then #prevent duplicates
      :
    else
PRINTOU="dn: ou=${OU},ou=users,dc=gertzenstein,dc=local
changetype: add
objectclass: top
objectclass: organizationalUnit
ou: ${OU}
"
echo "$PRINTOU" && echo "$PRINTOU" >> $OUTPUTFILE
    fi
  fi
done

# Create groups
COUNTER700=700
cat $INPUTFILE | iconv -f UTF-8 -t ASCII//TRANSLIT | awk -F '#' '{ print $52 "#" $114 }' | sort | while read LINE; do #this sort removes empty lines while it won't work with grep inside the var GROUP definition for some reason
  if ( echo $LINE | awk -F '#' '{ print $2 }' | grep -q . ); then #only create if a user is part of the group
    GROUP=$( echo $LINE | cut -s -f 2 -d ',' | sed 's/ //' | cut -s -f 1 -d '#' ) #GROUP = content in column description after the first "," and space
    if ( cat $OUTPUTFILE | grep -q "cn=${GROUP}" ); then #prevent duplicates
      :
    else
PRINTGROUPS="dn: cn=${GROUP},ou=groups,dc=gertzenstein,dc=local
objectClass: top
objectClass: posixGroup
gidNumber: ${COUNTER700}
"
echo "$PRINTGROUPS" && echo "$PRINTGROUPS" >> $OUTPUTFILE
      (( COUNTER700++ ))
    fi
  fi
done

#COUNTER2000=2000
cat $INPUTFILE | iconv -f UTF-8 -t ASCII//TRANSLIT | awk -F '#' '{ print $115 "#" $114 "#" $1 "#" $52 }' | grep -v -e '^[[:space:]]*$' -e '^#' | sort | while read LINE; do
  # Read from input file
  GIVENNAME=$( echo $LINE | awk -F '#' '{ print $1 }' )
  SN=$( echo $LINE | awk -F '#' '{ print $2 }' )
  USERNAME=$( echo ${GIVENNAME}.${SN} | tr '[:upper:]' '[:lower:]' )
  OU=$( echo $LINE | awk -F ',' '{ printf $2 }' | cut -f 2 -d '=' )
  DESCRIPTION=$( echo $LINE | awk -F '#' '{ printf $4 }' )
  if [[ $DESCRIPTION == *"deaktiviert"* ]]; then
    DISABLED=1
  else
    DISABLED=0
  fi
  GROUP=$( echo $LINE | awk -F '#' '{ print $4 }' | cut -s -f 2 -d ',' | sed 's/ //' )
  if ( cat $OUTPUTFILE | grep -q "uid=${USERNAME}" ); then #prevent duplicates
    #:
    cat $OUTPUTFILE | grep "uid=${USERNAME}"
  else
      # Print to output file and stdout
PRINT="dn: uid=${USERNAME},ou=${OU},ou=users,dc=gertzenstein,dc=local
changetype: add
objectClass: top
objectClass: iNetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: ${USERNAME}
uid: ${USERNAME}
givenName: ${GIVENNAME}
sn: ${SN}
mail: ${USERNAME}@gertzenstein.local
homeDirectory: /home/users/${USERNAME}
loginShell: /bin/bash
uidNumber: ${COUNTER2000}
gidNumber: ${COUNTER2000}
userPassword: ${USERNAME}1234"
echo "$PRINT" && echo "$PRINT" >> $OUTPUTFILE
  if [[ $DISABLED == "1" ]]; then
    PRINTDISABLED="pwdAccountLockedTime: 000001010000Z" && echo $PRINTDISABLED >> $OUTPUTFILE && echo $PRINTDISABLED
  fi
PRINTGROUP="
dn: cn=${GROUP},ou=groups,dc=gertzenstein,dc=local
changetype: modify
add: memberUid
memberUid: ${USERNAME}
"
echo "$PRINTGROUP" && echo "$PRINTGROUP" >> $OUTPUTFILE
    (( COUNTER2000++ ))
  fi
done

echo ""
echo "Done!"
echo ""
