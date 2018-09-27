if exists('b:did_ftplugin')
    finish
endif

runtime! ftplugin/markdown.vim
unlet! b:did_ftplugin

let b:did_ftplugin = 1

" teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
\                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
\                     ."
\                        delc HydraAnalyse
\                      "
