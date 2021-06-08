vim9script

if exists('b:did_ftplugin')
    finish
endif

runtime! ftplugin/markdown.vim
unlet! b:did_ftplugin
# Why do you `:unlet`, and then `:let` again right after?{{{
#
# We  should take  the  habit of  always  doing an  `:unlet  b:...` after  using
# `:runtime` in a filetype/indent/syntax plugin.
# This way, if you add a new `:runtime` in the future, it will work as expected,
# without a guard stopping the sourcing prematurely.
#}}}

b:title_like_in_markdown = true

b:did_ftplugin = true

# Teardown {{{1

b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
    .. '| unlet! b:title_like_in_markdown | delc HydraAnalyse'

