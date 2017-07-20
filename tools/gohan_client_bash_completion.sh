#!/bin/bash


commands="list show create set delete"
verbosity="0 1 2"
outputFormat="json table"
gohanCommandPos=1
unnamedCommandWords="show set delete"
getUnnamedProperties()
{
schema_id=$1
OIFS=$IFS
IFS=$'\n' arr=`${COMP_WORDS[0]} client $schema_id list`
wasProperties=0
counter=0
unnamed=""
for a in $arr
do
        cop=$a
        replacewhat="-"
        replacewith=""
        replacewhat2="+"
        result="${cop//$replacewhat/$replacewith}"
        result="${result//$replacewhat2/$replacewith}"
        let counter=counter+1
        if [  -z $result ] ; then
        continue
        fi
        if [[ $counter -gt 2 ]];then
        args=$(echo $a | tr "|" "\n")
        sub=0
        for i in $args
        do

            let sub=sub+1
            if [ $sub -eq 1 ] && [ ! -z "${i// }" ] ; then
        		i="$(echo -e "${i}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
                unnamed="$i $unnamed"	
            fi
        done
        fi
done
}

getProperties()
{
named="--output-format --verbosity --fields"
fields=""
schema_id=$1
OIFS=$IFS
IFS=$'\n' arr=`${COMP_WORDS[0]} client $schema_id`
wasProperties=0
for a in $arr
do
     if [[ wasProperties -eq 1 ]] ; then
         curvar=`echo $a | awk '{print $2}'`
         if [[ -z "${curvar// }" ]] ; then
             return
         else
             curvar="$(echo -e "${curvar}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
             named="$named --$curvar"
             fields="$fields $curvar"
        fi
     fi
     if [[ $a == *"Properties:"* ]] ; then
         wasProperties=1
     elif [[ -z "${a// }" ]] ; then
         wasProperties=0
     fi
done
}

getAllSchemas()
{
OIFS=$IFS
IFS=$'\n'
array=`${COMP_WORDS[0]} client`
schemasArr=()
schemas=""
for curLine in $array
do
	IFS='#' read -r -a arr <<< "$curLine"
	curSchema_id=`echo $arr | cut -d " " -f 3`
	schemasArr+=("$curSchema_id")
done

for i in "${schemasArr[@]}"
do
    i="$(echo -e "${i}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	schemas="$schemas $i"
done
IFS=$OIFS
}

bashCompletion()
{
local cur prev opts
COMPREPLY=()
cur="${COMP_WORDS[COMP_CWORD]}"
prev="${COMP_WORDS[COMP_CWORD-1]}"
c=" "
let "c=(${COMP_CWORD}+$gohanCommandPos) % 2"
if [[ "${COMP_CWORD}" -lt $((gohanCommandPos+1)) ]] ; then
    return 0
fi
if [[ "${COMP_WORDS[0]}" != "gohan" ]] &&  [[ "${COMP_WORDS[1]}" != "client" ]] ; then
    return 0
fi
if [[ `${COMP_WORDS[0]} client` == "Environment variable GOHAN_SERVICE_NAME needs to be set" ]] ; then
    return 0
fi
if [[ "${COMP_CWORD}" -eq $((gohanCommandPos+1)) ]] ; then
	getAllSchemas
    COMPREPLY=( $(compgen -W "${schemas}" -- ${cur}) )
     return 0
elif [[ "${COMP_CWORD}" -eq $((gohanCommandPos+2)) ]] ; then
	COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
	return 0
elif [[ "${COMP_CWORD}" -gt $((gohanCommandPos+2)) ]] && [[ c -eq 1 ]] &&  [[ "${cur}" == -* ]] ; then
	schema_id="${COMP_WORDS[$((gohanCommandPos+1))]}"
	getProperties $schema_id
	IFS=$OIFS
	COMPREPLY=( $(compgen -W "${named}" -- ${cur} ) )
	return 0
elif [[ "${COMP_CWORD}" -gt $((gohanCommandPos+2)) ]] && [[ c -eq 1 ]] && [[ "${cur}" != -* ]] ; then
    toShow=0
    curCommand="${COMP_WORDS[3]}"
    [[ $unnamedCommandWords =~ (^|[[:space:]])$curCommand($|[[:space:]]) ]] && toShow=1 || toShow=0
    if [[ $toShow == 0 ]]; then
        return 0
    fi
	device="${COMP_WORDS[$((gohanCommandPos+1))]}"
	getUnnamedProperties $device 
	IFS=$OIFS
	COMPREPLY=( $(compgen -W "${unnamed}" -- ${cur}) )
	return 0
elif [[ "${COMP_CWORD}" -gt $((gohanCommandPos+2)) ]] && [[ c -eq 0 ]] && [[ "${prev}" == "--fields" ]] ; then
	getProperties "${COMP_WORDS[$((gohanCommandPos+1))]}"
    IFS=$OIFS
    COMPREPLY=( $(compgen -W "${fields}" -- ${cur}) )
    return 0
elif [[ "${COMP_CWORD}" -gt $((gohanCommandPos+2)) ]] && [[ c -eq 0 ]] && [[ "${prev}" == "--verbosity" ]] ; then
    COMPREPLY=( $(compgen -W "${verbosity}" -- ${cur}) )
    return 0
elif [[ "${COMP_CWORD}" -gt $((gohanCommandPos+2)) ]] && [[ c -eq 0 ]] && [[ "${prev}" == "--output-format" ]] ; then
    COMPREPLY=( $(compgen -W "${outputFormat}" -- ${cur}) )
    return 0

fi
}
complete -F bashCompletion gohan client 
