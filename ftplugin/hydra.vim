" folding + conceal {{{1

augroup my_hydra
    au! * <buffer>
    au BufWinEnter  <buffer>  setl fdm=expr
                           \| let &l:fdt = 'markdown#fold_text()'
                           \| let &l:fde = 'markdown#stacked()'
    au BufWinEnter <buffer> setl cole=2 cocu=nc
augroup END

" teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
\                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
\                     ."
\                          setl cocu< cole< fde< fdm< fdt<
\                        | exe 'au! my_hydra * <buffer>'
\                        | delc HydraAnalyse
\                      "
