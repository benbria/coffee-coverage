

counter = 0

`_l_1: //`
for x in [1..10]
    console.log x
    if counter == 10
        break
    `_$l_2: //`
    for y in [1..10]
        console.log y
        if y == 5 and counter < 10
            counter++
            `continue _l_1`
        `continue _$l_2`

