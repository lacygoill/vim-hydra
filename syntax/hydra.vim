if exists('b:current_syntax')
    finish
endif

syn match  hydra_section        '\v^#.*'
" FIXME:
" How to color a digit at the beginning of a line followed by a tilde:
"     syn match  hydra_digit          '^\d\+\ze\~'
"     hi link  hydra_digit          DiffAdd
"
" … then conceal the tilde:
"     syn match  hydra_digit_conceal  '^\d\+\zs\~' conceal containedin=ALL
"
" The commented code here fails  to conceal the tilde. Probably, because there's
" an overlap between the 2 syntax items (even though we use `\zs` and `\ze`).

hi link  hydra_section        Title

let b:current_syntax = 'hydra'
