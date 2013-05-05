" Folding support for LaTeX
"
" Options
" g:LatexBox_Folding       - Turn on/off folding
" g:LatexBox_fold_preamble - Turn on/off folding of preamble
" g:LatexBox_fold_parts    - Define parts (eq. appendix, frontmatter) to fold
" g:LatexBox_fold_sections - Define section levels to fold
" g:LatexBox_fold_envs     - Turn on/off folding of environments
"

" {{{1 Set options
if exists('g:LatexBox_Folding') && g:LatexBox_Folding == 1
    setl foldmethod=expr
    setl foldexpr=LatexBox_FoldLevel(v:lnum)
    setl foldtext=LatexBox_FoldText()
endif
if !exists('g:LatexBox_fold_preamble')
    let g:LatexBox_fold_preamble=1
endif
if !exists('g:LatexBox_fold_envs')
    let g:LatexBox_fold_envs=1
endif
if !exists('g:LatexBox_fold_parts')
    let g:LatexBox_fold_parts=[
                \ "appendix",
                \ "frontmatter",
                \ "mainmatter",
                \ "backmatter"
                \ ]
endif
if !exists('g:LatexBox_fold_sections')
    let g:LatexBox_fold_sections=[
                \ "part",
                \ "chapter",
                \ "section",
                \ "subsection",
                \ "subsubsection"
                \ ]
endif

" The foldexpr function returns "=" for most lines, which means it can become
" slow for large files.  The following is a hack that is based on this reply to
" a discussion on the Vim Developer list:
" http://permalink.gmane.org/gmane.editors.vim.devel/14100
"augroup FastFold
"    autocmd!
"    autocmd InsertEnter *.tex setlocal foldmethod=manual
"    autocmd InsertLeave *.tex setlocal foldmethod=expr
""   autocmd InsertLeave *.tex augroup FoldMeth
""               \ | autocmd  FoldMeth CursorHold * setlocal foldmethod=expr
""               \ | autocmd! FoldMeth CursorHold
"augroup end

" {{{1 LatexBox_FoldLevel help functions

" The function parses the tex file to find the sections that are to be folded
" and their levels.
function! s:FoldSectionLevels()
    " Initialize
    let level = 1
    let foldsections = []

    " If we use two or more of the *matter commands, we need one more foldlevel
    let nparts = 0
    for part in g:LatexBox_fold_parts
        let i = 1
        while i < line("$")
            if getline(i) =~ '^\s*\\' . part . '\>'
                let nparts += 1
                break
            endif
            let i += 1
        endwhile
        if nparts > 1
            let level = 2
            break
        endif
    endfor

    " Combine sections and levels, but ignore unused section commands:  If we
    " don't use the part command, then chapter should have the highest
    " level.  If we don't use the chapter command, then section should be the
    " highest level.  And so on.
    let ignore = 1
    for part in g:LatexBox_fold_sections
        " For each part, check if it is used in the file.  We start adding the
        " parts to the fold sections array whenever we find one.
        if ignore
            let i = 1
            while i < line("$")
                if getline(i) =~ '^\s*\\' . part . '\>'
                    call insert(foldsections, [part, level])
                    let level += 1
                    let ignore = 0
                    break
                endif
                let i += 1
            endwhile
        else
            call insert(foldsections, [part, level])
            let level += 1
        endif
    endfor

    return foldsections
endfunction

function! s:GetFoldLevel(lnum)
    if b:LatexBox_FoldCache[a:lnum].level[0] == ">"
        return b:LatexBox_FoldCache[a:lnum].level[1]
    elseif b:LatexBox_FoldCache[a:lnum].level[0] == "<"
        return b:LatexBox_FoldCache[a:lnum].level[1] - 1
    else
        return b:LatexBox_FoldCache[a:lnum].level[0]
    endif
endfunction

" {{{1 LatexBox_FoldLevel

" Parse file to dynamically set the sectioning fold levels
let b:LatexBox_FoldSections = s:FoldSectionLevels()

" Create fold cache
let b:LatexBox_FoldCache = {0: 0, 'unchanged': 0}

let s:notbslash = '\%(\\\@<!\%(\\\\\)*\)\@<='
let s:notcomment = '\%(\%(\\\@<!\%(\\\\\)*\)\@<=%.*\)\@<!'
function! LatexBox_FoldLevel(lnum)
    " Folding starts with line 1, in which case we reset the unchanged flag
    if a:lnum == 1
        let b:LatexBox_FoldCache.force = 0
    endif

    " Check cache
    let line = getline(a:lnum)
    if has_key(b:LatexBox_FoldCache, a:lnum)
        if b:LatexBox_FoldCache[a:lnum].line != line
           let b:LatexBox_FoldCache[a:lnum].line = line
           let b:LatexBox_FoldCache[a:lnum].level = -1
        endif
    else
        let b:LatexBox_FoldCache[a:lnum] = {
                    \ 'line': line,
                    \ 'level': -1,
                    \ }
    endif

    " Check if we need to do more work
    if b:LatexBox_FoldCache[a:lnum].level == -1 || b:LatexBox_FoldCache.force
        let b:LatexBox_FoldCache[a:lnum].level
                    \ = s:GetFoldLevel(a:lnum - 1)
    else
        return b:LatexBox_FoldCache[a:lnum].level
    endif

    " Fold preamble
    let nline = getline(a:lnum + 1)
    if g:LatexBox_fold_preamble == 1
        if line =~# '^\s*\\documentclass'
            let b:LatexBox_FoldCache[a:lnum].level = ">1"
            let b:LatexBox_FoldCache.force = 1
            return b:LatexBox_FoldCache[a:lnum].level
        elseif nline =~# '^\s*\\begin\s*{\s*document\s*}'
            let b:LatexBox_FoldCache[a:lnum].level = "<1"
            let b:LatexBox_FoldCache.force = 1
            return b:LatexBox_FoldCache[a:lnum].level
        elseif line =~# '^\s*\\begin\s*{\s*document\s*}'
            let b:LatexBox_FoldCache[a:lnum].level = 0
            let b:LatexBox_FoldCache.force = 1
            return b:LatexBox_FoldCache[a:lnum].level
        endif
    endif

    " Don't fold \end{document}
    if line =~# '\s*\\end{document}'
        let b:LatexBox_FoldCache[a:lnum].level = 0
        let b:LatexBox_FoldCache.force = 1
        return b:LatexBox_FoldCache[a:lnum].level
    endif

    " Fold parts (\frontmatter, \mainmatter, \backmatter, and \appendix)
    if line =~# '^\s*\\\%(' . join(g:LatexBox_fold_parts, '\|') . '\)'
        let b:LatexBox_FoldCache[a:lnum].level = ">1"
        let b:LatexBox_FoldCache.force = 1
        return b:LatexBox_FoldCache[a:lnum].level
    endif

    " Fold chapters and sections
    for [part, level] in b:LatexBox_FoldSections
        if line =~# '^\s*\(\\\|% Fake\)' . part . '\>'
            let b:LatexBox_FoldCache[a:lnum].level = ">" . level
            let b:LatexBox_FoldCache.force = 1
            return b:LatexBox_FoldCache[a:lnum].level
        endif
    endfor

    " Fold environments
    if g:LatexBox_fold_envs == 1
        if line =~# s:notcomment . s:notbslash . '\\begin\s*{.\{-}}'
            let b:LatexBox_FoldCache[a:lnum].level
                        \ = ">" . string(1 + b:LatexBox_FoldCache[a:lnum].level)
            let b:LatexBox_FoldCache.force = 1
            return b:LatexBox_FoldCache[a:lnum].level
        elseif line =~# s:notcomment . s:notbslash . '\\end\s*{.\{-}}'
            let b:LatexBox_FoldCache[a:lnum].level
                        \ = "<" . b:LatexBox_FoldCache[a:lnum].level
            let b:LatexBox_FoldCache.force = 1
            return b:LatexBox_FoldCache[a:lnum].level
        endif
    endif

    " Return foldlevel of previous line
    return b:LatexBox_FoldCache[a:lnum].level
endfunction

" {{{1 LatexBox_FoldText help functions
function! s:LabelEnv()
    let i = v:foldend
    while i >= v:foldstart
        if getline(i) =~ '^\s*\\label'
            return matchstr(getline(i), '^\s*\\label{\zs.*\ze}')
        end
        let i -= 1
    endwhile
    return ""
endfunction

function! s:CaptionEnv()
    let i = v:foldend
    while i >= v:foldstart
        if getline(i) =~ '^\s*\\caption'
            return matchstr(getline(i), '^\s*\\caption\(\[.*\]\)\?{\zs.\+')
        end
        let i -= 1
    endwhile
    return ""
endfunction

function! s:CaptionTable()
    let i = v:foldstart
    while i <= v:foldend
        if getline(i) =~ '^\s*\\caption'
            return matchstr(getline(i), '^\s*\\caption\(\[.*\]\)\?{\zs.\+')
        end
        let i += 1
    endwhile
    return ""
endfunction

function! s:CaptionFrame(line)
    " Test simple variant first
    let caption = matchstr(a:line,'\\begin\*\?{.*}{\zs.\+')

    if ! caption == ''
        return caption
    else
        let i = v:foldstart
        while i <= v:foldend
            if getline(i) =~ '^\s*\\frametitle'
                return matchstr(getline(i),
                            \ '^\s*\\frametitle\(\[.*\]\)\?{\zs.\+')
            end
            let i += 1
        endwhile

        return ""
    endif
endfunction

" {{{1 LatexBox_FoldText
function! LatexBox_FoldText()
    " Initialize
    let line = getline(v:foldstart)
    let nlines = v:foldend - v:foldstart + 1
    let level = ''
    let title = 'Not defined'

    " Fold level
    let level = strpart(repeat('-', v:foldlevel-1) . '*',0,3)
    if v:foldlevel > 3
        let level = strpart(level, 1) . v:foldlevel
    endif
    let level = printf('%-3s', level)

    " Preamble
    if line =~ '\s*\\documentclass'
        let title = "Preamble"
    endif

    " Parts, sections and fakesections
    let sections = '\(\(sub\)*section\|part\|chapter\)'
    let secpat1 = '^\s*\\' . sections . '\*\?\s*{'
    let secpat2 = '^\s*\\' . sections . '\*\?\s*\['
    if line =~ '\\frontmatter'
        let title = "Frontmatter"
    elseif line =~ '\\mainmatter'
        let title = "Mainmatter"
    elseif line =~ '\\backmatter'
        let title = "Backmatter"
    elseif line =~ '\\appendix'
        let title = "Appendix"
    elseif line =~ secpat1 . '.*}'
        let title =  matchstr(line, secpat1 . '\zs.*\ze}')
    elseif line =~ secpat1
        let title =  matchstr(line, secpat1 . '\zs.*')
    elseif line =~ secpat2 . '.*\]'
        let title =  matchstr(line, secpat2 . '\zs.*\ze\]')
    elseif line =~ secpat2
        let title =  matchstr(line, secpat2 . '\zs.*')
    elseif line =~ 'Fake' . sections . ':'
        let title =  matchstr(line,'Fake' . sections . ':\s*\zs.*')
    elseif line =~ 'Fake' . sections
        let title =  matchstr(line, 'Fake' . sections)
    endif

    " Environments
    if line =~ '\\begin'
        let env = matchstr(line,'\\begin\*\?{\zs\w*\*\?\ze}')
        if env == 'frame'
            let label = ''
            let caption = s:CaptionFrame(line)
        elseif env == 'table'
            let label = s:LabelEnv()
            let caption = s:CaptionTable()
        else
            let label = s:LabelEnv()
            let caption = s:CaptionEnv()
        endif
        if caption . label == ''
            let title = env
        elseif label == ''
            let title = printf('%-12s%s', env . ':',
                        \ substitute(caption, '}\s*$', '',''))
        elseif caption == ''
            let title = printf('%-12s%56s', env, '(' . label . ')')
        else
            let title = printf('%-12s%-30s %23s', env . ':',
                        \ strpart(substitute(caption, '}\s*$', '',''),0,34),
                        \ '(' . label . ')')
        endif
    endif

    let title = strpart(title, 0, 68)
    return printf('%-3s %-68s #%5d', level, title, nlines)
endfunction

" {{{1 Footer
" vim:fdm=marker:ff=unix:ts=4:sw=4
