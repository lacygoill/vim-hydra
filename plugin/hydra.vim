if exists('g:loaded_hydra')
    finish
endif
let g:loaded_hydra = 1

" TODO: Create documentation file.
" Move the `Purpose` section there.

" TODO: In `analysis.hydra`,  you could  install custom mappings  on `C-a`/`C-x`
" which would cycle  across previous observations.  This way,  you wouldn't have
" to copy-paste them from an old head file to the current one.

" Purpose {{{1
"
" This code will  be useful to understand what are  the necessary and sufficient
" conditions for some code to work as expected.
"
"    1. Generate all the possible commands/scripts which could execute the
"       desired action.
"
"    2. Test each of them, and note the results.
"
"    3. Regroup the commands/scripts which have the same result.
"
"    4. Find invariants in them.
"
"    5. Deduce the necessary and sufficient conditions to produce each result
"       you've seen.
"
"    6. Note these as rules.

" Examples {{{1
"
" To test, uncomment first.
"
" Example1:
"
" set %s
" %s
" fu Func() abort
"     %s
"     %s
"     return ''
" endfu
" ---
" nolz
" lz
" ---
" nno          cd  :call Func()<cr>
" nno  <expr>  cd        Func()
" ---
"
" redraw
" call timer_start(5, {-> execute('redraw', '')})
" ---
" echo 'hello'
" call timer_start(0, {-> execute('echo "hello"', '')})
"
" Example2:
"
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
"
" Note: An empty line means that the option can be absent.
"
" Tip: To test more quickly, run this shell command:
"
"     for f in /run/user/1000/vim/hydra/head*.vim; do vim -Nu "$f" --cmd "echom '$f'"; \
"         if [[ $? != 0 ]]; then break; fi; done
"
" The loop will start Vim once for each `headXX.vim` file, sourcing the latter.
" Make your  test and quit with  `ZZ`.  If something  is wrong, and you  want to
" cancel the remaining tests, quit with `:cq`.

" Commands {{{1

com -bar -range=% Hydra exe hydra#main(<line1>,<line2>)
