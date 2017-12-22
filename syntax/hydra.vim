if exists('b:current_syntax')
    finish
endif

syn match hydra_section '\v^%(Code meaning|Observations|Conclusion):$'

hi link hydra_section Title

let b:current_syntax = 'hydra'
