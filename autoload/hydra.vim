vim9script noclear

# Init {{{1

import MatrixTransposition from 'lg/math.vim'

var DIR: string = getenv('XDG_RUNTIME_VIM') ?? '/tmp'
DIR ..= '/hydra'
const ANALYSIS_FILE: string = DIR .. '/analysis.hydra'

# Interface {{{1
def hydra#main(line1: number, line2: number) #{{{2
    var orig_id: number = win_getid()
    var view: dict<number> = winsaveview()
    var ext: string = expand('%:e')
    var cml: string = &commentstring->matchstr('\S*\ze\s*%s')

    var template: string = GetTemplate(line1)
    if template->matchstr('%s')->empty()
        Error('Provide a template')
        return
    endif

    # get the addresses of all the lines which consider as “delimiters”;
    # that is `---` lines + last line in the range
    var dlm_addr: list<number> = GetDlmAddr(line1, line2)

    # check the range of lines looks valid;
    # i.e. has at least 2 `---` lines
    if len(dlm_addr) == 1
        Error('No delimiter (---) line')
        return
    elseif len(dlm_addr) == 2
        Error('Not enough delimiter (---) lines')
        return
    endif

    # the lines between 2 consecutive `---` lines compose a set;
    # get all of them
    var sets: list<list<string>> = GetSets(dlm_addr)
    # check the range of lines looks valid;
    # i.e. has as many sets as there are `%s` items in the template
    if len(sets) < count(template, '%s')
        Error('Too many %s items')
        return
    elseif len(sets) > count(template, '%s')
        Error('Too few %s items')
        return
    endif

    # we can create a  new set of lines, each of which come  from one of the
    # previous sets; get all of those new sets
    var cbns: list<list<string>> = AllCombinations(sets)
    #   ^ combinations
    if !isdirectory(DIR)
        mkdir(DIR, 'p', 0o700)
    else
        EmptyDir()
    endif

    tabnew
    CreateHydraHeads(template, cbns, sets, ext, cml)
    PrepareAnalysis(sets)
    # load head file
    edit %%
    # split window vertically, and load analysis file
    vsplit %%
    # get back to head file
    wincmd p
    win_execute(orig_id, 'winrestview(' .. string(view) .. ')')
    new_obs = []
enddef
var new_obs: list<string>
#}}}1
# Core {{{1
def GetTemplate(line1: number): string #{{{2
    # return all the lines between the first in the range,
    # and the next `---` line

    cursor(line1, 1)
    # if the first line of the range is `---`, don't include
    # it in the template
    var fline: number = getline(line1) == '---'
        ?     line1 + 1
        :     line1
    return getline(fline, search('^---$', 'nW') - 1)->join("\n")
enddef

def Error(msg: string) #{{{2
    echohl ErrorMsg
    echomsg msg
    echohl NONE
enddef

def GetDlmAddr(line1: number, line2: number): list<number> #{{{2
    # delimiters addresses:
    # addresses of `---` lines inside the range + last line of the range
    var dlm_addr: list<number>
    cursor(line1, 1)
    while search('^---$', 'W') > 0 && line('.') <= line2
        dlm_addr += [line('.')]
    endwhile

    # Make the code work  even if we added an unnecessary `---`  line at the end
    # of the range.
    if getline(line2) == '---'
        --dlm_addr[-1]
    else
        dlm_addr += [line2]
    endif

    return dlm_addr
enddef

def GetSets(dlm_addr: list<number>): list<list<string>> #{{{2
    var sets: list<list<string>>
    for i: number in range(1, len(dlm_addr) - 1)
        var set: list<string> = getline(dlm_addr[i - 1], dlm_addr[i])
            ->filter((_, v: string): bool => v != '---')
        sets += [set]
    endfor
    return sets
enddef

def AllCombinations(sets: list<list<string>>): list<list<string>> #{{{2
    var cbns: list<list<string>>
    if len(sets) == 2
        for i: string in sets[0]
            for j: string in sets[1]
                cbns += [[i, j]]
            endfor
        endfor
    else
        for i: string in sets[0]
            for j: list<string> in AllCombinations(sets[1 :])
                cbns += [[i] + j]
            endfor
        endfor
    endif
    return cbns
enddef

def EmptyDir() #{{{2
    DIR->readdir()
       ->map((_, v: string) => DIR .. '/' .. v)
       ->mapnew((_, v: string) => {
           if bufexists(v)
               execute 'bwipe! ' .. v
           endif
           delete(v)
        })
    # Why do we need to delete a possible buffer?{{{
    #
    # If a  buffer exists,  when we'll  do `:edit  fname`, even  if the  file is
    # deleted, Vim will load the buffer with its old undesired contents.
    #}}}
    delete(DIR, 'd')
enddef

def CreateHydraHeads( #{{{2
    tmpl: string,
    cbns: list<list<string>>,
    sets: list<list<string>>,
    arg_ext: string,
    cml: string
)

    var ext: string = !empty(arg_ext) ? '.' .. arg_ext : ''

    for i: number in range(1, len(cbns))
        execute 'edit ' .. DIR .. '/head'
            # padding of  `0`, so  that the  filenames are  sorted as  expected when
            # there are more than 10 possible combinations
            .. repeat('0', len(cbns)->len() - len(i))
            .. i .. ext
        var cbn: list<string> = cbns[i - 1]
        # compute a code standing for the current combination
        # sth like 1010
        var code: string = cml
            .. ' '
            .. range(1, len(sets))
                ->map((j: number, _): number => index(sets[j], cbn[j]))
                ->join('')
        var expanded_tmpl: string = GetExpandedTemplate(tmpl, cbns[i - 1])

        append('$', code)
        var lines: list<string> = [
            '',
            cml .. ' Write your observation below (stop before ENDOBS):',
            cml .. ' ENDOBS',
            ''
        ]
        append('$', lines)
        expanded_tmpl->split('\n')->append('$')
        keepjumps :0 delete _
        update
    endfor

    # populate arglist with all generated files
    execute 'args '
    .. DIR->readdir((n: string): bool => n =~ '^head' && n =~ ext .. '$')
          ->map((_, v: string) => DIR .. '/' .. v)
          ->join()
    first
enddef

def GetExpandedTemplate(tmpl: string, cbn: list<string>): string #{{{2
    var texts: list<string> = split(tmpl, '%s\zs')
        # Replace each `%s` item with  the appropriate text, escaping characters
        # which  have   a  special  meaning   in  the  replacement  part   of  a
        # substitution:
        #
        #     \ ~ &
        #
        # Why checking that there's a `%s` item? Shouldn't there always be one?{{{
        #
        # Not necessarily.  MWE:
        #
        #     foo %s bar %s baz
        #
        #     → foo %s
        #       bar %s
        #       baz     (no `%s` item)
        #}}}
        ->map((i: number, v: string) =>
                  v =~ '%s'
                ? v->substitute('%s', escape(cbn[i], '\~&'), '')
                : v
        )
    # join the texts and trim ending whitespace on each line
    return texts->join('')->substitute('\zs\s*\ze\%($\|\n\)', '', 'g')
enddef

def PrepareAnalysis(sets: list<list<string>>) #{{{2
    execute 'edit ' .. ANALYSIS_FILE

    append('$', '# Code meaning')
    var i: number = 1
    var ordinals: dict<string> = {1: '1st', 2: '2nd', 3: '3rd'}
    for a_set: list<string> in sets
        var ordinal: string = i <= 3 ? ordinals[i] : i .. 'th'

        (
            ['## ' .. ordinal .. ' digit', '']
           + a_set->mapnew((j: number, v: string) =>
                                '~' .. j .. '~  ' .. (empty(v) ? '∅' : v))
           + ['']
        )->append('$')

        ++i
    endfor

    var lines: list<string> =<< trim END
        # Observations

        # Conclusion

        Describe the heads according to their invariants:

    END
    append('$', lines)

    keepjumps :0 delete _
    update

    command! -bar -buffer -range=% HydraAnalyse Analyse()
enddef

def Analyse() #{{{2
    # dictionary binding a list of codes to each observation
    var obs2codes: dict<list<string>>
    # iterate over the files such as `/run/user/1000/hydra/head01.ext`
    var heads: list<string> = DIR
        ->readdir((n: string): bool => n =~ '^head')
        ->map((_, v: string) => DIR .. '/' .. v)
    for head: string in heads
        var an_obs: string
        var code: string
        [an_obs, code] = GetObservationAndCode(head)
        obs2codes[an_obs] = get(obs2codes, an_obs, []) + [code]
    endfor

    execute 'edit ' .. ANALYSIS_FILE
    &l:foldenable = false
    &l:wrap = false
    search('^# Observations', 'c')
    var c: number = 0
    # Write each observation noted in the heads files, as well as the associated
    # (syntax highlighted) codes.
    for [obs: string, codes: list<string>] in obs2codes->items()
        var o: string = obs
        # the observation is probably commented; try to guess what it is
        var cml: string = o->matchstr('\S\{1,2}\s')
        # remove it
        o = o->substitute('\%(^\|\n\)\zs' .. cml, '', 'g')

        # write the observation (and make it a title)
        var lines: list<string> = (c ? [''] : []) + ['## ' .. o] + ['']
        append('.', lines)
        cursor(line('.') + len(lines), 1)
        # write the list of codes below;
        # we split then join back to add a space between 2 consecutive digits
        var mcodes: list<list<string>> = codes
            ->mapnew((_, v: string): list<string> => split(v, '\zs'))
        lines = mcodes->mapnew((_, v: list<string>): string => join(v))
        append('.', lines)
        cursor(line('.') + len(lines), 1)

        # if we  have only  1 code,  there can't be  any invariant,  and there's
        # nothing to syntax highlight
        if len(mcodes) == 1
            continue
        endif

        # Transpose the codes so that if there're invariants, they'll be found on lines, instead of columns:{{{
        #
        #     ['1','4','5','8']     ['1','2','3']
        #     ['2','4','6','8']  →  ['4','4','4']
        #     ['3','4','7','8']     ['5','6','7']
        #                           ['8','8','8']
        #}}}
        var transposed_codes: list<list<number>> = call(MatrixTransposition, [
            mcodes
                ->mapnew((_, v: list<string>): list<number> =>
                            v->mapnew((_, w: string): number => w->str2nr()))
        ])
        # Get a list of boolean flags standing for the columns where there're invariants:{{{
        #
        #                           there are invariants on the 2nd and 4th LINES of the TRANSPOSED lists,
        #                           so there are invariants on the 2nd and 4th COLUMNS of the ORIGINAL lists
        #                           ✔     ✔
        #     ['1','2','3']         v     v
        #     ['4','4','4']  →  [0, 1, 0, 1]
        #     ['5','6','7']      ^     ^
        #     ['8','8','8']      ✘     ✘
        #                        there're no invariants on the 1st and 3rd column
        #
        #}}}
        var invariants: list<bool> = transposed_codes
            ->mapnew((_, v: list<number>): bool =>
                        v == deepcopy(v)->filter((_, w: number): bool => w == v[0]))
        # Translate every flag into a column index:{{{
        #
        #     [0, 1, 0, 1]  →  [0, 1, 0, 3]
        #}}}
        var minvariants: list<number> = invariants
            # Suppose the first column is an invariant.{{{
            #
            # Its flag is on (value `1`).
            #
            # Here, if you write `i`, instead of `i+1`, the boolean flag `1`
            # will be  replaced by the position  of the column which  is `0`
            # (Vim starts indexing a list from `0`).
            #
            # But later,  when we'll  need to filter  out the  columns where
            # there's no invariant,  we'll have no way to  tell whether this
            # `0` means:
            #
            #    - the first column is an invariant, and `0` is its index
            #
            #    - the first column is NOT an invariant, and its flag is off
            #
            # So,  we temporarily  offset the  index of  the columns  to the
            # right, to avoid the confusion later.
            #}}}
            #                                                  vvv
            ->mapnew((i: number, v: bool): number => v ? i + 1 : 0)
            # remove the columns where there's no invariant
            ->filter((_, v: number): bool => v != 0)
            # cancel the offset (`+ 1`) we've introduced in the previous `map()`
            ->map((_, v: number) => v - 1)

        # add syntax highlighting for each column of identical digits
        # those are interesting invariants
        CreateMatchInvariants(mcodes, minvariants)
        ++c
    endfor
    update
    &l:foldenable = true
enddef

def CreateMatchInvariants( #{{{2
    codes: list<list<string>>,
    invariants: list<number>
)
    # Add `~` characters around invariant digits, so that they are
    # syntax highlighted.

    var lline: number = line('.')
    var fline: number = lline - len(codes) + 1
    # Why `reverse()`?{{{
    #
    # Whenever we add  an `~` character, for syntax highlighting,  we change the
    # column position of the next digit to highlight.
    # We don't  want to re-compute  this position,  so we process  the invariant
    # digits in reverse order.
    #}}}
    for vcol: number in reverse(invariants)
        var coords: list<list<number>> = range(fline, lline)
            ->mapnew((_, v: number): list<number> => [v, 2 * vcol + 1])
        for coord: list<number> in coords
            execute 'silent keepjumps keeppatterns :% substitute'
                .. '/\%' .. coord[0] .. 'l\%' .. coord[1] .. 'v.'
                .. '/\~&\~'
                .. '/e'
        endfor
    endfor
enddef

def GetObservationAndCode(head: string): list<string> #{{{2
    var lines: list<string> = readfile(head)
    var code: string = lines[0]->matchstr('\d\+')
    var i: number = lines->match('Write your observation')
    var j: number = lines->match('ENDOBS$')
    var an_obs: string = lines[i + 1 : j - 1]->join("\n")

    # If the  user wrote `obs123`  as an observation,  expand it into  the 123th
    # observation.
    var old_obs: number = an_obs
        #           ┌ possible comment leader
        #           ├─────────┐
        ->matchstr('^.\{1,2}\s*obs\zs\d\+\ze\s*$')
        ->str2nr()
    #                              ┌ make sure `new_obs[old_obs - 1]` exists
    #                              │
    if !empty(old_obs) && new_obs->get(old_obs - 1, '') != ''
        an_obs = new_obs[old_obs - 1]
    elseif old_obs == 0
        new_obs += [an_obs]
    endif
    return [an_obs, code]
enddef

