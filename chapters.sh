
: ${storydir:="."}
: ${diffdir:="./diffs"}

chapters=($(ls -1dH "${storydir}"/[0-9]*))
