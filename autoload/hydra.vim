vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Init {{{1

import MatrixTransposition from 'lg/math.vim'

var DIR = getenv('XDG_RUNTIME_VIM') ?? '/tmp'
DIR ..= '/hydra'
const ANALYSIS_FILE = DIR .. '/analysis.hydra'

# Interface {{{1
def hydra#main(line1: number, line2: number) #{{{2
    var orig_id: number = win_getid()
    var view: dict<number> = winsaveview()
    var ext: string = expand('%:e')
    var cml: string = matchstr(&l:cms, '\S*\ze\s*%s')

    var template: string = GetTemplate(line1)
    if matchstr(template, '%s')->empty()
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
    e %%
    # split window vertically, and load analysis file
    vs %%
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

def Error(msg: string): string #{{{2
    echohl ErrorMsg
    echom msg
    echohl NONE
enddef

def GetDlmAddr(line1: number, line2: number): list<number> #{{{2
    # delimiters addresses:
    # addresses of `---` lines inside the range + last line of the range
    var dlm_addr: list<number> = []
    cursor(line1, 1)
    while search('^---$', 'W') > 0 && line('.') <= line2
        dlm_addr += [line('.')]
    endwhile

    # Make the code work  even if we added an unnecessary `---`  line at the end
    # of the range.
    if getline(line2) == '---'
        dlm_addr[-1] = dlm_addr[-1] - 1
    else
        dlm_addr += [line2]
    endif

    return dlm_addr
enddef

def GetSets(dlm_addr: list<number>): list<list<string>> #{{{2
    var sets: list<list<string>> = []
    for i in range(1, len(dlm_addr) - 1)
        var set: list<string> = getline(dlm_addr[i - 1], dlm_addr[i])
            ->filter((_, v) => v != '---')
        sets += [set]
    endfor
    return sets
enddef

def AllCombinations(sets: list<list<string>>): list<list<string>> #{{{2
    var cbns: list<list<string>> = []
    if len(sets) == 2
        for i in sets[0]
            for j in sets[1]
                cbns += [[i, j]]
                #         ^ string
            endfor
        endfor
    else
        for i in sets[0]
            for j in AllCombinations(sets[1 :])
                cbns += [[i] + j]
                #        ^^^ list containing a string
            endfor
        endfor
    endif
    return cbns
enddef

def EmptyDir() #{{{2
    glob(DIR .. '/*', false, true)
        ->mapnew((_, v) => [bufexists(v) && !!execute('bwipe! ' .. v), delete(v)])
    # Why do we need to delete a possible buffer?{{{
    #
    # If a buffer exists, when we'll do `:e fname`, even if the file is deleted,
    # Vim will load the buffer with its old undesired contents.
    #}}}
enddef

def CreateHydraHeads( #{{{2
    tmpl: string,
    cbns: list<list<string>>,
    sets: list<list<string>>,
    arg_ext: string,
    cml: string
    )

    var ext: string = !empty(arg_ext) ? '.' .. arg_ext : ''

    for i in range(1, len(cbns))
        #                             ┌ padding of `0`, so that the filenames are sorted as expected
        #                             │ when there are more than 10 possible combinations
        #                             │
        exe 'e ' .. DIR .. '/head' .. repeat('0', len(cbns)->len() - len(i)) .. i .. ext
        var cbn: list<string> = cbns[i - 1]
        # compute a code standing for the current combination
        # sth like 1010
        var code: string = cml
            .. ' '
            .. range(1, len(sets))
            ->map((i) => index(sets[i], cbn[i]))
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
        keepj :0d _
        update
    endfor

    # populate arglist with all generated files
    exe 'args ' .. glob(DIR .. '/head*' .. ext, false, true)->join()
    first
enddef

def GetExpandedTemplate(tmpl: string, cbn: list<string>): string #{{{2
    var texts: list<string> = split(tmpl, '%s\zs')
    # Replace  each `%s`  item with  the appropriate  text, escaping  characters
    # which have a special meaning in  the replacement part of a substitution:
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
    map(texts, (j, v) => v =~ '%s'
        ? substitute(v, '%s', escape(cbn[j], '\~&'), '')
        : v )
    # join the texts and trim ending whitespace on each line
    return join(texts, '')->substitute('\zs\s*\ze\%($\|\n\)', '', 'g')
enddef

def PrepareAnalysis(sets: list<list<string>>) #{{{2
    exe 'e ' .. ANALYSIS_FILE

    append('$', '# Code meaning')
    var i: number = 1
    var ordinals: dict<string> = {1: '1st', 2: '2nd', 3: '3rd'}
    for a_set in sets
        var ordinal: string = i <= 3 ? ordinals[i] : i .. 'th'
        append('$', ['## ' .. ordinal .. ' digit', ''])
        mapnew(a_set, (i, v) => '~' .. i .. '~  ' .. (empty(v) ? '∅' : v))
        append('$', a_set + [''])
        i += 1
    endfor

    var lines: list<string> =<< trim END
        # Observations

        # Conclusion

        Describe the heads according to their invariants:

    END
    append('$', lines)

    keepj :0d _
    update

    com! -bar -buffer -range=% HydraAnalyse Analyse()
enddef

def Analyse() #{{{2
    # dictionary binding a list of codes to each observation
    var obs2codes: dict<list<string>> = {}
    # iterate over the files such as `/run/user/1000/hydra/head01.ext`
    var heads: list<string> = glob(DIR .. '/head*', false, true)
    for head in heads
        var an_obs: string
        var code: string
        [an_obs, code] = GetObservationAndCode(head)
        obs2codes[an_obs] = get(obs2codes, an_obs, []) + [code]
    endfor

    exe 'e ' .. ANALYSIS_FILE
    setl nofoldenable nowrap
    search('^# Observations', 'c')
    var c: number = 0
    # Write each observation noted in the heads files, as well as the associated
    # (syntax highlighted) codes.
    for [obs, codes] in items(obs2codes)
        # the observation is probably commented; try to guess what it is
        var cml: string = matchstr(obs, '\S\{1,2}\s')
        # remove it
        obs = substitute(obs, '\%(^\|\n\)\zs' .. cml, '', 'g')

        # write the observation (and make it a title)
        var lines: list<string> = (c ? [''] : []) + ['## ' .. obs] + ['']
        append('.', lines)
        exe ':+' .. len(lines)
        # write the list of codes below;
        # we split then join back to add a space between 2 consecutive digits
        var mcodes: list<list<string>> = mapnew(codes, (_, v) => split(v, '\zs'))
        lines = mapnew(mcodes, (_, v) => join(v))
        append('.', lines)
        exe ':+' .. len(lines)

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
                ->mapnew((_, v) => v
                                ->mapnew((_, w) => w->str2nr()))
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
        var invariants: list<bool> = mapnew(transposed_codes, (_, v) =>
            v == deepcopy(v)->filter((_, w) => w == v[0]))
        # Translate every flag into a column index:{{{
        #
        #     [0, 1, 0, 1]  →  [0, 1, 0, 3]
        #}}}
        var minvariants: list<number> = mapnew(invariants, (i, v) =>
            v ? i + 1 : 0)
        #         ├─┘{{{
        #         └ Suppose the first column is an invariant.
        #
        # Its flag is on (value `1`).
        #
        # Here, if you write `i`, instead of `i+1`, the boolean flag `1` will be
        # replaced  by the  position  of the  column which  is  `0` (Vim  starts
        # indexing a list from `0`).
        #
        # But later, when we'll need to  filter out the columns where there's no
        # invariant, we'll have no way to tell whether this `0` means:
        #
        #    - the first column is an invariant, and `0` is its index
        #
        #    - the first column is NOT an invariant, and its flag is off
        #
        # So, we temporarily offset the index of the columns to the right,
        # to avoid the confusion later.
        #}}}
        # remove the columns where there's no invariant
        filter(minvariants, (_, v) => v != 0)
        # cancel the offset (`+1`) we've introduced in the previous `map()`
        map(minvariants, (_, v) => v - 1)

        # add syntax highlighting for each column of identical digits
        # those are interesting invariants
        CreateMatchInvariants(mcodes, minvariants)
        c += 1
    endfor
    update
    setl foldenable
enddef

def CreateMatchInvariants(codes: list<list<string>>, invariants: list<number>) #{{{2
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
    for vcol in reverse(invariants)
        var coords: list<list<number>> = range(fline, lline)
            ->mapnew((_, v) => [v, 2 * vcol + 1])
        for coord in coords
            exe 'sil keepj keepp :%s/\%' .. coord[0] .. 'l\%' .. coord[1] .. 'v./\~&\~/e'
        endfor
    endfor
enddef

def GetObservationAndCode(head: string): list<string> #{{{2
    var lines = readfile(head)
    var code: string = matchstr(lines[0], '\d\+')
    var i: number = match(lines, 'Write your observation')
    var j: number = match(lines, 'ENDOBS$')
    var an_obs: string = join(lines[i + 1 : j - 1], "\n")

    # If the  user wrote `obs123`  as an observation,  expand it into  the 123th
    # observation.
    #                                       ┌ possible comment leader
    #                                       ├─────────┐
    var old_obs: number = matchstr(an_obs, '^.\{1,2}\s*obs\zs\d\+\ze\s*$')
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

