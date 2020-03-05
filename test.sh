banner_pad=$( printf '%0.1s' " "{1..80})
function banner_bar ()
{
    printf '%0.1s' "#"{1..80}
    printf "\n"
}

function banner_head ()
{
    # line is divided like so # <- a -> b <- c ->#
    # b is the string to display centered
    # a and c are whitespace padding to center the string
    _b="${*}"
    _a=$(( ( 78 - ${#_b} ) / 2 )) 
    _c=$(( 78 - ${_a} - ${#_b} ))
    printf "#"
    printf '%*.*s' 0 ${_a} "${banner_pad}" 
    printf "${_b}"
    printf '%*.*s' 0 ${_c} "${banner_pad}" 
    printf "#\n"
}

function banner ()
{
    banner_bar
    banner_head "${*}"
    banner_bar
}

banner "this is it"
