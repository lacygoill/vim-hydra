" TODO:
" Allow the user to write `headXX` as an observation, and make the plugin expand
" it into the corresponding observation (looking in the eponym file).

let s:dir           = $XDG_RUNTIME_DIR.'/hydra'
let s:analysis_file = s:dir.'/analysis.hydra'

fu! s:all_combinations(sets) abort "{{{1
    let cbns = []
    if len(a:sets) == 2
        for i in a:sets[0]
            for j in a:sets[1]
                let cbns += [[i , j]]
                "             ^ string
            endfor
        endfor
    else
        for i in a:sets[0]
            for j in s:all_combinations(a:sets[1:])
                let cbns += [[i] + j]
                "            ^^^ list containing a string
            endfor
        endfor
    endif
    return cbns
endfu

fu! s:analyse() abort "{{{1
    " dictionary binding a list of codes to each observation
    let obs2codes = {}
    " iterate over the files such as `/run/user/1000/hydra/head01.ext`
    let heads = glob(s:dir.'/head*.*', 0, 1)
    for head in heads
        let lines = readfile(head)
        let code = matchstr(lines[0], '\d\+')
        let i = match(lines, 'Write your observation')
        let j = match(lines, 'ENDOBS$')
        let an_obs = join(lines[i+1:j-1], "\n")
        let obs2codes[an_obs] = get(obs2codes, an_obs, []) + [code]
    endfor

    exe 'e '.s:analysis_file
    setl nofoldenable nowrap
    call search('^# Observations', 'c')
    let c = 0
    " Write each observation noted in the heads files, as well as the associated
    " (syntax highlighted) codes.
    for [obs, codes] in items(obs2codes)
        " the observation is probably commented; try to guess what it is
        let cml = matchstr(obs, '\S\{1,2}\s')
        " remove it
        let obs = substitute(obs, '\%(^\|\n\)\zs'.cml, '', 'g')

        " write the observation (and make it a title)
        sil put =(c ? [''] : []) + ['## '.obs] + ['']
        " write the list of codes below;
        " we split then join back to add a space between 2 consecutive digits
        call map(codes, {i,v -> split(v, '\zs')})
        sil put =map(deepcopy(codes), {i,v -> join(v)})

        " ['1','2']     ['1','3','5']
        " ['3','4']  →  ['2','4','6']
        " ['5','6']
        let transposed_codes = call('my_lib#matrix_transposition', codes)

        " ['1','2','3']
        " ['4','4','4']  →  [0, 1, 0, 1]
        " ['5','6','7']
        " ['8','8','8']
        let invariants = map(transposed_codes, {i,v -> v == filter(deepcopy(v), {j,w -> w ==# v[0] })})
        " [0, 1, 0, 1]  →  [0, 1, 0, 3]
        let invariants = map(invariants, {i,v -> v ? i : 0})

        " add syntax highlighting for each column of identical digits
        " those are interesting invariants
        call s:create_match_invariants(codes, invariants)
        let c += 1
    endfor
    update
    setl foldenable
    return ''
endfu

fu! s:create_hydra_heads(tmpl, cbns, sets, ext, cml) abort "{{{1
    let ext = !empty(a:ext) ? '.'.a:ext : ''

    for i in range(1,len(a:cbns))
        "                      ┌ padding of `0`, so that the filenames are sorted as expected
        "                      │ when there are more than 10 possible combinations
        "                      │
        exe 'e '.s:dir.'/head'.repeat('0', len(len(a:cbns))-len(i)).i.ext
        let cbn = a:cbns[i-1]
        " compute a code standing for the current combination
        " sth like 1010
        let code = a:cml.' '.join(map(range(1, len(a:sets)),
        \                             {i,v -> index(a:sets[i], cbn[i])})
        \                         , '')
        let expanded_tmpl = s:get_expanded_template(a:tmpl, a:cbns[i-1])

        sil $put =code
        sil $put =['',
        \          a:cml.' Write your observation below (stop before ENDOBS):',
        \          a:cml.' ENDOBS',
        \          '']
        sil $put =expanded_tmpl
        0d_
        update
    endfor

    " populate arglist with all generated files
    exe 'args '.join(glob(s:dir.'/head*'.ext, 0, 1))
    first
    " enable statusline item showing position in the arglist
    let g:my_stl_list_position = 2
    let g:motion_to_repeat = ']a'
endfu

fu! s:create_match_invariants(codes, invariants) abort "{{{1
    " Add `~` characters around invariant digits, so that they are
    " syntax highlighted.

    let lline = line('.')
    let fline = lline - len(a:codes) + 1
    " Why `reverse()`?{{{
    "
    " Whenever we add  an `~` character, for syntax highlighting,  we change the
    " column position of the next digit to highlight.
    " We don't  want to re-compute  this position,  so we process  the invariant
    " digits in reverse order.
    "}}}
    for vcol in reverse(a:invariants)
        " We could filter `a:invariants`, but I prefer not to,
        " because it would break the alternative method (addind markers `v ^`).
        if vcol == 0
            continue
        endif
        let coords = map(range(fline, lline), {i,v -> [v, 2*vcol+1]})
        for coord in coords
            exe 'sil keepj keepp %s/\%'.coord[0].'l\%'.coord[1].'v./\~&\~/e'
        endfor
    endfor
    " Alternative:{{{
    " Instead of creating a match, you can also add a marker.
    "
    " " [0, 1, 0, 1]  →  [' ', '^', ' ', '^']
    " call map(a:invariants, {i,v -> v ? '^' : ' '})
    " " ' ^ ^'
    "
    " sil put =matchstr(join(a:invariants), '\v.*\s@<!')
    " "        │
    " "        └ trim ending whitespace if any
    "
    " norm! {
    " " ' ^ ^'  →  ' v v'
    "
    " sil put =matchstr(join(map(invariants, {i,v -> v ==# '^' ? 'v' : ' '})), '\v.*\s@<!')
    "
    " norm! }k
    " "      ^ important to get back exactly on the line where we wrote
    " "        ' ^ ^'
    "}}}
endfu

fu! s:empty_dir() abort "{{{1
    call map(glob(s:dir.'/*', 0, 1),
    \        {i,v -> (bufexists(v) && execute('bwipe! '.v)) + delete(v)})
    " Why do we need to delete a possible buffer?{{{
    "
    " If a buffer exists, when we'll do `:e fname`, even if the file is deleted,
    " Vim will load the buffer with its old undesired contents.
    "}}}
    " Why do we need to write `bufexists(v) && execute(…)` inside parentheses?{{{
    "
    " Because  the `+`  operator has  priority over  `&&`, and  here we  want to
    " change the priority:
    "
    "            bufexists(v) && execute('bwipe! '.v) + delete(v)
    "         ⇔  if the buffer exists, delete both the buffer and the file
    "
    "            ⇒ if the buffer doesn't exist,  but the file does, the latter
    "              is not deleted ✘
    "
    "           (bufexists(v) && execute('bwipe! '.v)) + delete(v)
    "         ⇔  if the buffer exists, delete it, then no matter what, delete the file    ✔
    "}}}
endfu

fu! s:get_dlm_addr(line1,line2) abort "{{{1
    "   ┌ delimiters addresses:
    "   │
    "   │       addresses of `---` lines inside the range
    "   │     + last line of the range
    let dlm_addr = []
    call cursor(a:line1, 1)
    while search('^---$', 'W') && line('.') <= a:line2
        let dlm_addr += [ line('.') ]
    endwhile

    " Make the code work  even if we added an unnecessary `---`  line at the end
    " of the range.
    if getline(a:line2) ==# '---'
        let dlm_addr[-1] -= 1
    else
        let dlm_addr += [ a:line2 ]
    endif

    return dlm_addr
endfu

fu! s:get_expanded_template(tmpl, cbn) abort "{{{1
    let texts = split(a:tmpl, '%s\zs')
    " Replace  each `%s`  item with  the appropriate  text, escaping  characters
    " which have a special meaning in  the replacement part of a substitution:
    "
    "         \ ~ &
    "
    " Why checking that there's a `%s` item? Shouldn't there always be one?{{{
    "
    " Not necessarily. Watch:
    "
    "     foo %s bar %s baz
    "
    "     → foo %s
    "       bar %s
    "       baz     (no `%s` item)
    "}}}
    call map(texts, {j,v -> v =~# '%s'
    \?                          substitute(v, '%s', escape(a:cbn[j], '\~&'), '')
    \:                          v })
    " join the texts and trim ending whitespace on each line
    return substitute(join(texts, ''), '\v\zs\s*\ze%($|\n)', '', 'g')
endfu

fu! s:get_sets(dlm_addr) abort "{{{1
    let sets = []
    for i in range(1, len(a:dlm_addr)-1)
        let set   = filter(getline(a:dlm_addr[i-1], a:dlm_addr[i]), {i,v -> v !=# '---'})
        let sets += [ set ]
    endfor
    return sets
endfu

fu! s:get_template(line1) abort "{{{1
    " return all the lines between the first in the range,
    " and the next `---` line

    call cursor(a:line1, 1)
    " if the first line of the range is `---`, don't include
    " it in the template
    let fline = getline(a:line1) ==# '---'
    \?              a:line1 + 1
    \:              a:line1
    let template = join(getline(fline, search('^---$', 'nW')-1), "\n")
    return template
endfu

fu! hydra#main(line1,line2) abort "{{{1
    try
        let orig_id = win_getid()
        let view    = winsaveview()
        let ext     = expand('%:e')
        let cml     = get(split(&l:cms, '%s'), 0, '')

        let template = s:get_template(a:line1)
        if empty(matchstr(template, '%s'))
            return s:msg('Provide a template')
        endif

        " get the addresses of all the lines which consider as “delimiters”;
        " that is `---` lines + last line in the range
        let dlm_addr = s:get_dlm_addr(a:line1,a:line2)

        " check the range of lines looks valid;
        " i.e. has at least 2 `---` lines
        if len(dlm_addr) == 1
            return s:msg('No delimiter (---) line')
        elseif len(dlm_addr) == 2
            return s:msg('Not enough delimiter (---) lines')
        endif

        " the lines between 2 consecutive `---` lines compose a set;
        " get all of them
        let sets = s:get_sets(dlm_addr)
        " check the range of lines looks valid;
        " i.e. has as many sets as there are `%s` items in the template
        if len(sets) < count(template, '%s')
            return s:msg('Too many %s items')
        elseif len(sets) > count(template, '%s')
            return s:msg('Too few %s items')
        endif

        " we can create a  new set of lines, each of which come  from one of the
        " previous sets; get all of those new sets
        let cbns = s:all_combinations(sets)
        "   ^ combinations
        if !isdirectory(s:dir)
            call mkdir(s:dir, 'p')
        else
            call s:empty_dir()
        endif

        tabnew
        call s:create_hydra_heads(template, cbns, sets, ext, cml)
        call s:prepare_analysis(sets)
        e# | vs# | wincmd p
        "│     │   │
        "│     │   └ get back to head file
        "│     └ split window vertically, and load analysis file
        "└ load head file
    catch
        return my_lib#catch_error()
    finally
        call s:winrestview(view, orig_id)
    endtry
    return ''
endfu

fu! s:msg(msg) abort "{{{1
    return 'echoerr '.string(a:msg)
endfu

fu! s:prepare_analysis(sets) abort "{{{1
    exe 'e '.s:analysis_file

    sil $put=['# Code meaning']
    let i = 1
    let ordinals = {'1': '1st', '2': '2nd', '3': '3rd'}
    for a_set in deepcopy(a:sets)
        let ordinal = i <= 3 ? ordinals[i] : i.'th'
        $put =['## '.ordinal.' digit', '']
        call map(a_set, {i,v -> '~'.i.'~  '.(empty(v) ? '∅' : v)})
        sil $put =a_set + ['']
        let i += 1
    endfor

    sil $put=['# Observations', '',
    \         '# Conclusion', '',
    \         'Describe the heads according to their invariants:', '']

    0d_
    update

    com! -bar -buffer -range=% HydraAnalyse  exe s:analyse()
endfu

fu! s:winrestview(view, orig_id) abort "{{{1
    let now_id = win_getid()
    call win_gotoid(a:orig_id)
    call winrestview(a:view)
    call win_gotoid(now_id)
endfu
