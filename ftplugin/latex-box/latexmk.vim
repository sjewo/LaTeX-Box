" LaTeX Box latexmk functions


" <SID> Wrap {{{
function! s:GetSID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\ze.*$')
endfunction
let s:SID = s:GetSID()
function! s:SIDWrap(func)
	return s:SID . a:func
endfunction
" }}}

" Compilation {{{

" g:vim_program {{{
if !exists('g:vim_program')

	if match(&shell, '/\(bash\|zsh\)$') >= 0
		let ppid = '$PPID'
	else
		let ppid = '$$'
	endif

	" attempt autodetection of vim executable
	let g:vim_program = ''
	let tmpfile = tempname()
	silent execute '!ps -o command= -p ' . ppid . ' > ' . tmpfile
	for line in readfile(tmpfile)
		let line = matchstr(line, '^\S\+\>')
		if !empty(line) && executable(line)
			let g:vim_program = line . ' -g'
			break
		endif
	endfor
	call delete(tmpfile)

	if empty(g:vim_program)
		if has('gui_macvim')
			let g:vim_program = '/Applications/MacVim.app/Contents/MacOS/Vim -g'
		else
			let g:vim_program = v:progname
		endif
	endif
endif
" }}}

if !exists('g:LatexBox_latexmk_options')
	let g:LatexBox_latexmk_options = ''
endif
if !exists('g:LatexBox_output_type')
	let g:LatexBox_output_type = 'pdf'
endif
if !exists('g:LatexBox_viewer')
	let g:LatexBox_viewer = 'xdg-open'
endif
if !exists('g:LatexBox_autojump')
	let g:LatexBox_autojump = 0
endif
if ! exists("g:LatexBox_quickfix")
	let g:LatexBox_quickfix = 1
endif
" }}}


" dictionary of latexmk PID's (basename: pid)
let s:latexmk_running_pids = {}

" Set PID {{{
function! s:LatexmkSetPID(basename, pid)
	let s:latexmk_running_pids[a:basename] = a:pid
endfunction
" }}}

" Callback {{{
function! s:LatexmkCallback(basename, status)
	call remove(s:latexmk_running_pids, a:basename)
	call LatexBox_LatexErrors(a:status, a:basename)
endfunction
" }}}

" Latexmk {{{
function! LatexBox_Latexmk(force)

	let basename = LatexBox_GetTexBasename(1)

	if !filereadable(LatexBox_GetTexRoot() . '/latexmk')
		let l:options = '-' . g:LatexBox_output_type . g:LatexBox_latexmk_options
		if a:force
			let l:options .= ' -g'
		endif
			let l:options .= " -e '$pdflatex =~ s/ / -file-line-error /'"
			let l:options .= " -e '$latex =~ s/ / -file-line-error /'"
	endif

	" latexmk command
	let cmd = 'cd ' . shellescape(LatexBox_GetTexRoot()) . ' ; ' .
		' latexmk ' . l:options	. ' ' . shellescape(LatexBox_GetMainTexFile())

	silent execute '!' . cmd
	if !has("gui_running")
		redraw!
	endif
endfunction
" }}}

" LatexmkClean {{{
function! LatexBox_LatexmkClean(cleanall)

	if a:cleanall
		let l:options = '-C'
	else
		let l:options = '-c'
	endif

	silent execute '! cd ' . shellescape(LatexBox_GetTexRoot()) . ' ; latexmk ' . l:options
				\	. ' ' . shellescape(LatexBox_GetMainTexFile()) . ' >&/dev/null'
	if !has("gui_running")
		redraw!
	endif

	echomsg "latexmk clean finished"

endfunction
" }}}

" LatexErrors {{{
" LatexBox_LatexErrors(jump, [basename])
function! LatexBox_LatexErrors(status, ...)
	if a:0 >= 1
		let log = a:1 . '.log'
	else
		let log = LatexBox_GetLogFile()
	endif

	if fnamemodify(getcwd(), ":p") !=# fnamemodify(LatexBox_GetTexRoot(), ":p")
		redraw
		echohl WarningMsg
		echomsg 'Changing directory to TeX root: ' . LatexBox_GetTexRoot() . ' to support error log parsing'
		echohl None
		execute 'cd ' . LatexBox_GetTexRoot()
	endif

	if g:LatexBox_autojump
		execute 'cfile ' . fnameescape(log)
	else
		execute 'cgetfile ' . fnameescape(log)
	endif

	" always open quickfix when an error/warning is detected
	if g:LatexBox_quickfix
		ccl
		cw
	endif

	if a:status
		echomsg "latexmk exited with status " . a:status
	else
		echomsg "latexmk finished"
	endif

endfunction
" }}}

" Commands {{{
command! -bang	Latexmk				call LatexBox_Latexmk(<q-bang> == "!")
command! -bang	LatexmkClean		call LatexBox_LatexmkClean(<q-bang> == "!")
command! LatexErrors			call LatexBox_LatexErrors(1)
" }}}

autocmd VimLeavePre * call <SID>kill_all_latexmk()

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
