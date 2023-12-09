#!/usr/bin/awk -f

BEGIN {
    getline
    if(ERRNO) {
        print(ERRNO)
        exit 1
    }
    # fill in seeds
    for (i = 2; i <= NF; i+=2) {
        tr[i - 2, "start"] = $i # seed range begin
        tr[i - 2, "len"] = $(i + 1) # seed range length
    }
    nseedranges = (NF - 1) / 2
}

/[0-9]+/ { # inside something-to-somethingElse map
    mapto[nmaps, "srcstart"] = $2 # source range start
    mapto[nmaps, "dststart"] = $1 # destination range start
    mapto[nmaps, "len"] = $3 # ranges length
    nmaps++
}

function setSourceRanges() {
    start = tr[i, "start"]
    len = tr[i, "len"]
    end = start + len - 1
}
function setMappingRanges() {
    rlen = mapto[j, "len"]
    srcstart = mapto[j, "srcstart"]
    srcend = srcstart + rlen - 1
    deststart = mapto[j, "dststart"]
}

/^$/ { # end of something-to-somethingElse map
    # check every mapping rule for every seed range. update if rule found
    for (i = 0; i < nseedranges; i++) {
        setSourceRanges()
        for (j = 0; j < nmaps; j++) {
            setMappingRanges()

            # need to split range? ->
            # ranges intersect IFF start < srcend && end > srcstart
            if (start < srcend && end > srcstart &&
                start < srcstart) {
                # end of seed range intersects, example
                # 0, 10 meets 5, 11 -> 0, 4 || 5, 10
                # 0,+11 meets 5,+7  -> 0,+5 || 5,+6
                tr[i, "start"] = srcstart
                tr[i, "len"] = end - srcstart + 1
                tr[nseedranges, "start"] = start
                tr[nseedranges, "len"] = len - tr[i, "len"]
                setSourceRanges()
                nseedranges++
            }
                # can be both if tr range is larger than map rule
            if (start < srcend && end > srcstart &&
                end > srcend) {
                # start of seed range intersects, example:
                # 1, 10 meets 0, 5 -> 1, 5 || 6, 10
                # 1,+11 meets 0,+6 -> 1,+4 || 6,+5
                tr[i, "len"] = srcend - start + 1
                tr[nseedranges, "start"] = srcend + 1
                tr[nseedranges, "len"] = len - tr[i, "len"]
                nseedranges++
            }

            if (tr[i, "start"] >= mapto[j, "srcstart"] &&
                tr[i, "start"] < mapto[j, "srcstart"] + mapto[j, "len"]) {
                tr[i, "start"] +=  mapto[j, "dststart"] - mapto[j, "srcstart"]
                break
            }
        }
    }

    delete mapto
    nmaps = 0
}

END {
    for (i = 0; i < nseedranges; i++)
        printf("#%4d -> %15d, %15d\n", i, tr[i, "start"], tr[i, "len"])

    min = tr[0, "start"]
    for (i = 1; i < nseedranges; i++)
        if (min > tr[i, "start"])
            min = tr[i, "start"]
    print("nearest location: " min)
}
