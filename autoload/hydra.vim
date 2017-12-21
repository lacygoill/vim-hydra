fu! s:all_combinations(sets) abort "{{{1
    let cbns = []
    if len(a:sets) == 2
        for i in a:sets[0]
            for j in a:sets[1]
                let cbns += [[i , j]]
            endfor
        endfor
    else
        for i in a:sets[0]
            for j in s:all_combinations(a:sets[1:])
                let cbns += [[i] + j]
            endfor
        endfor
    endif
    return cbns
endfu

fu! s:create_hydra_heads(dir, tmpl, cbns) abort "{{{1
    tabnew
    for i in range(1,len(a:cbns))
        "                      ┌ padding of `0`, so that the filenames are sorted as expected
        "                      │ when there are more than 10 possible combinations
        "                      │
        exe 'e '.a:dir.'/head'.repeat('0', len(len(a:cbns))-len(i)).i
        let text = s:get_expanded_template(a:tmpl, a:cbns[i-1])
        sil 0put =text
        $d_
        update
    endfor
    exe 'Dirvish '.a:dir
    1
endfu

fu! s:empty_dir(dir) abort "{{{1
    call map(glob(a:dir.'/*', 0, 1),
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
    return join(texts, '')
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

        let template = s:get_template(a:line1)
        if empty(matchstr(template, '%s'))
            return s:msg('Provide a template')
        endif

        let dlm_addr = s:get_dlm_addr(a:line1,a:line2)

        if len(dlm_addr) == 1
            return s:msg('No delimiter (---) line')
        elseif len(dlm_addr) == 2
            return s:msg('Not enough delimiter (---) lines')
        endif

        let sets = s:get_sets(dlm_addr)
        if len(sets) < count(template, '%s')
            return s:msg('Too many %s items')
        elseif len(sets) > count(template, '%s')
            return s:msg('Too few %s items')
        endif

        let cbns = s:all_combinations(sets)
        let dir  = $XDG_RUNTIME_DIR.'/hydra'
        if !isdirectory(dir)
            call mkdir(dir, 'p')
        else
            call s:empty_dir(dir)
        endif
        call s:create_hydra_heads(dir, template, cbns)
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

fu! s:winrestview(view, orig_id) abort "{{{1
    let now_id = win_getid()
    call win_gotoid(a:orig_id)
    call winrestview(a:view)
    call win_gotoid(now_id)
endfu
