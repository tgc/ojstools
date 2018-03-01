#!/bin/bash
#
# Do key checks on a OJS locale files

# Global arrays to hold keys
declare -A rkeys
declare -A ckeys
# Defaults
dups=0
missing=0
obsolete=0
delete=0
copy=0
locale=da_DK

print_usage() {
    echo "Usage: $(basename $0) [ -u ] [ -m ] [ -o [ -d ] ] [ -e ] [ -l <locale> ]"
    echo
    echo "-u	check for duplicate keys (checks both reference and target (-l) locale"
    echo "-m	check for missing keys"
    echo "-o	check for obsolete keys"
    echo "-d	remove obsolete keys (noop without -o)"
    echo "-e	check for messages copied verbatim"
    echo "-l	the locale to check (default is $locale)"
    echo
}

main() {
    # Find all catalogs
    for catalog in $(find . -type d -name "$locale" | grep -v help  | xargs -n 1 -i find {} -type f)
    do
	# Reset the arrays
	ckeys=()
	rkeys=()
	# Reference is here
	reference=${catalog/$locale/en_US}
	# Load the catalog keys
	for key in $(sed -n 's|.*<message key="\([^"]*\)">\(.*\)|\1|p' $catalog)
	do
	    if [ -z "${ckeys[$key]}" ]; then
		ckeys[$key]=1
	    else
		ckeys[$key]=$((ckeys[$key]+1))
	    fi
	done
	# Load the reference keys
	if [ -r $reference ]; then
	    for key in $(sed -n 's|.*<message key="\([^"]*\)">\(.*\)|\1|p' $reference)
	    do
		if [ -z "${rkeys[$key]}" ]; then
		    rkeys[$key]=1
		else
		    rkeys[$key]=$((rkeys[$key]+1))
		fi
	    done
	else
	    echo "WARNING: could not find reference for $catalog"
	fi
	# Check for duplicates and list them if found
	if [ $dups -eq 1 ]; then
	    for key in ${!ckeys[@]};
	    do
		if [ ${ckeys[$key]} -gt 1 ]; then
		    echo "DUPLICATE: $key in $catalog"
		    grep "<message key=\"$key\"" $catalog
		fi
	    done
	    for key in ${!rkeys[@]};
	    do
		if [ ${rkeys[$key]} -gt 1 ]; then
		    echo "DUPLICATE: $key in $reference"
		    grep "<message key=\"$key\"" $reference
		fi
	    done
	fi
	# Check for missing translations
	if [ $missing -eq 1 ]; then
	    for key in ${!rkeys[@]};
	    do
		if [ -z ${ckeys[$key]} ]; then
		    echo "MISSING: $key in $catalog"
		fi
	    done
	fi
	# Check for obsolete keys
	if [ $obsolete -eq 1 ]; then
	    for key in ${!ckeys[@]};
	    do
		if [ -z ${rkeys[$key]} ]; then
		    echo "OBSOLETE: $key in $catalog"
		    if [ $delete -eq 1 ]; then
			# Single line key
			sed -i "/<message key=\"$key\">.*<\/message>/d" $catalog
			# Multiline key
			sed -i "/<message key=\"$key\">/,/<\/message>/d" $catalog
		    fi
		fi
	    done
	fi
	# Check for translations copied verbatim from the reference
	if [ $copy -eq 1 -a -r $reference ]; then
	    for key in ${!ckeys[@]};
	    do
		# Single line key
		ref="$(sed -n "/<message key=\"$key\">.*<\/message>/p" $reference)"
		cat="$(sed -n "/<message key=\"$key\">.*<\/message>/p" $catalog)"
		# No? Try multiline
		[ -z "$ref" ] && ref="$(sed -n "/<message key=\"$key\">/,/<\/message>/p" $reference)"
		[ -z "$cat" ] && cat="$(sed -n "/<message key=\"$key\">/,/<\/message>/p" $catalog)"

		if [ "$cat" = "$ref" ]; then
		    echo "COPIED: $key in $catalog"
		    echo "$ref"
		    echo
		fi
	    done
	fi
    done
}

# Parse command line
if [ $# -gt 0 ]; then
    while getopts umodel: opt
    do
        case $opt in
            u)
                dups=1;;
	    m)
		missing=1;;
	    o)
		obsolete=1;;
	    d)
		delete=1;;
	    e)
		copy=1;;
	    l)
		locale=$OPTARG;;
	    \?|h)
                print_usage
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))
else
    print_usage
    exit 1
fi

# Go
main
