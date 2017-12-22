if exists('b:current_syntax')
    finish
endif

syn match hydra_section '\v^# %(Code meaning|Observations|Conclusion)$'
syn match hydra_digit '\v^\d+%(st|nd|rd|th) digit$'
syn match hydra_invariants '\v^%(\s*[v^])+\s*$'

hi link hydra_section Title
hi link hydra_digit Number
hi link hydra_invariants Number

let b:current_syntax = 'hydra'
