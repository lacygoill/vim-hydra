if exists('b:current_syntax')
    finish
endif

syn region hydra_digit   matchgroup=DiffAdd start='\~' end='\~' oneline concealends
syn match hydra_section '^#.*'

hi link hydra_digit   DiffAdd
hi link hydra_section Title

let b:current_syntax = 'hydra'
