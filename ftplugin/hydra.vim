" folding + conceal {{{1

augroup my_hydra
    au! * <buffer>
    au BufWinEnter  <buffer>  setl fdm=expr
                           \| let &l:fdt = 'markdown#fold_text()'
                           \| let &l:fde = 'markdown#stacked()'
    au BufWinEnter <buffer> setl cole=2 cocu=nc
augroup END
