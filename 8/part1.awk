#!/bin/awk -f

BEGIN {
    getline
    # read navigation instructions
    for (i = 0; i < length($1); i++)
        instr[i] = substr($1, i + 1, 1)

    start= "AAA"
    target = "ZZZ"
}

# load lines like this : AAA = (BBB, CCC)
/=/ { # load map
    map[$1, "L"] = gensub(/[\(\),]/, "", "g", $3)
    map[$1, "R"] = gensub(/[\(\),]/, "", "g", $4)
}

END {
    steps = 0
    now = start
    while (now != target) {
        lr = instr[steps % length(instr)]
        willgo = map[now, lr]
        print(now " -(" lr ")-> " willgo)
        now = willgo
        steps++
    }
    print("it took " steps " step(s) to reach " target)
}
