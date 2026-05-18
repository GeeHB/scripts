
PROTECTED_KERNEL="5.11.5"

# strpos
#   Recherche d'une sous chaine dans une chaine
#
#   $1 : Chaine
#   $2 : sous chaine recherchée
#
#   ret : index ou -1
strpos(){
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}

# Kernel protégé ?
k=$(uname -r)

pos=$(strpos "$k" "$PROTECTED_KERNEL")
if [ $pos = 0 ]; then
    # Oui !!!
    export PS1="\[$(tput bold)\][$(tput setaf 1)\]\u@\h\[$(tput setaf 4)\] \W\[$(tput sgr0)\]]\\$ "
else
    export PS1="[\[$(tput setaf 2)\]\u\[$(tput sgr0)\]@\h\[$(tput bold)\]\[$(tput setaf 4)\] \W\[$(tput sgr0)\]]\\$ "
fi