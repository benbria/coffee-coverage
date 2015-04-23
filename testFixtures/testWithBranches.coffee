

a = false
b = null
c = true


# 1. single line standard boolean expressions
r11 = a || b || c


# 2. single line coffee script boolean expressions

r21 = if a or b then c else a


r2 = if a
   a
else if b
   b
else if c
   c
else
   null


r3 = if a or
        b
    c




if a
   a
else if b
   b
else if c
   c
else
   null


unless a
   a


f = ->


f() unless a or b or
           c



