
let g:vwm_statusline = get(g:, 'vwm_statusline', [
    \ {'text': ' %{vwm#status#ff()}', 'highlight': ['Status3', 'StatusLineNC']},
    \ {'text': " %{expand('%:.')}", 'highlight': ['StatusFile', 'StatusFileNC']},
    \ {'text': "%{&modified ? '  ✘': ''}", 'highlight': ['StatusModified', 'StatusLineNC']},
    \ {'text': '  %{vwm#status#func()}', 'highlight': ['StatusFunc', 'StatusLineNC']},
    \ '%#StatuslineNC#%r%h%w%=',
    \ ' %#StatusBufNr##%n',
    \ {'text': '  %{vwm#status#ft()}', 'highlight': ['StatusFileType', 'StatusLineNC']},
    \ {'text': '  %{vwm#status#fenc()}', 'highlight': ['Status3', 'StatusLineNC']},
    \ {'text': '  %p%%', 'highlight': ['StatusPercent', 'StatusLineNC']},
    \ {'text': '  %l:%-v ', 'highlight': ['StatusLineNr', 'StatusLineNC']},
\ ])

fun! vwm#status#toggle()
    if s:is_enabled()
        return vwm#status#disable()
    else
        return vwm#status#enable()
    endif
endf

fun! vwm#status#enable()
    augroup Statusline
        au WinEnter,BufWinEnter,FileType,ColorScheme * call vwm#status#update()
        au CursorMoved,BufUnload * call vwm#status#update()
    augroup END
    call vwm#status#hilight()
    if get(g:, 'vwm#status#interval')
        let g:vwm_status_timer = timer_start(g:vwm#status#interval, {t->vwm#status#update()}, {'repeat': -1})
        au CmdlineEnter * call timer_pause(g:vwm_status_timer, 1)
        au CmdlineLeave * call timer_pause(g:vwm_status_timer, 0)
    endif
endf

fun! vwm#status#disable()
    sil! au! Statusline
    sil! augroup! Statusline
endf

fun! s:is_enabled()
    try
        au Statusline
        return 1
    catch
        return 0
    endtry
endf

if has('nvim')
    fun! s:strip_alt(c)
        let k = type(a:c) == v:t_number ? nr2char(a:c): a:c
        return len(k) > 1 ? split(k, '.\zs')[-1]: k
    endf
else
    fun! s:strip_alt(c)
        if type(a:c) == v:t_number
            let n = a:c
            return nr2char(n > 127 ? n - 128 : n)
        endif
        return a:c
    endf
endif

fun! vwm#status#goto(...)
    let nr = a:0 ? a:1 : nr2char(getchar())
    let bufs = vwm#get_bufs()

    " 两位数
    if len(bufs) >= nr * 10
        let n = s:strip_alt(getchar())
        let nr = nr . n
    endif

    let nr = get(bufs, nr - 1)
    if nr && !vwm#goto_buffer(nr)       " goto exists window
        if a:0 > 1                      " split window
            let split = 'winc s'
            let direction = ''
            if index(a:000, 'right') > 0
                let [split, direction] = ['winc v', 'belowright']
            endif
            if index(a:000, 'left') > 0
                let [split, direction] = ['winc v', 'aboveleft']
            endif
            if index(a:000, 'below') > 0
                let direction = 'belowright'
            endif
            if index(a:000, 'above') > 0
                let direction = 'aboveleft'
            endif
            if len(direction) | exe direction split | endif
        endif
        " call vwm#goto_normal_window(nr)
        " switch buffer
        exe nr 'b!'
    endif
endf

fun! vwm#status#mouse_goto(idx, double, key, pressed)
    call vwm#goto_normal_window()
    call vwm#status#goto(a:idx)

    if a:key == 'r'
        call vwm#close_buffer()
    endif

    if a:key == 'l' && a:double == 2
        call vwm#open_this()
    endif
endf

" set tabline=%!vwm#status#bufs()
fun! vwm#status#bufs()
    return s:to_tabline(vwm#status#dispatch_bufs())
endf

" set tabline=%!vwm#status#tabs()
fun! vwm#status#tabs()
    return s:to_tabline(vwm#status#tabbufs())
endf

" Get buffer list of tabpages
fun! vwm#status#tabbufs()
    let list = []
    for i in range(1, tabpagenr('$'))
        let fl = tabpagebuflist(i)
        let j = tabpagewinnr(i)-1
        let nr = fl[j]
        let e = j
        while !empty(getbufvar(nr, '&bt'))
            let j = (j+1) % len(fl)
            if j == e | break | endif
            let nr = fl[j]
        endw
        call add(list, nr)
    endfo
    return list
endf

fun! vwm#status#dispatch_bufs()
    let norm_bufs = []
    let bottom_bufs = []
    let left_bufs = []
    for info in getbufinfo({'buflisted': 0, 'bufloaded': 0})
        let bnr = info['bufnr']
        let bt = getbufvar(bnr, '&bt')
        let ft = getbufvar(bnr, '&ft')
        if bt == '' && info.listed
            call add(norm_bufs, bnr)
        elseif has_key(g:, 'vwm_left_filetype') && has_key(g:vwm_left_filetype, ft)
            call add(left_bufs, bnr)
        elseif info.listed && bt == 'quickfix' || bt == 'terminal'
            call add(bottom_bufs, bnr)
        endif
    endfor
    let g:vwm_bottom_bufs = bottom_bufs
    let g:vwm_left_bufs = left_bufs

    let g:norm_bufs = norm_bufs
    return norm_bufs
endf

fun! vwm#status#update()
    call vwm#status#dispatch_bufs()
    for wnr in range(1, winnr('$'))
        let g:curwin = wnr
        let g:curbuf = winbufnr(wnr)

        let StatusConfig = getwinvar(wnr, 'vwm_statusline', g:vwm_statusline)
        let t = type(StatusConfig)
        if t == v:t_func | let StatusConfig = StatusConfig() | endif
        let t = type(StatusConfig)

        if t == v:t_list
            call setwinvar(wnr, '&statusline', join(s:build_statusline(StatusConfig, wnr), ''))
        elseif t == v:t_func
            call setwinvar(wnr, '&statusline', StatusConfig())
        elseif t == v:t_string
            call setwinvar(wnr, '&statusline', StatusConfig)
        endif
    endfor
endf

fun! s:build_statusline(l, wnr)
    let cur_win = winnr()
    let inactive = a:wnr != cur_win
    let result = []
    for Item in a:l
        let text = ''
        let hili = ''
        if type(Item) == v:t_func
            let Item = Item()
        endif
        if type(Item) == v:t_string
            let text = Item
        elseif type(Item) == v:t_dict
            let Text = get(Item, 'text', '')
            let text = type(Text) == v:t_func ? Text(): Text
            let hili = get(Item, 'highlight')
            if type(hili) == v:t_list
                let hili = hili[inactive]
            endif
            if !empty(hili)
                let text = '%#' . hili . '#' . text
            endif
        endif
        if len(text)
            let text = len(hili) ? '%#' . hili . '#' . text : text
            call add(result, text)
        endif
    endfor
    return result
endf

fun! vwm#status#func()
    let result = get(b:, 'vista_nearest_method_or_function', '')
    " let result = get(b:, 'coc_current_function', '')
    return len(result) ? ' ' . result : result
endf

let g:vwm_default_icon = get(g:, 'vwm_default_icon', '')
let g:vwm_ft_icon = extend({
    \ 'html': '',
    \ 'css': '',
    \ 'less': '',
    \ 'markdown': '',
    \ 'json': '',
    \ 'javascript': '',
    \ 'jsx': '',
    \ 'php': '',
    \ 'python': '',
    \ 'coffee': '',
    \ 'conf': '',
    \ 'dosini': '',
    \ 'gitconfig': '',
    \ 'yaml': '',
    \ 'dosbatch': '',
    \ 'cpp': '',
    \ 'c': '',
    \ 'lua': '',
    \ 'java': '',
    \ 'sh': '',
    \ 'fish': '',
    \ 'bash': '',
    \ 'zsh': '',
    \ 'awk': '',
    \ 'ps1': '',
    \ 'sql': '',
    \ 'dump': '',
    \ 'scala': '',
    \ 'go': '',
    \ 'dart': '',
    \ 'rust': '',
    \ 'vim': '',
    \ 'typescript': '',
\ }, get(g:, 'vwm_ft_icon',{}))

"     
fun! vwm#status#ft()
    let ft = &ft
    return empty(g:vwm_default_icon) ? ft :
        \ get(g:vwm_ft_icon, ft, g:vwm_default_icon) . ' ' . ft
endf

fun! vwm#status#ff()
    return &ff == 'dos' ? '' : &ff == 'unix' ? '' : ''
endf

fun! vwm#status#fenc()
    return ' ' . &fenc
endf

fun! vwm#status#left()
    return [
        \ {'text': '▓▒░', 'highlight': 'Status2'},
        \ {'text': join(s:to_status([], get(g:, 'vwm_left_bufs', []), g:curbuf), '')},
        \ {'text': '', 'highlight': 'StatusLineNC'},
        \ '%#StatuslineNC#%=',
        \ '%#StatusBufNr##%n',
    \ ]
endf

fun! s:hi(group, gfg, gbg, cfg, cbg)
    exe 'hi!' a:group
        \ empty(a:gfg) ? '': 'guifg='.a:gfg
        \ empty(a:gbg) ? '': 'guibg='.a:gbg
        \ empty(a:cfg) ? '': 'ctermfg='.a:cfg
        \ empty(a:cbg) ? '': 'ctermbg='.a:cbg
endf

fun! HiCopy(dest, from)
    let t = split(execute('hi ' . a:from), '\n*\s\+')[2:]
    if t[0] == 'links' && t[1] == 'to'
        return HiCopy(a:dest, t[2])
    endif

    let l = []
    let grev = 0
    let crev = 0
    for item in t
        let kv = split(item, '=')
        if len(kv) == 1 && item == 'links'
            break
        elseif kv[0] == 'gui' && kv[1] =~ 'reverse'
            let grev = 1
            let item = substitute(item, '\vreverse,?', '', '')
        elseif kv[0] == 'cterm' && kv[1] =~ 'reverse'
            let crev = 1
            let item = substitute(item, '\vreverse,?', '', '')
        endif
        let item = item =~ '=$' ? '': item
        call add(l, item)
    endfor

    let F = {s->s[0] =~ 'fg$' ? 'bg': 'fg'}
    let l = grev ? map(l, {i,v->substitute(v, '\vgui\zsfg|gui\zsbg', F, '')}) : l
    let l = crev ? map(l, {i,v->substitute(v, '\vcterm\zsfg|cterm\zsbg', F, '')}) : l
    let t = join(l)

    sil! exec 'hi' 'clear' a:dest
    sil! exec 'hi' a:dest t
endf

fun! vwm#status#hilight()
    hi! default link TabLineSel StatusLine
    hi! default link TabLineFill StatusLineNC
    hi! default link TabLineItem StatusLineNC
    hi! default link TabLineDir TabLineSel

    hi! default link StatusBufNr Status1
    hi! default link StatusFile StatusLine
    hi! default link StatusItem StatusLineNC
    hi! default link StatusItemSel StatusFile

    hi! default link StatusFileNC StatusLineNC

    sil! hi StatusCur guifg=#3a3a3a guibg=#febf48
    sil! hi Status1 guifg=#c2bfbc guibg=#606060
    sil! hi Status2 guifg=#c2bfbc guibg=#4e4e4e
    sil! hi Status3 guifg=#c2bfbc guibg=#444444
    sil! hi LeftPanelNormal guibg=#252525
    sil! hi LeftPanelCursorLine guibg=#2F3F46

    let nr = hlID('CursorLineNr')
    let nr_fg_g = synIDattr(nr, 'fg', 'gui')
    let nr_fg_c = synIDattr(nr, 'fg', 'cterm')

    call HiCopy('TabLineWarn', 'TabLineItem')
    exec 'hi' 'TabLineWarn' 'guifg='.'red' 'ctermfg='.'red'

    call HiCopy('TabLineNum', 'TabLineItem')
    exec 'hi' 'TabLineNum' 'guifg='.nr_fg_g 'ctermfg='.nr_fg_c

    call HiCopy('TabLineSelWarn', 'TabLineSel')
    exec 'hi' 'TabLineSelWarn' 'guifg='.'red' 'ctermfg='.'red'

    call HiCopy('TabLineTemp', 'TabLineItem')
    exec 'hi' 'TabLineTemp' 'gui=italic' 'cterm=italic'

    call HiCopy('TabLineTempSel', 'TabLineSel')
    exec 'hi' 'TabLineTempSel' 'gui=italic' 'cterm=italic'

    call HiCopy('StatusFunc', 'StatusLineNC')
    exec 'hi' 'StatusFunc' 'guifg='.'#d7875f'

    call HiCopy('StatusModified', 'StatusLineNC')
    exec 'hi' 'StatusModified' 'guifg=red'

    call HiCopy('StatusFile', 'StatusLineNC')
    " exec 'hi' 'StatusFile' 'gui=underline' 'guifg=#afd700'
    exec 'hi' 'StatusFile' 'guifg=yellow'

    call HiCopy('StatusPercent', 'StatusLineNC')
    exec 'hi' 'StatusPercent' 'guifg=#af87d7'

    call HiCopy('StatusLineNr', 'StatusLineNC')
    exec 'hi' 'StatusLineNr' 'guifg=#ff5faf'

    call HiCopy('StatusFileType', 'StatusLineNC')
    exec 'hi' 'StatusFileType' 'guifg=#5fafd7'

    call HiCopy('StatusBufNr', 'StatusLineNC')
    exec 'hi' 'StatusBufNr' 'guifg=#808080'

    call HiCopy('Status1', 'StatusLineNC')
    exec 'hi' 'Status1' 'guifg=#d7af5f'
    call HiCopy('Status2', 'StatusLineNC')
    exec 'hi' 'Status2' 'guifg=#af87d7'
    call HiCopy('Status3', 'StatusLineNC')
    exec 'hi' 'Status3' 'guifg=#00afaf'
endf

au VimEnter,ColorScheme * call timer_start(0, {t->vwm#status#hilight()})

fun! s:to_status(l, nrs, cur)
    let result = a:l
    for nr in a:nrs
        let name = bufname(nr)
        let ft = getbufvar(nr, '&ft')
        if getbufvar(nr, '&bt') == 'quickfix'
            let name = 'QuickFix'
        elseif getbufvar(nr, '&bt') == 'terminal'
            let name = matchstr(name, '\d\+.*$')
        elseif has_key(g:vwm_left_filetype, ft)
            let name = g:vwm_left_filetype[ft]
        endif

        if nr == a:cur
            call add(result, '%#StatusItemSel# ' . name . ' %##')
        else
            call add(result, '%#StatusItem# ' . name . ' ')
        endif
    endfor
    return result
endf

fun! vwm#status#bottom()
    let git_state = ''
    if exists('*FugitiveHead')
        let git_state = FugitiveHead()
    else
        sil! let git_state = gina#component#repo#branch()
    endif
    if len(git_state)
        let git_state = '   ' . git_state
    endif

    let coc_status = exists('*coc#status') ? coc#status() : ''
    if len(coc_status)
        let coc_status = ' ' . coc_status . ' '
    endif

    return [
        \ {'text': '█▓▒░', 'highlight': 'Status2'},
        \ {'text': join(s:to_status([], get(g:, 'vwm_bottom_bufs', []), g:curbuf), '')},
        \ {'text': '%=', 'highlight': 'StatusLineNC'},
        \ '%#StatusBufNr##%n',
        \ {'text': coc_status, 'highlight': 'Status3'},
        \ {'text': git_state, 'highlight': 'Status1'},
        \ {'text': '  %p%%', 'highlight': ['StatusPercent', 'StatusLineNC']},
        \ {'text': '  %l:%-v ', 'highlight': ['StatusLineNr', 'StatusLineNC']},
    \ ]
endf

fun! s:list_next(l, e)
    let i = index(a:l, a:e)
    return i >= 0 ? a:l[(i + 1) % len(a:l)] : 0
endf

fun! s:list_prev(l, e)
    let i = index(a:l, a:e)
    return i >= 0 ? a:l[i - 1] : 0
endf

fun! vwm#status#next()
    let nr = 0
    if win_getid() == get(g:, 'vwm_bottom_panel')
        let nr = s:list_next(g:vwm_bottom_bufs, bufnr('%'))
    endif
    if win_getid() == get(g:, 'vwm_left_panel')
        let nr = s:list_next(g:vwm_left_bufs, bufnr('%'))
    endif

    if nr
        sil! exec nr 'b'
        return
    endif

    let nr = s:list_next(g:norm_bufs, bufnr('%'))
    if nr && !vwm#goto_buffer(nr)
        call vwm#goto_normal_window(nr)
        exe nr 'b!'
    endif
endf

fun! vwm#status#prev()
    let nr = 0
    if win_getid() == get(g:, 'vwm_bottom_panel')
        let nr = s:list_prev(g:vwm_bottom_bufs, bufnr('%'))
    endif
    if win_getid() == get(g:, 'vwm_left_panel')
        let nr = s:list_prev(g:vwm_left_bufs, bufnr('%'))
    endif

    if nr
        exec nr 'b'
        return
    endif

    let nr = s:list_prev(g:norm_bufs, bufnr('%'))
    if nr && !vwm#goto_buffer(nr)
        call vwm#goto_normal_window(nr)
        exe nr 'b!'
    endif
endf

fun! s:get_item(i, nr)
    let is_curnr = bufnr('%') == a:nr
    let modified = getbufvar(a:nr, '&mod')
    let temp = getbufvar(a:nr, '&bh') == 'delete' && empty(getbufvar(a:nr, '&bt'))
    let file = pathshorten(fnamemodify(bufname(a:nr), ':.'))
    let name = empty(file) ? '[new_' . a:nr . ']': file
    return ['%#TabLineNum# ', a:i,
          \ is_curnr ?
              \ temp ? ' %#TabLineTempSel# '
                  \ : (modified ? ' %#TabLineSelWarn# ': ' %#TabLineSel# ')
            \ : temp ? ' %#TabLineTemp#'
                  \ : (modified ? ' %#TabLineWarn#': ' %#TabLineItem#'),
          \ name, is_curnr ? ' ': '']
endf

fun! s:get_dir()
    return ['%#TabLineDir# ', fnamemodify(getcwd(), ':t'), '/ ', '%#Normal# ']
endf

fun! s:get_tabs()
    let last_tnr = tabpagenr('$')
    return last_tnr > 1 ? [tabpagenr(), '/', last_tnr, ' '] : []
endf

let s:tablineat = has('tablineat')
fun! s:to_tabline(nrs)
    let i = 1
    let l = ['']
    " Buffers
    for nr in a:nrs
        let l += ['%', i, 'T']
        if s:tablineat
            let l += ['%', i, '@vwm#status#mouse_goto@']
        endif
        let l += s:get_item(i, nr)
        let i += 1
    endfor
    " Special buffer
    let bt = &bt
    if bt == 'nofile'
        let l += ['%#TabLineNum#', printf(' [%s]', &ft)]
    elseif bt == 'help'
        let l += ['%#TabLineNum#', ' [HELP:', expand('%:t'), '] ']
    elseif bt == 'quickfix'
        let l += ['%#TabLineNum#', ' [QuickFix] ']
    elseif bt == 'terminal'
        if has('nvim')
            let l += ['%#TabLineNum#', printf(' [%s:%d]', b:term_title, b:terminal_job_pid)]
        endif
    endif
    " Tabfill
    let l += ['%#TabLineFill#', '%=']
    let l += s:get_dir()
    let l += s:get_tabs()
    return join(l, '')
endf
