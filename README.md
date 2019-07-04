
# Vim's Window Manager

## Features

* Window Management like VSCode
* Built-in Text-Search like VSCode
* Built-in Workspace(session) support
* Built-in statusline/bufline support
* Built-in Bookmark support

## ScreenShots

Overview:
![vwm](https://user-images.githubusercontent.com/9403405/60673271-fa72cd00-9ea9-11e9-9831-c62283e316a3.png)

Symbol:
![vwm-symbol](https://user-images.githubusercontent.com/9403405/60673282-fe9eea80-9ea9-11e9-89ef-9f18e4ce3acd.png)

Search Dialog/Results:
![vwm-search](https://user-images.githubusercontent.com/9403405/60673287-01014480-9eaa-11e9-8b3a-0ea51457b677.png)

## Basic&Recommended Requires

* Neovim 0.4.0-982+
* [defx.nvim](https://github.com/Shougo/defx.nvim)
* [vista.vim](https://github.com/liuchengxu/vista.vim)

### Show session list via [vim-startify](https://github.com/mhinz/vim-startify)

```viml
let padding_left = '  '
let g:startify_lists = [
    \ {'header': [padding_left .'Sessions'], 'type': function('vwm#ss#startify')},
    \ {'header': [padding_left .'Recently '. getcwd()], 'type': 'dir'},
    \ {'header': [padding_left .'Recently'], 'type': 'files'},
    \ {'header': [padding_left .'Commands'], 'type': 'commands'},
\ ]
```

### Select session via [denite.nvim](https://github.com/Shougo/denite.nvim)

```viml
nnoremap <silent><c-r> :Denite session<cr>
```

## Config && Usage

```viml
let g:vwm#status#interval = 200

call vwm#init()
set showtabline=2
set tabline=%!vwm#status#bufs()

" Settings for switch-buffer
nnore <silent><m-1> :call vwm#status#goto(1)<cr>
nnore <silent><m-2> :call vwm#status#goto(2)<cr>
nnore <silent><m-3> :call vwm#status#goto(3)<cr>
nnore <silent><m-4> :call vwm#status#goto(4)<cr>
nnore <silent><m-5> :call vwm#status#goto(5)<cr>
nnore <silent><m-6> :call vwm#status#goto(6)<cr>
nnore <silent><m-7> :call vwm#status#goto(7)<cr>
nnore <silent><m-8> :call vwm#status#goto(8)<cr>
nnore <silent><m-9> :call vwm#status#goto(9)<cr>

nnore <silent><m-i> :call vwm#status#prev()<cr>
nnore <silent><m-o> :call vwm#status#next()<cr>

nnore <silent><c-f4> :call vwm#close_buffer()<cr>

" Settings for toggle panel
nnore <silent><c-1>  :call vwm#toggle_explorer()<cr>
tnore <silent><c-1>  :call vwm#toggle_explorer()<cr>
nnore <silent><c-2>  :call vwm#toggle_quickfix()<cr>
tnore <silent><c-2>  :call vwm#toggle_quickfix()<cr>
nnore <silent><c-3>  :call vwm#toggle_terminal()<cr>
tnore <silent><c-3>  :call vwm#toggle_terminal()<cr>
nnore <silent><c-4>  :call vwm#toggle_symbol()<cr>
tnore <silent><c-4>  :call vwm#toggle_symbol()<cr>

" Settings for adjust window size
nnore <silent><m-s>   :call vwm#add_size()<cr>
nnore <silent><m-s-s> :call vwm#dec_size()<cr>
tnore <silent><m-s>   :call vwm#add_size()<cr>
tnore <silent><m-s-s> :call vwm#dec_size()<cr>

" Settings for text-search
nnore <leader>s :call vwm#rg#ui('', {})<cr>
nnore <leader>w :call vwm#rg#ui(expand('<cword>'), {'word': 1})<cr>

" Settings for bookmark feature
nnore <silent>mm :call vwm#bm#toggle()<cr>
nmap  <silent>mk :call vwm#bm#jump_prev()<cr>
nmap  <silent>mj :call vwm#bm#jump_next()<cr>
nnore <silent>ma :call vwm#bm#copen()<cr>
nnore <silent>me :call vwm#bm#toggle('label')<cr>
```
