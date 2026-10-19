" Minimal vim config: backup editor in case the Neovim config breaks.
" Single file, no plugins. It mirrors the options and the main keymaps of the
" Neovim config (nvim/.config/nvim/lua/default/options.lua and keymaps/).

" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
" Neovim defaults
" Neovim enables these by default, vim does not. Without them vim behaves
" differently from Neovim (e.g. :bnext refuses to leave a modified buffer).

set nocompatible                    " use vim features, not vi compatibility
syntax on                           " syntax highlighting
filetype plugin indent on           " filetype detection, plugins and indentation
set encoding=utf-8                  " encoding used inside vim
set hidden                          " switch buffers without saving them first
set autoindent                      " keep the indentation of the previous line
set backspace=indent,eol,start      " backspace works over everything in insert mode
set incsearch                       " show matches while typing the search
set laststatus=2                    " always show the status line
set ruler                           " show line/column in the status line
set showcmd                         " show the partial command in the last line
set wildmenu                        " menu for command line completion
set autoread                        " reload files changed outside vim
set display=lastline                " show as much as possible of the last line
set belloff=all                     " no bells
set ttimeout ttimeoutlen=50         " short wait for terminal key codes (Esc, Alt)

" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
" Options (same as options.lua)

set nobackup                        " creates a backup file
if has('clipboard')                 " the macOS system vim has no clipboard support
	set clipboard^=unnamed,unnamedplus  " use the system clipboard
endif
set cmdheight=1                     " height of the command line
set completeopt=menuone,noselect    " completion menu
set conceallevel=0                  " so that `` is visible in markdown files
set fileencoding=utf-8              " the encoding written to a file
set hlsearch                        " highlight all matches on previous search pattern
set ignorecase                      " ignore case in search patterns
set mouse=a                         " allow the mouse to be used
set pumheight=10                    " pop up menu height
set showmode                        " show the mode in the lower section
set showtabline=2                   " always show tabs
set smartcase                       " case sensitive search if it contains uppercase letters
set smartindent                     " make indenting smarter
set splitbelow                      " horizontal splits go below current window
set splitright                      " vertical splits go to the right of current window
set noswapfile                      " creates a swapfile
set timeoutlen=1000                 " time to wait for a mapped sequence to complete (ms)
set updatetime=300                  " faster updates (4000ms default)
set nowritebackup                   " no backup before overwriting a file
set noexpandtab                     " keep tabs (do not convert them to spaces)
set shiftwidth=4                    " the number of spaces inserted for each indentation
set tabstop=4                       " width of a tab
set cursorline                      " highlight the current line
set number                          " set numbered lines
set relativenumber                  " set relative numbered lines
set numberwidth=4                   " number column width
set signcolumn=yes                  " always show the sign column
set nowrap                          " display lines as one long line
set scrolloff=20                    " lines kept above/below the cursor
set sidescrolloff=8                 " columns kept left/right of the cursor
set shortmess+=c                    " no completion messages
set whichwrap+=<,>,[,],h,l          " h/l and arrows move to the previous/next line
set iskeyword+=-                    " words-with-dashes are one word

" Persistent undo. Unlike Neovim, vim writes the undo files next to the edited
" file by default, so they are kept in ~/.vim/undo instead.
set undofile
let s:undodir = expand('~/.vim/undo')
if !isdirectory(s:undodir)
	call mkdir(s:undodir, 'p', 0700)
endif
let &undodir = s:undodir

" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
" Colors
" tokyonight is a plugin, so the built-in habamax (vim >= 9) is used instead,
" with the same bright green italic comments of the Neovim config.

if has('termguicolors')
	set termguicolors                   " set term gui colors
	" Escape codes for true colors, needed when TERM is not xterm (e.g. Ghostty)
	let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
	let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
endif
augroup vimrc_colors
	autocmd!
	autocmd ColorScheme * highlight Comment guifg=#5aff3d cterm=italic gui=italic
augroup END
try
	colorscheme habamax
catch
	colorscheme desert
endtry

" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
" Keymaps

" Space as leader key
nnoremap <Space> <Nop>
let mapleader = " "
let maplocalleader = " "

" In the terminal Alt+j arrives as Esc followed by j. Tell vim that this
" sequence is the <M-j> key, so the Alt mappings below work.
if !has('gui_running')
	for s:key in ['j', 'k']
		execute "set <M-" . s:key . ">=\e" . s:key
	endfor
endif

" Window navigation (move between open windows)
nnoremap <silent> <C-h> <C-w>h
nnoremap <silent> <C-j> <C-w>j
nnoremap <silent> <C-k> <C-w>k
nnoremap <silent> <C-l> <C-w>l

" Resize with arrows
nnoremap <silent> <C-Up> :resize -2<CR>
nnoremap <silent> <C-Down> :resize +2<CR>
nnoremap <silent> <C-Left> :vertical resize -2<CR>
nnoremap <silent> <C-Right> :vertical resize +2<CR>

" Navigate buffers
nnoremap <silent> <S-h> :bprevious<CR>
nnoremap <silent> <S-l> :bnext<CR>

" Open/close splits
nnoremap <silent> <C-s>v :vsplit<CR>
nnoremap <silent> <C-s>h :split<CR>
nnoremap <silent> <C-s>d :close<CR>

" Jump between functions/methods (works in python)
nmap <silent> mk [m
nmap <silent> mj ]m

" Find the next occurrence of the word under the cursor
nnoremap <silent> ff yiw/<C-r>"<CR>:noh<CR>

" Insert: press jk fast to go back to normal mode
inoremap <silent> jk <Esc>

" Visual: indent/unindent keeping the selection
xnoremap <silent> < <gv
xnoremap <silent> > >gv

" Visual: paste over the selection without losing the yanked text
xnoremap <silent> p "_dP

" Visual: move the selected lines up and down
xnoremap <silent> J :move '>+1<CR>gv-gv
xnoremap <silent> K :move '<-2<CR>gv-gv
xnoremap <silent> <M-j> :move '>+1<CR>gv-gv
xnoremap <silent> <M-k> :move '<-2<CR>gv-gv

" Save file / close window / close buffer
nnoremap <silent> <leader>w :w!<CR>
nnoremap <silent> <leader>q :q<CR>
nnoremap <silent> <C-b> <Esc>:bd<CR>

" Replace text (in the whole file / in the current line). Not <silent>,
" otherwise the command line is not shown while typing the pattern.
nnoremap <leader>r1 :%s/
nnoremap <leader>r2 :s/

" Open the Neovim config (same as the 'cn' button of the alpha dashboard)
nnoremap <silent> <leader>cn :e ~/.config/nvim/init.lua<CR>

" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
" File explorer (netrw, built-in). Replaces Yazi.
" Inside netrw: Enter opens, - goes to the parent folder, % new file, d new folder.

let g:netrw_banner = 0              " hide the help banner at the top
nnoremap <silent> <leader>e :Explore<CR>

" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
" Telescope replacements (built-in commands)

" :find searches file names in all the subfolders (**) of the current folder.
" Tab completes the name, also with wildcards (e.g. :find *opt<Tab>).
set path+=**
set wildignore+=*/.git/*,*/node_modules/*,*/.venv/*,*/__pycache__/*,*.pyc,*.DS_Store
if has('patch-8.2.4325')
	set wildoptions=pum                 " show the completions in a popup menu
endif

" :Grep {pattern} searches the text in all the files below the current folder
" and shows the results in the quickfix list (Enter jumps to the result,
" :cnext/:cprev move between results).
command! -nargs=1 Grep execute 'silent vimgrep /' . escape(<q-args>, '/') . '/gj **' | copen | redraw!

nnoremap <leader>f :find<Space>
nnoremap <leader>t :Grep<Space>
nnoremap <silent> <leader>gs :Grep <C-r><C-w><CR>
nnoremap <leader>bb :ls<CR>:buffer<Space>
nnoremap <silent> <leader>bo :browse oldfiles<CR>
nnoremap <silent> <leader>br :registers<CR>

" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
" Surround (same keys as the nvim-surround mappings in surround.lua)
" The old pure-vim mappings (commented in surround.lua) used ciw/di(/x, which
" overwrite the yank register and the system clipboard and break on empty
" pairs like () or "". These functions edit the line directly instead.

" Surround the word under the cursor with open/close
function! s:SurroundWord(open, close) abort
	" Select the word to set the '< and '> marks on its first and last char
	execute "normal! viw\<Esc>"
	let l:lnum = line("'<")
	let l:line = getline(l:lnum)
	let l:start = col("'<") - 1                              " 0-based byte index
	" '> is the first byte of the last char: add the char length (multibyte)
	let l:end = col("'>") - 1 + len(matchstr(l:line, '.', col("'>") - 1))
	call setline(l:lnum, strpart(l:line, 0, l:start) . a:open
		\ . strpart(l:line, l:start, l:end - l:start) . a:close . strpart(l:line, l:end))
endfunction

" Return [line1, col1, line2, col2] of the open/close pair around the cursor
" (1-based byte columns), or [] if there is none.
function! s:FindPair(open, close) abort
	if a:open ==# a:close
		" Quotes: only on the current line. Pair them from the start of the
		" line (1st with 2nd, 3rd with 4th, ...) and take the pair that
		" contains the cursor, or the first one after it (like vi").
		let l:line = getline('.')
		let l:cur = col('.') - 1
		let l:pos = []
		let l:i = stridx(l:line, a:open)
		while l:i >= 0
			call add(l:pos, l:i)
			let l:i = stridx(l:line, a:open, l:i + 1)
		endwhile
		for l:k in range(0, len(l:pos) - 2, 2)
			if l:pos[l:k + 1] >= l:cur
				return [line('.'), l:pos[l:k] + 1, line('.'), l:pos[l:k + 1] + 1]
			endif
		endfor
		return []
	endif
	" Brackets: searchpairpos handles nested pairs and multiple lines.
	" b = backward, c = accept a match at the cursor, n = do not move, W = no wrap
	let l:o = '\V' . escape(a:open, '\')
	let l:c = '\V' . escape(a:close, '\')
	if getline('.')[col('.') - 1] ==# a:close
		" On the closing bracket: search the opening one backward from here
		let [l:l2, l:c2] = [line('.'), col('.')]
		let [l:l1, l:c1] = searchpairpos(l:o, '', l:c, 'bnW')
	else
		let [l:l1, l:c1] = searchpairpos(l:o, '', l:c, 'bcnW')
		let [l:l2, l:c2] = searchpairpos(l:o, '', l:c, 'nW')
	endif
	return (l:l1 > 0 && l:l2 > 0) ? [l:l1, l:c1, l:l2, l:c2] : []
endfunction

" Replace the char at line lnum, byte column col (1-based) with text
function! s:SetChar(lnum, col, text) abort
	let l:line = getline(a:lnum)
	call setline(a:lnum, strpart(l:line, 0, a:col - 1) . a:text . strpart(l:line, a:col))
endfunction

" Replace the pair open/close around the cursor with new_open/new_close
" (empty strings remove the pair)
function! s:ChangeSurround(open, close, new_open, new_close) abort
	let l:p = s:FindPair(a:open, a:close)
	if empty(l:p)
		echo 'No ' . a:open . a:close . ' around the cursor'
		return
	endif
	" Change the closing char first, so the column of the opening one is still valid
	call s:SetChar(l:p[2], l:p[3], a:new_close)
	call s:SetChar(l:p[0], l:p[1], a:new_open)
endfunction

nnoremap <silent> (( :call <SID>SurroundWord('(', ')')<CR>
nnoremap <silent> "" :call <SID>SurroundWord('"', '"')<CR>
nnoremap <silent> '' :call <SID>SurroundWord("'", "'")<CR>
nnoremap <silent> `` :call <SID>SurroundWord('`', '`')<CR>
nnoremap <silent> )) :call <SID>ChangeSurround('(', ')', '', '')<CR>
nnoremap <silent> "( :call <SID>ChangeSurround('"', '"', '(', ')')<CR>
nnoremap <silent> ") :call <SID>ChangeSurround('"', '"', '(', ')')<CR>
nnoremap <silent> (" :call <SID>ChangeSurround('(', ')', '"', '"')<CR>
nnoremap <silent> )" :call <SID>ChangeSurround('(', ')', '"', '"')<CR>
nnoremap <silent> "' :call <SID>ChangeSurround('"', '"', "'", "'")<CR>
nnoremap <silent> '" :call <SID>ChangeSurround("'", "'", '"', '"')<CR>

" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
" Comments: gcc (line, with count) and gc (visual selection / motion)
" Vim >= 9.1.0375 ships the comment package with these keys. The macOS
" system vim may be older: in that case a simple version is defined here.

silent! packadd comment
if maparg('gcc', 'n') ==# ''
	" Comment/uncomment the lines l1..l2 using 'commentstring' (set by the
	" filetype, e.g. "# %s" for python, "-- %s" for lua, "\" %s" for vim)
	function! s:ToggleComment(l1, l2) abort
		if &commentstring !~# '%s'
			return
		endif
		let [l:left, l:right] = map(split(&commentstring, '%s', 1), 'trim(v:val)')
		let l:lines = getline(a:l1, a:l2)
		let l:nonblank = filter(copy(l:lines), 'v:val =~# "\\S"')
		let l:lpat = '^\s*\V' . escape(l:left, '\')
		" Commented if every non-blank line starts with the comment string
		let l:commented = !empty(l:nonblank)
			\ && empty(filter(copy(l:nonblank), 'v:val !~# l:lpat'))
		if l:commented
			" Remove 'left ' at the start and ' right' at the end
			call map(l:lines, 'substitute(v:val, ''^\(\s*\)\V'' . escape(l:left, ''\'') . ''\m \?'', ''\1'', "")')
			if l:right !=# ''
				call map(l:lines, 'substitute(v:val, ''\m \?\V'' . escape(l:right, ''\'') . ''\m\s*$'', "", "")')
			endif
		else
			" Insert 'left ' at the smallest indentation, so the block stays aligned
			let l:indent = min(map(copy(l:nonblank), 'len(matchstr(v:val, "^\\s*"))'))
			call map(l:lines, 'v:val =~# "\\S" ? strpart(v:val, 0, l:indent) . l:left . " "'
				\ . ' . strpart(v:val, l:indent) . (l:right ==# "" ? "" : " " . l:right) : v:val')
		endif
		call setline(a:l1, l:lines)
	endfunction

	" Used by gc{motion}: '[ and '] are the first/last line of the motion
	function! s:CommentOperator(type) abort
		call s:ToggleComment(line("'["), line("']"))
	endfunction

	nnoremap <silent> gcc :<C-u>call <SID>ToggleComment(line('.'), line('.') + v:count1 - 1)<CR>
	xnoremap <silent> gc :<C-u>call <SID>ToggleComment(line("'<"), line("'>"))<CR>
	nnoremap <silent> <expr> gc "\<Cmd>set operatorfunc=" . expand('<SID>') . "CommentOperator\<CR>g@"
endif
