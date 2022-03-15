" zf.vim - a Vim plugin for the zf fuzzy finder.
"     Copyright (c) 2022 Dave Gauer
"     MIT License

if exists('g:loaded_zf_vim')
"    finish TODO uncomment!
endif
let g:loaded_zf_vim = 1

" ============================================================================
" Global settings - override these in your .vimrc to taste

if !exists('g:zf_exec')
    let g:zf_exec = 'zf'
endif

if !exists('g:zf_lines')
    let g:zf_lines = 20
endif

if !exists('g:zf_list_files')
    let g:zf_list_files = 'find . -type f'
endif


" ============================================================================
" Plugin API

" This global will be populated with your selection
" It's a list, so you'll pretty much always want g:zf_selection[0]
let g:zf_selection = []

" ZfSelectFile() function - select a file from current working directory and
" open it in Vim. Example:
"
"   nnoremap <leader>ff :call ZfSelectFile()<CR>
"
" After calling, g:zf_selection will contain the selected file name (if any).
function! ZfSelectFile()
    call ZfWithPipe(g:zf_list_files)

	" If g:zf_selection contains no lines, the user must have aborted the
	" selection.
	if len(g:zf_selection) < 1
		return
	endif

    exec "edit " . g:zf_selection[0]
endfunction

" ============================================================================
" Internal interfaces to call zf executable

" Call an external command and pipe its output to zf (to be used as the fuzzy
" find input list).
" Example:
"
"     :call ZfWithPipe('cat bowie-albums.txt')
"
" Resulting selection in g:zf_selection
function! ZfWithPipe(pipe_from)
    let g:zf_selection = s:zfcall(a:pipe_from, '')
endfunction

" Supply the fuzzy find input list directly as a Vim list of strings
" Example:
"
"     :call ZfWithLines(['foo', 'bar', 'baz'])
"
" Resulting selection in g:zf_selection
function! ZfWithLines(lines)
    let g:zf_selection = s:zfcall('', a:lines)
endfunction

" Actual executable system call. Takes a command to pipe OR list of lines.
" Returns the selection as a list of lines (currently one line max).
function! s:zfcall(pipe_from, lines)
    if !executable(g:zf_exec)
        echohl ErrorMsg
        echom "'" . g:zf_exec . "' not executable. Maybe check your $PATH?"
        echohl None
        return
    endif

    if !executable('tput') || !filereadable('/dev/tty')
        echohl ErrorMsg
        echom "Either can't execute 'tput' or read /dev/tty'. Setup not supported."
        echohl None
        return
    endif

	" Output will always go to a temporary file that we'll read
	" into a Vim variable afterward
    let output_fname = tempname()

	" Construct command line to prepare terminal and execute
	" a f u Z z Y f I n d! =8-D
	let cmd = "tput cnorm > /dev/tty; "

	if len(a:pipe_from) > 0
		" Pipe input from supplied command to zf executable
		let cmd .= a:pipe_from . " | "
	endif

	let cmd .= g:zf_exec . " --lines " . g:zf_lines . " > " . output_fname

	if len(a:lines) > 0
		" Write input lines to temporary file
		let source_fname = tempname()
		" Assumes a perfect world where this couldn't possibly fail. :-)
		call writefile(a:lines, source_fname)
		let cmd .= " < " . source_fname
	endif

	let cmd .= " 2> /dev/tty"

	" Make it so!		
    call system(cmd)

	" Let Vim reset the terminal state and all that good stuff
	" after we messed with it (yay, we don't need to clean up!)
    redraw!

	" Read the selection (if any) from the temporary file.
	" Assumes a perfect world where this couldn't possibly fail. :-)
    return readfile(output_fname)
endfunction


" *** Future support for high-level buffer-listing function ***
" Major inspiration from fzf.vim/plugin/fzf.vim
"let g:zf_bufferlist = {}
"augroup zf_buffers
"    autocmd!
"    autocmd BufWinEnter,WinEnter * let g:zf_bufferlist[bufnr('')] = localtime()
"    autocmd BufDelete * silent! call remove(g:zf_bufferlist, expand('<abuf>'))
"augroup END
