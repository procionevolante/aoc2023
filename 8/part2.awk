#!/bin/awk -f

BEGIN {
    getline
    # read navigation instructions
    for (i = 0; i < length($1); i++)
        instr[i] = substr($1, i + 1, 1)

    parallel = 0
}

# load lines like this : AAA = (BBB, CCC)
/=/ { # load map
    map[$1, "L"] = gensub(/[\(\),]/, "", "g", $3)
    map[$1, "R"] = gensub(/[\(\),]/, "", "g", $4)

    if ($1 ~/A$/) { # record starting tile
        now[parallel] = $1
        parallel++
    }
}

function gcd(a, b) 
{ 
    if (a == 0) 
        return b; 
    return gcd(b % a, a); 
} 
  
# function to calculate 
# lcm of two numbers. 
function lcm(a, b) 
{ 
    return (a * b) / gcd(a, b); 
}

END {
    for (key in now) {
        print("path of ghost #" key ":")
        steps[key] = 0

        while (now[key] !~ /Z$/) { # continue until arrived
            lr = instr [steps[key] % length(instr)]
            steps[key]++
            willgo = map[now[key], lr]

            print(steps[key]": " now[key] " -(" lr ")-> " willgo)
            now[key] = willgo
        }
        print("ghost #" key " needs " steps[key] " steps to exit the desert")
    }

    print("summary: ")
    for (key in steps)
        print("ghost #" key " needs " steps[key] " steps to exit the desert")
    print("least commond denominator of these values will be the overall step#")
    print("of when the 6 ghosts meet")

    minsteps = steps[0]
    for (i = 1; i < length(steps); i++)
        minsteps = lcm(minsteps, steps[i])
    print("LCM = " minsteps)
}
