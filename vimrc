" Load pathogen
call pathogen#infect()

colorscheme freya
set guifont=Monospace\ 12
set guioptions-=T
set guioptions-=m
set guioptions+=LlRrb
set guioptions-=LlRrb

set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set autoindent
set number
set hlsearch
set incsearch
set ignorecase
set smartcase
set gdefault
set textwidth=0
set undolevels=1000
set history=50
set ruler
set showcmd
set showmatch
filetype plugin indent on
syntax on
" set autowrite
set hidden
set nocompatible
set undofile
set undodir=/tmp
set wildignore=*.bak,*.os,*.so,*.png,*.svg,*.d,*.o
let mapleader = ","
set backspace=indent,eol,start
nnoremap j gj
nnoremap k gk

" Complete options (disable preview scratch window)
set completeopt=menu,menuone,longest
" Limit popup menu height
set pumheight=15
" SuperTab option for context aware completion
let g:SuperTabDefaultCompletionType = "<c-x><c-u>"

" Disable cursor keys for hjkl training!
" noremap  <Up> ""
" noremap! <Up> <Esc>
" noremap  <Down> ""
" noremap! <Down> <Esc>
" noremap  <Left> ""
" noremap! <Left> <Esc>
" noremap  <Right> ""
" noremap! <Right> <Esc>

" hi ColorColumn guibg=#383838
highlight OverLength guibg=#402929
match OverLength /\%121v.\+/

" Commenting/Uncommenting function
function! Comment() range
    let commentChar = '#'
    if &filetype == "cpp" || &filetype == "mel"
        let commentChar = '//'
    endif
    if getline( a:firstline ) =~ commentChar
        execute ":" . a:firstline . "," . a:lastline . 's,^' . commentChar . ',,'
    else
        execute ":" . a:firstline . "," . a:lastline . 's,^,' . commentChar . ','
    endif
endfunction

map <silent> ,/ :call Comment()<CR>

" Eclim settings
let g:EclimLocateFileDefaultAction="edit"
let g:EclimCSearchSingleResult = 'edit'
nmap <silent> <F2> :LocateFile<CR>
set statusline=%<%f\ %M\ %h%r%=%-10.(%l,%c%V\ %{eclim#project#util#ProjectStatusLine()}%)\ %P
let g:EclimProjectStatusLine = 'eclim(p=${name})'

" Window navigating shortcuts
nmap <c-j> <c-w>j
nmap <c-k> <c-w>k
nmap <c-l> <c-w>l
nmap <c-h> <c-w>h
set wmh=0

" Switch between .h/.cpp
nmap <silent> <F1> :A<CR>


" Minibuffer explorer settings
let g:miniBufExplMapWindowNavVim = 1
let g:miniBufExplMapWindowNavArrows = 1
let g:miniBufExplMapCTabSwitchBufs = 1
let g:miniBufExplModSelTarget = 1
" let g:miniBufExplVSplit = 20
let g:miniBufExplMaxSize = 40

" Faster Esc
inoremap jk <esc>

function! s:InsertCppTemplate()
    silent! 0r ~/.vim/templates/c_template
    let filename = expand("%:t")
    exec "%s/<filename>/" . filename . "/"
    let date = strftime( "%h %e, %Y" )
    exec "%s/<date>/" . date . "/"
    let project = eclim#project#util#GetCurrentProjectName()
    exec "%s/<project>/" . project . "/"
    normal! G
endfunction

function! s:InsertHeaderTemplate()
    let gatename = substitute(toupper(expand("%:t")), "\\.", "_", "g")
    execute "normal! i#ifndef " . gatename
    execute "normal! o#define " . gatename
    execute "normal! 3o"
    execute "normal! o#endif /* " . gatename . " */"
    execute "normal! 2k"
endfunction
autocmd BufNewfile *.{c,cpp,h} call <SID>InsertCppTemplate()
autocmd BufNewfile *.h call <SID>InsertHeaderTemplate()

