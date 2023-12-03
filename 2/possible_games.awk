#!/usr/bin/awk -f
BEGIN {
    sum = 0
}

# filter out 13 red, 14 red , .... (>12) red
# and >13 green
# and >14 blue
{
    if ($0 !~ /0*(1[3-9]|[2-9][0-9]|[1-9][0-9]{2,}) red/ &&
        $0 !~ /0*(1[4-9]|[2-9][0-9]|[1-9][0-9]{2,}) green/ &&
        $0 !~ /0*(1[5-9]|[2-9][0-9]|[1-9][0-9]{2,}) blue/) {
        sum += NR # NR == to game id
    }
}

END {
    print("total IDs: " sum)
}
