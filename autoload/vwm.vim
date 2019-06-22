
let g:vwm_left_panel = 0
let g:vwm_bottom_panel = 0

let g:vwm_left_width = get(g:, 'vwm_left_width', 35)
let g:vwm_bottom_height = get(g:, 'vwm_bottom_height', 10)
let g:vwm_left_buffer = 0
let g:vwm_bottom_buffer = 0

let g:vwm_left_size = get(g:, 'vwm_left_size', [42, 0.3, 0.7, 1.0])
let g:vwm_bottom_size = get(g:, 'vwm_bottom_size', [0.2, 0.5, 1.0])

let g:vwm_left_filetype = {
    \ 'ctrlsf': 'Search',
    \ 'defx': 'Defx',
    \ 'vista_kind': 'Symbols', 'vista': 'Symbols',
    \ 'rg_term': 'Search',
\ }

let g:vwm_bottom_filetype = {}

fun! vwm#init()
    augroup VWM
        au WinEnter * call vwm#check_layout()
        " au WinLeave * call vwm#check_term_exit()
        au BufWinEnter,BufWinLeave,WinEnter,WinLeave * call vwm#update_panel_info()
        if has('nvim')
            au FileType,BufWinEnter,TermOpen * call vwm#check_panel()
        else
            au FileType,BufWinEnter,TerminalOpen * call vwm#check_panel()
        endif
    augroup END

    com! -nargs=+ -complete=command VwmInNormWin call vwm#do_in_normal_window(<q-args>)
    com! -nargs=* -complete=shellcmd VwmTerminal call vwm#terminal(<q-args>)

    call vwm#status#hilight()
endf

fun! vwm#copen()
    call vwm#open_bottom_panel()
    call vwm#switch_to_quickfix()
endf

if has('nvim')
fun! vwm#termopen(cmd, ...)
    ene!
    return a:0 ? termopen(a:cmd, a:1) : termopen(a:cmd)
endf
else
endif

fun! vwm#terminal(...)
    let bnr = bufnr('%')
    " 在Bottom Panel中切换Terminal
    call vwm#open_bottom_panel()
    " 保证处于当前buffer的上下文中
    exec bnr . 'b'

    if has('nvim')
        exec 'terminal' join(a:000)
    else
        exec 'terminal' '++curwin' join(a:000)
    endif

    call vwm#status#update()
endf

fun! vwm#scrach()
    ene!
    setl bt=nofile bh=delete
endf

fun! vwm#toggle_terminal()
    let tnr = get(g:, 'vwm_terminal')
    if bufnr('%') == tnr
        close | return
    endif

    if tnr && bufexists(tnr)
        call vwm#open_bottom_panel()
        exec tnr . 'b'
        startinsert
    else
        call vwm#terminal()
        let g:vwm_terminal = bufnr('%')
    endif
endf

fun! vwm#toggle_quickfix()
    if &bt == 'quickfix'
        close | return
    else
        call vwm#copen()
    endif
endf

fun! vwm#toggle_symbol()
    if get(g:vwm_left_filetype, &ft, '') == 'Symbols'
        close
    else
        call vwm#goto_normal_window()
        exec 'Vista'
    endif
endf

fun! vwm#switch_to_quickfix()
    let qf = 0
    for b in getbufinfo({'buflisted': 0})
        let nr = b['bufnr']
        if getbufvar(nr, '&bt') == 'quickfix'
            let qf = nr
            break
        endif
    endfor
    if qf
        sil! exec qf 'b'
    else
        ene | setl nonu bt=quickfix bh=
    endif
    call vwm#status#update()
endf

fun! vwm#check_term_exit()
    if &bt == 'terminal' && win_getid() == g:vwm_bottom_panel
     \ && jobwait([b:terminal_job_id], 0)[0] != -1
        call timer_start(0, {t->vwm#open_bottom_panel()})
    endif
endf

fun! vwm#check_layout()
    " 窗口布局中只剩左侧面板
    if winnr('$') == 1 && win_getid(winnr('$')) == g:vwm_left_panel
        let bnr = s:next_buf(g:norm_bufs)
        let w = g:vwm_left_width
        call timer_start(0, {t->[
            \ execute('botright vsplit'),
            \ execute(bnr ? bnr . 'b': 'ene'),
            \ win_gotoid(g:vwm_left_panel),
            \ vwm#make_left({'width': w}),
        \ ]})
    endif
endf

" 更新面板的宽度/高度
fun! vwm#update_panel_info()
    let wid = win_getid()
    if wid == g:vwm_left_panel
        let g:vwm_left_buffer = bufnr('%')
        let g:vwm_left_width = winwidth(0)
    endif
    if wid == g:vwm_bottom_panel
        let g:vwm_bottom_buffer = bufnr('%')
        let g:vwm_bottom_height = winheight(0)
    endif
endf

" 移动一个窗口为左面板
" fun! vwm#move_to_left(wid, bnr)
"     let wid = a:wid
"     let bnr = a:bnr
"     " 延时过后 bnr还属于wid
"     if winbufnr(wid) == bnr
"         call win_gotoid(wid)
"         " caddexpr 'wid: ' . wid . ' bnr: ' . bnr
"         " Panel存在且wid不是Panel
"         if win_id2win(g:vwm_left_panel) && wid != g:vwm_left_panel
"             noau close
"             call win_gotoid(g:vwm_left_panel)
"             let g:vwm_left_width = winwidth(0)
"             noau exec bnr 'b'
"         else
"             call vwm#make_left()
"         endif
"         call vwm#status#update()
"     endif
"     exec 'vertical' 'resize' g:vwm_left_width
" endf

fun! vwm#move_to_left(wid, bnr)
    let r = vwm#move_window(a:wid, a:bnr, g:vwm_left_panel)

    if r == 'missing'
        call vwm#make_left()
    elseif r == 'success'
        let g:vwm_left_width = winwidth(0)
        let g:vwm_left_buffer = bufnr('%')
    endif

    call vwm#status#update()
    exec 'vertical' 'resize' g:vwm_left_width
endf

fun! vwm#move_window(src_wid, src_buf, dst_wid)
    if a:src_wid == a:dst_wid
        return 'same'
    endif

    " src_wid存在且src_buf在src_wid窗口内
    if win_gotoid(a:src_wid) && winbufnr(a:src_wid) == a:src_buf
        if win_gotoid(a:dst_wid)
            noau exec a:src_buf 'b!'
            call nvim_win_close(a:src_wid, 0)
            return 'success'
        else
            return 'missing'
        endif
    else
        return 'failure'
    endif
endf

fun! vwm#move_to_bottom(wid, bnr)
    let r = vwm#move_window(a:wid, a:bnr, g:vwm_bottom_panel)

    if r == 'missing'
        call vwm#make_bottom()
    elseif r == 'success'
        let g:vwm_bottom_height = winheight(0)
        let g:vwm_bottom_buffer = bufnr('%')
    endif

    call vwm#status#update()
    exec 'resize' g:vwm_bottom_height
endf

fun! s:current_belong_bottom()
    let wnr = winnr()
    return (&bt == 'quickfix' && empty(getloclist(wnr)))
      \ || (&bt == 'terminal' && wnr == winnr('$') && winnr('k') != wnr)
endf

" 将属于面板内的buf移到面板内，不属于的移出
fun! vwm#check_panel()
    let bnr = bufnr('%')
    let wnr = winnr()
    let wid = win_getid()

    if wid == g:vwm_left_panel
        " 不属于左侧边栏所容纳的buffer类型
        if !has_key(g:vwm_left_filetype, &ft)
            let bnr = bufnr('%')
            call timer_start(0, {t->[
                \ bufnr('#') > 0 ? execute('b#'): 0,
                \ vwm#goto_normal_window(),
                \ execute(bnr . 'b'),
            \ ]})
        endif
        return
    endif

    if wid == g:vwm_bottom_panel
        return
    endif

    if has_key(g:vwm_left_filetype, &ft)
        call timer_start(1, {t->vwm#move_to_left(wid, bnr)})
        return
    endif

    if s:current_belong_bottom()
        call timer_start(0, {t->vwm#move_to_bottom(wid, bnr)})
    endif
endf

fun! vwm#open_bottom_panel()
    if !win_gotoid(g:vwm_bottom_panel)
        let bottom_bnr = 0
        for info in getbufinfo({'buflisted': 1})
            let bnr = info['bufnr']
            let bt = getbufvar(bnr, '&bt')
            if bt == 'terminal' || bt == 'quickfix'
                let bottom_bnr = bnr
                break
            endif
        endfor
        if bottom_bnr
            exec 'botright' g:vwm_bottom_height.'split' '+b'.bottom_bnr
        else
            exec 'botright' 'copen' g:vwm_bottom_height
        endif
        setl bufhidden=
        if line('$') < 2
            " cadde '==================『Bottom Panel』=================='
        endif

        call vwm#make_bottom()
    endif
    sil! noau exec g:vwm_bottom_buffer 'b'
endf

" 将一个窗口变为左侧面板
fun! vwm#make_left(...)
    let opt = a:0 ? a:1 : {}
    call assert_true(type(opt) == v:t_dict)

    let wnr = get(opt, 'winnr', winnr())
    let g:vwm_left_panel = win_getid(wnr)

    " 移至最左侧 移动之后wnr不再表示原来的窗口
    if wnr != 1 | winc H | endif

    call setwinvar(g:vwm_left_panel, 'vwm_statusline', function('vwm#status#left'))
    if exists('&winhl')
        call setwinvar(g:vwm_left_panel, '&winhl', 'Normal:LeftPanelNormal,CursorLine:LeftPanelCursorLine')
    endif

    " caddexpr 'wid: ' . g:vwm_left_panel
    call win_gotoid(g:vwm_left_panel)
    exec 'vertical' 'resize' get(opt, 'width', g:vwm_left_width)
endf

" 打开底部面板后，恢复左侧面板的位置
fun! vwm#restore_left()
    let wid = win_getid()
    if win_gotoid(g:vwm_left_panel)
        let g:vwm_left_width = winwidth(0)
        winc H
        exec 'vertical' 'resize' g:vwm_left_width
        call win_gotoid(wid)
        redraw!
    endif
endf

fun! vwm#make_bottom()
    if g:vwm_bottom_panel != win_getid()
        winc J
        let g:vwm_bottom_panel = win_getid()
        let w:vwm_statusline = function('vwm#status#bottom')
        exec 'resize' g:vwm_bottom_height
        call vwm#restore_left()
    endif
endf

fun! vwm#open_left_panel()
    if !win_gotoid(g:vwm_left_panel)
        exec 'vertical' 'topleft' g:vwm_left_width . 'split'
        call vwm#make_left()
    endif
    sil! noau exec g:vwm_left_buffer 'b'
endf

fun! vwm#close_left_panel()
    if win_gotoid(g:vwm_left_panel)
        let g:vwm_left_buffer = bufnr('%')
        let g:vwm_left_width = winwidth(0)
        close
        return 1
    endif
endf

fun! vwm#goto_window(opt)
    if type(a:opt) == v:t_func
        for wnr in range(1, winnr('$'))
            if a:opt(wnr, winbufnr(wnr))
                return wnr
            endif
        endfor
        return 0
    endif

    let buf = get(a:opt, 'buffer', '')
    if len(buf)
        let nr = bufnr(a:buf)
        let wid = win_findbuf(nr)
        if len(wid)
            return win_gotoid(wid[0])
        else
            return 0
        endif
    endif
endf

fun! vwm#goto_filetype_window(ft)
    let ft = a:ft
    return vwm#goto_window({w,b->getbufvar(b,'&ft')==ft})
endf

fun! vwm#goto_buffer(buf, ...)
    let nr = bufnr(a:buf)
    let wid = win_findbuf(nr)
    if len(wid)
        return win_gotoid(wid[0])
    endif
    " a:1 = edit | tabedit
    if a:0 | exe a:1 a:buf | endif
endf

fun! vwm#goto_max_window()
    let max_area = 0
    let max_wid = 0
    for wnr in range(1, winnr('$'))
        let area = winwidth(wnr) * winheight(wnr)
        if area > max_area
            let max_wid = win_getid(wnr)
            let max_area = area
        endif
    endfor
    return win_gotoid(max_wid)
endf

fun! vwm#goto_normal_window(...)
    " 当前是普通窗口，可以随意切换
    let wid = win_getid()
    if empty(&bt) && wid != g:vwm_bottom_panel && wid != g:vwm_left_panel
        return 1
    endif

    for i in range(1, winnr('$'))
        if empty(getbufvar(winbufnr(i), '&bt'))
            call win_gotoid(win_getid(i))
            return 1
        endif
    endfor
    call vwm#goto_max_window()
    call vwm#auto_split()
endf

fun! vwm#do_in_normal_window(...)
    call vwm#goto_normal_window()
    exe join(a:000)
endf

fun! vwm#goto_last(dir)
    call assert_true(a:dir ==# '^[jkhl]$')
    exec '100winc' a:dir
endf

fun! vwm#goto_terminal(force)
    call vwm#open_bottom_panel()
    let terminal_bnr = 0
    for info in getbufinfo({'buflisted': 1})
        let bnr = info['bufnr']
        let bt = getbufvar(bnr, '&bt')
        if bt == 'terminal'
            let terminal_bnr = bnr
            break
        endif
    endfor
    if terminal_bnr
        exec terminal_bnr 'b'
    elseif a:force
        call vwm#terminal()
    endif
    startinsert
endf

fun! vwm#close_window(...)
    let level = a:0 ? a:1 : 'delete'
    if level == 'delete!'
        setl bh=delete
    elseif level == 'delete'
        if empty(&bt)
            setl bh=delete
        endif
    endif

    let wid = win_getid()
    if wid == g:vwm_left_panel || wid == g:vwm_bottom_panel
        close | return
    endif

    " 非panel的窗口列表
    let norm_wids = filter(range(1, winnr('$')), {i,v->win_getid(v)!=g:vwm_left_panel&&win_getid(v)!=g:vwm_bottom_panel})
    " 存在一个以上的非panel的窗口
    if len(norm_wids) > 1
        close
    else
        echohl Error
        echo 'can not close the only normal window'
        echohl Normal
    endif
endf

" Get buffers belongs to current window
fun! vwm#get_bufs()
    let wid = win_getid()
    if wid == g:vwm_bottom_panel
        return get(g:, 'vwm_bottom_bufs', [])
    endif
    if wid == g:vwm_left_panel
        return get(g:, 'vwm_left_bufs', [])
    endif
    return get(g:, 'norm_bufs', [])
endf

fun! s:next_buf(l)
    let blist = a:l
    let last_bnr = bufnr('#')

    if len(bufname(last_bnr)) && index(blist, last_bnr) > 0
        return last_bnr
    end

    if len(blist) < 2 | return 0 | endif

    let i = index(blist, bufnr('%'))
    if i >= 0
        return get(blist, (i + 1) % len(blist), 0)
    else
        return get(blist, 0, 0)
    endif
endf

fun! vwm#close_buffer()
    " nofile类型的buffer，清除之前要求用户确认
    if &bt=='nofile' && 2 != confirm('Not a file, continue quit?', "&Yes\ n&No", 2, "Warning")
        return
    endif

    if &bt == 'terminal' && has('nvim')
        set bh=delete
        call jobclose(b:terminal_job_id)
    endif

    let curbuf = bufnr('%')
    let wid = win_getid()

    " 下一个buffer
    let bufs = vwm#get_bufs()
    let next_bnr = s:next_buf(bufs)
    let in_panel = wid == g:vwm_bottom_panel || wid == g:vwm_left_panel

    echo bufs next_bnr in_panel
    if next_bnr
        if &modified == 0
            setl bh=delete
            exec next_bnr 'b!'
        elseif empty(&bt)
            let n = confirm('Modified, Save?', "&Yes\n&No\n&Cancel", 1)
            " echo n | call getchar()
            if n == 1 | write! | endif
            if n != 3
                if n == 2 | setl bt=nowrite | endif
                setl bh=delete
                exec next_bnr 'b!'
            endif
        else
            exec next_bnr 'b!'
        endif
    elseif in_panel
        close
    endif
endf

fun! vwm#auto_split()
    let width = winwidth(0) * 1.0 / &columns
    let height = winheight(0) * 1.0 / &lines
    let vert = width > height
    exe a:0 ? (vert ? 'vert ' : '') . a:1 : (vert ? 'winc v': 'winc s')
endf

fun! s:map_sizes(sizelist, fullsize)
    return map(copy(a:sizelist), {i,v->type(v)==v:t_float ? float2nr(a:fullsize * v): v})
endf

" 获取两个并排的普通窗口
" return [cur_winid, left_winid, right_wid]
fun! vwm#get_norm_win()
    let wid = win_getid()
    let left_win = winnr('h')
    if winnr() != left_win && empty(getbufvar(winbufnr(left_win), '&bt'))
        return [wid, win_getid(left_win), wid]
    endif

    let right_win = winnr('l')
    if winnr() != right_win && empty(getbufvar(winbufnr(right_win), '&bt'))
        return [wid, wid, win_getid(right_win)]
    endif
    return [wid, 0, 0]
endf

fun! s:change_size(inc, sizes, cursize, cmd, loop, height)
    let sizes = a:inc ? a:sizes: reverse(a:sizes)
    let cursize = a:cursize

    for i in range(0, len(sizes) - 1)
        let size = sizes[i]
        if (a:inc ? cursize < size: cursize > size)
            exec a:cmd size
            " 高度没有变化，说明已到极限了
            if (a:height ? winheight(0): winwidth(0)) == cursize
                break
            else
                return
            endif
        endif
    endfor
    " 轮回
    if a:loop | exec a:cmd sizes[0] | endif
endf

fun! vwm#add_size(...)
    let wid = win_getid()
    let inc = a:0 ? a:1 : 1

    if wid == g:vwm_bottom_panel || &bt == 'help'
        call s:change_size(inc, s:map_sizes(g:vwm_bottom_size, &lines), winheight(0), 'resize', 1, 1)
    elseif wid == g:vwm_left_panel
        call s:change_size(inc, s:map_sizes(g:vwm_left_size, &columns), winwidth(0), 'vertical resize', 1, 0)
    else
        let [wid, lid, rid] = vwm#get_norm_win()
        " echom wid lid rid
        if lid && rid
            let another_width = winwidth(wid == lid ? rid: lid)
            let current_width = winwidth(wid)
            " echom current_width another_width
            if abs(current_width - another_width) > 1
                " 两个窗口宽带相差超过1，平分两个窗口
                exec 'vertical' 'resize' (another_width+current_width)/2
            else
                " 两个窗口宽度差不多相同，调整成2/3
                exec 'vertical' 'resize' float2nr((another_width+current_width)*0.67)
            endif
        else
            let wid = win_getid()
            let below_wid = win_getid(winnr('j'))
            let left_wid = win_getid(winnr('l'))
            if below_wid == g:vwm_bottom_panel
                call win_gotoid(below_wid)
                call vwm#add_size(!inc)
                call win_gotoid(wid)
            endif
            if below_wid == g:vwm_left_panel
                call win_gotoid(left_wid)
                call vwm#add_size(!inc)
                call win_gotoid(wid)
            endif
        endif
    endif
endf

fun! vwm#dec_size()
    return vwm#add_size(0)
endf
