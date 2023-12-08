#!/usr/bin/awk -f

BEGIN {
    getline
    if(ERRNO) {
        print(ERRNO)
        exit 1
    }
    # fill in seeds
    for (i = 2; i <= NF; i++) {
        seeds[i - 2] = $i
        tr[i -2] = $i # translation table
    }
}

/[0-9]+/ { # inside something-to-somethingElse map
    mapto[nmaps, 0] = $2 # source range start
    mapto[nmaps, 1] = $1 # destination range start
    mapto[nmaps, 2] = $3 # ranges length
    nmaps++
}

/^$/ { # end of something-to-somethingElse map
    # check every mapping rule for every seed. update if rule found
    for (i = 0; i < length(seeds); i++) {
        #print("translating " tr[i])
        for (j = 0; j < nmaps; j++) {
            #print(mapto[j, 0] ", " mapto[j, 1] ", " mapto[j, 2])
            if (tr[i] >= mapto[j, 0] && tr[i] < mapto[j, 0] + mapto[j, 2]) {
                tr[i] = tr[i] - mapto[j, 0] + mapto[j, 1]
                break
            }
        }
        #print("result = " tr[i])
    }

    delete mapto
    nmaps = 0
}

END {
    for (i = 0; i < length(seeds); i++)
        printf("%15d -> %15d\n", seeds[i], tr[i])

    min = tr[0]
    for (idx in tr)
        if (min > tr[idx])
            min = tr[idx]
    print("nearest location: " min)
}
