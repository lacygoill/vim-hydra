if exists('g:loaded_hydra')
    finish
endif
let g:loaded_hydra = 1

" TODO: Create documentation file.
" Move the `Purpose` section there.

" TODO: In `analysis.hydra`,  you could  install custom mappings  on `C-a`/`C-x`
" which would cycle through previous  observations.  This way, you wouldn't have
" to copy-paste them from an old head file to the current one.
"
" ---
"
" But  you would  still  need to  alt-tab  twice  after each  test  to write  an
" observation into a head file, then get back to the next test.
" To improve a  little, you could tweak  your zsh snippet, and the  tip given in
" the documentation of this file:
"
"     for f in /run/user/1000/vim/hydra/head*.vim; do vim -Nu "$f" + "echom '$f'"; \
"         if [[ $? != 0 ]]; then break; fi; done
"
" The idea is that  you could install a `C-a` mapping in  a Vim instance started
" for a  test; it  would send  a `C-a` keypress  to the  main Vim  instance (via
" `--remote-expr`).  That would require a few things:
"
"    - maybe install a mapping which lets us send an arbitrary observation to the
"      current head file in the Vim server (consider a similar key binding in the
"      shell when we're not testing Vim but sth else; the test will presumably be
"      scripted from the shell)
"
"    - when quitting a testing Vim instance, make the Vim server automatically load
"      the next head file (iow, the current test and the current head file should be
"      automatically synchronized)
"
"      same thing when your test doesn't involve a Vim instance, but a shell script
"
"    - when loading the next head file, automatically use the observation written
"      in the previous head file
"
"    - in the Vim server, install buffer-local mappings on `C-a`/`C-x` to cycle through
"      past observations
"
" Use `--remote-*` to communicate with the Vim server where the head files are loaded.

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
" nno        cd :call Func()<cr>
" nno <expr> cd       Func()
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
"     for f in /run/user/1000/vim/hydra/head*.vim; do vim -Nu "$f" + "echom '$f'"; \
"         if [[ $? != 0 ]]; then break; fi; done
"
" The loop will start Vim once for each `headXX.vim` file, sourcing the latter.
" Make your  test and quit with  `ZZ`.  If something  is wrong, and you  want to
" cancel the remaining tests, quit with `:cq`.

" Commands {{{1

com -bar -range=% Hydra exe hydra#main(<line1>,<line2>)
