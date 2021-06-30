vim9script

if exists('b:current_syntax')
    finish
endif

syntax region hydra_digit matchgroup=DiffAdd start='\~' end='\~' oneline concealends
syntax match hydra_section '^#.*'

highlight def link hydra_digit   DiffAdd
highlight def link hydra_section Title

b:current_syntax = 'hydra'
