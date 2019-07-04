
# Vim's Window Manager

## Features

* Window Management like VSCode
* Built-in Text-Search like VSCode
* Built-in Workspace(session) support
* Built-in statusline/bufline support
* Built-in Bookmark support

## Basic & Recommended Requires

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
