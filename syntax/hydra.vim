if exists('b:current_syntax')
    finish
endif

syn match hydra_section '^Code meaning:$'
syn match hydra_section 'Observations:'
syn match hydra_section 'Conclusion:'

hi link hydra_section Title

let b:current_syntax = 'hydra'
