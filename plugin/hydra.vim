" Purpose {{{1
"
" This code will  be useful to understand what are  the necessary and sufficient
" conditions for some code to work as expected.
"
"     1. Generate all the possible commands/scripts which could execute the
"        desired action.
"
"     2. Test each of them, and note the results.
"
"     3. Regroup the commands/scripts which have the same result.
"
"     4. Find invariants in them.
"
"     5. Deduce the necessary and sufficient conditions to produce each result
"        you've seen.
"
"     6. Note these as rules.

" Examples {{{1

" To test, uncomment first.

" Example1:

"" mapping:
" %s
"" option:
" %s
"" message:
" %s
" ---
" nno <expr> cd        Func()
" nno        cd  :call Func()<cr>
" ---
" set lz
" set nolz
" ---
" echo 'hello'
" call timer_start(0, {-> execute('echo "hello"', '')})

" Example2:

" cmd %s %s %s
" ---
"
" -a
" ---
"
" -b
" ---
"
" -c

" Note:
" An empty line means that the option can be absent.

" Command {{{1

com! -bar -range=% Hydra exe hydra#main(<line1>,<line2>)

