runtime! ftplugin/markdown.vim
let b:did_ftplugin = 1

" teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
\                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
\                     ."
\                        delc HydraAnalyse
\                      "
