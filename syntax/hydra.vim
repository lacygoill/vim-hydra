if exists('b:current_syntax')
    finish
endif

syn match hydra_section '\v^#.*'
syn match hydra_digit '\v^\d+%(st|nd|rd|th) digit$'

hi link hydra_section Title
hi link hydra_digit Number

let b:current_syntax = 'hydra'
