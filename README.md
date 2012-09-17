Nested Loop Parser Library
==========================

`parse_nest_loop` parses an input string that contains `<>` notation to indicate
nested loops. 

Syntax
------
- `<n-m>` means loop from `n` to `m`, `<<n-m>>` means an inner-loop.
- The number of `<` is the nested level
- Multiple levels of loops, and multiple loops of the same levels
can exist together. 
- Same level of loops can have different number of
iteration times. 
- The loop ends when the longest loop in the same
level ends. The shorter loop will continue from beginning.

Example
-------
`parse_nest_loop "1<0-5>.<<1-5>>" ` returns:
     10.1, 10.2, ..., 10.5,
     11.1, 11.2, ..., 11.5,
     ...
     15.1, 15.2, ..., 15.5

`parse_nest_loop "<0-5><0-3>" ` returns:
      00 11 22 33 40 51
